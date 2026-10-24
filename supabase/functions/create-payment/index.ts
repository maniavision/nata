/**
 * create-payment — starts paying an accepted request into escrow, for its
 * sender.
 *
 * Called by the app (with the sender's JWT) with { request_id, method,
 * country, email, phone, network }, where method is card, mobile_money,
 * bank_transfer or apple_pay. The amount and currency are the ones fixed when
 * the traveler accepted (display_total / display_currency), never taken from
 * the app. Mobile money is charged in the currency of the wallet's [country]
 * instead, converted at the latest rate (nata.mobile_money_charge); the fixed
 * price is kept as base_amount. Bank transfer is charged in naira the same
 * way (nata.local_charge).
 *
 * Allowed only for the request's sender, while it is accepted and before its
 * payment deadline, once the sender checked the ticket. (The traveler's ID is
 * checked in person, at the handover.)
 *
 * Mobile money is a pawaPay deposit (20240165): the wallet's [phone]
 * (international, +<code><number>) on its [network] (pawaPay's provider code,
 * one of nata.mobile_money_networks for that country) gets a prompt to
 * approve, with no payment page. The payment's tx_ref is the deposit id;
 * verify-payment and pawapay-callback settle it.
 *
 * Cards and Apple Pay are a Stripe PaymentIntent, paid in the app's own
 * Stripe payment sheet (no page to leave for): the payment's tx_ref is the
 * PaymentIntent's id, and verify-payment and stripe-webhook settle it. It is
 * charged in the price's own currency.
 *
 * Bank transfer uses Flutterwave's payment page, which needs the payer's
 * email: the account's, or for an account made with a phone number the
 * [email] the sender gave at checkout, kept in nata.payer_emails (20240148)
 * for next time.
 *
 * Responds 200 with { link, tx_ref } (Flutterwave's page),
 * { tx_ref, client_secret, publishable_key, merchant_country,
 * apple_merchant_id } (Stripe's sheet), or { tx_ref, direct: true } (mobile
 * money, waiting for the payer's approval).
 * Errors: 401 unauthorized, 403 not_allowed, 409 not_payable / expired /
 * checks_missing / email_required / mobile_money_unavailable /
 * rate_unavailable / amount_out_of_bounds, 422 phone_rejected (the number or
 * network doesn't fit, or pawaPay refused it), 503 payments_unavailable (no
 * key for the provider) / network_unavailable (the network is down),
 * 502 provider_error.
 */

// ── Flutterwave and Supabase helpers (the same in each payment function, so
// each can be deployed on its own, also from the dashboard) ──────────────

import { createClient } from "jsr:@supabase/supabase-js@2";

const FLW_API = "https://api.flutterwave.com/v3";

/** pawaPay's API: the sandbox until PAWAPAY_API_URL names production. */
const PAWAPAY_API = (Deno.env.get("PAWAPAY_API_URL")?.trim() ||
  "https://api.sandbox.pawapay.io").replace(/\/+$/, "");

const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function secretKey(): string | null {
  const key = Deno.env.get("FLW_SECRET_KEY")?.trim();
  return key ? key : null;
}

function stripeKey(): string | null {
  const key = Deno.env.get("STRIPE_SECRET_KEY")?.trim();
  return key ? key : null;
}

/** Calls Stripe (form-encoded); [status] 0 when it couldn't be reached. */
async function stripe(
  path: string,
  init: { method?: string; form?: Record<string, string>; idempotencyKey?: string } = {},
): Promise<{ status: number; body: Record<string, unknown> }> {
  const headers: Record<string, string> = {
    Authorization: `Bearer ${stripeKey()}`,
  };
  if (init.form) headers["Content-Type"] = "application/x-www-form-urlencoded";
  if (init.idempotencyKey) headers["Idempotency-Key"] = init.idempotencyKey;
  let res: Response;
  try {
    res = await fetch(`https://api.stripe.com/v1${path}`, {
      method: init.method ?? "GET",
      headers,
      body: init.form ? new URLSearchParams(init.form).toString() : undefined,
    });
  } catch (_) {
    return { status: 0, body: {} };
  }
  let body: Record<string, unknown> = {};
  try {
    body = await res.json();
  } catch (_) {
    // Not JSON: keep the empty body.
  }
  return { status: res.status, body };
}

/** Currencies Stripe takes in whole units (no cents). */
const ZERO_DECIMAL = new Set([
  "BIF", "CLP", "DJF", "GNF", "JPY", "KMF", "KRW", "MGA", "PYG", "RWF",
  "UGX", "VND", "VUV", "XAF", "XOF", "XPF",
]);

/** [amount] in Stripe's smallest unit of [currency]. */
function toStripeAmount(amount: number, currency: string): number {
  return ZERO_DECIMAL.has(currency.toUpperCase())
    ? Math.round(amount)
    : Math.round(amount * 100);
}

function pawapayToken(): string | null {
  const token = Deno.env.get("PAWAPAY_API_TOKEN")?.trim();
  return token ? token : null;
}

/** Calls pawaPay; [status] 0 when it couldn't be reached. */
async function pawapay(
  path: string,
  init: { method?: string; body?: unknown } = {},
): Promise<{ status: number; body: Record<string, unknown> }> {
  let res: Response;
  try {
    res = await fetch(`${PAWAPAY_API}${path}`, {
      method: init.method ?? "GET",
      headers: {
        Authorization: `Bearer ${pawapayToken()}`,
        "Content-Type": "application/json",
      },
      body: init.body === undefined ? undefined : JSON.stringify(init.body),
    });
  } catch (_) {
    return { status: 0, body: {} };
  }
  let body: Record<string, unknown> = {};
  try {
    body = await res.json();
  } catch (_) {
    // Not JSON: keep the empty body.
  }
  return { status: res.status, body };
}

/** The signed-in user calling the function, from their JWT. */
async function caller(req: Request) {
  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) return null;
  const { data: { user } } = await admin.auth.getUser(token);
  return user ?? null;
}

async function flutterwave(
  path: string,
  init: { method?: string; body?: unknown } = {},
): Promise<{ ok: boolean; status: number; body: Record<string, unknown> }> {
  const res = await fetch(`${FLW_API}${path}`, {
    method: init.method ?? "GET",
    headers: {
      Authorization: `Bearer ${secretKey()}`,
      "Content-Type": "application/json",
    },
    body: init.body === undefined ? undefined : JSON.stringify(init.body),
  });
  let body: Record<string, unknown> = {};
  try {
    body = await res.json();
  } catch (_) {
    // Not JSON: keep the empty body.
  }
  return { ok: res.ok && body.status === "success", status: res.status, body };
}

/** A transaction as Flutterwave reports it. */
interface Transaction {
  id: string;
  tx_ref: string;
  status: string;
  amount: number;
  currency: string;
  payment_type: string;
}

function toTransaction(data: unknown): Transaction | null {
  const d = data as Record<string, unknown> | null;
  if (!d || d.id == null || typeof d.tx_ref !== "string") return null;
  return {
    id: String(d.id),
    tx_ref: d.tx_ref,
    status: String(d.status ?? ""),
    amount: Number(d.amount ?? 0),
    currency: String(d.currency ?? ""),
    payment_type: String(d.payment_type ?? ""),
  };
}

/** Looks a transaction up by its Flutterwave id. */
async function transactionById(id: string): Promise<Transaction | null> {
  const res = await flutterwave(`/transactions/${encodeURIComponent(id)}/verify`);
  return res.ok ? toTransaction(res.body.data) : null;
}

/** Looks a transaction up by our reference; null while there is none yet. */
async function transactionByRef(txRef: string): Promise<Transaction | null> {
  const res = await flutterwave(
    `/transactions/verify_by_reference?tx_ref=${encodeURIComponent(txRef)}`,
  );
  return res.ok ? toTransaction(res.body.data) : null;
}

/**
 * Records what Flutterwave confirmed. Returns 'successful' (held in escrow),
 * 'failed' or 'pending' (still in progress).
 */
async function record(tx: Transaction): Promise<string> {
  const db = admin.schema("nata");
  if (tx.status === "successful") {
    const { data, error } = await db.rpc("complete_payment", {
      p_tx_ref: tx.tx_ref,
      p_transaction_id: tx.id,
      p_amount: tx.amount,
      p_currency: tx.currency,
      p_payment_type: tx.payment_type,
    });
    if (error) throw error;
    return data === "mismatch" || data === "not_found" ? "failed" : "successful";
  }
  if (tx.status === "failed" || tx.status === "cancelled") {
    const { error } = await db.rpc("fail_payment", {
      p_tx_ref: tx.tx_ref,
      p_transaction_id: tx.id,
    });
    if (error) throw error;
    return "failed";
  }
  return "pending";
}

// ── This function ──────────────────────────────────────────────────────────


/** Flutterwave payment options for what the sender picked (cards and Apple
 * Pay go through Stripe). */
const OPTIONS: Record<string, string> = {
  // A temporary Nigerian bank account to pay into, in naira.
  bank_transfer: "banktransfer",
};

const METHODS = ["card", "apple_pay", "mobile_money", "bank_transfer"];

/** pawaPay refusals that mean the number or network doesn't fit. */
const PHONE_REFUSALS = [
  "INVALID_PHONE_NUMBER",
  "INVALID_PROVIDER",
  "PROVIDER_NOT_SUPPORTED",
  "PAYER_NOT_FOUND",
];

/**
 * The wallet's number as pawaPay takes it (digits, starting with the
 * country's calling code), or null if it isn't a whole one.
 */
function msisdn(phone: string, dialCode: string): string | null {
  const digits = phone.replace(/\D/g, "");
  const code = dialCode.replace(/\D/g, "");
  if (!code || !digits.startsWith(code)) return null;
  if (digits.length < code.length + 7 || digits.length > 15) return null;
  return digits;
}

/** The same check as nata.payer_emails. */
const EMAIL = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const user = await caller(req);
  if (!user) return json({ error: "unauthorized" }, 401);

  let requestId = "";
  let method = "card";
  let country = "";
  let givenEmail = "";
  let phone = "";
  let network = "";
  try {
    const body = await req.json();
    requestId = String(body.request_id ?? "");
    method = String(body.method ?? "card");
    country = String(body.country ?? "").trim().toUpperCase();
    givenEmail = String(body.email ?? "").trim().toLowerCase();
    phone = String(body.phone ?? "").trim();
    network = String(body.network ?? "").trim().toUpperCase();
  } catch (_) {
    return json({ error: "bad_request" }, 400);
  }
  if (!requestId || !METHODS.includes(method)) {
    return json({ error: "bad_request" }, 400);
  }
  const mobile = method === "mobile_money";
  const viaStripe = method === "card" || method === "apple_pay";
  if (mobile && !/^[A-Z]{2}$/.test(country)) {
    return json({ error: "bad_request" }, 400);
  }
  if (mobile ? !pawapayToken() : viaStripe ? !stripeKey() : !secretKey()) {
    return json({ error: "payments_unavailable" }, 503);
  }

  const db = admin.schema("nata");
  const { data: request } = await db
    .from("delivery_requests")
    .select(
      "id, sender_id, status, expires_at, display_total, display_fee, display_currency, ticket_checked_at",
    )
    .eq("id", requestId)
    .maybeSingle();
  if (!request || request.sender_id !== user.id) {
    return json({ error: "not_allowed" }, 403);
  }
  if (request.status !== "accepted" || !request.display_total) {
    return json({ error: "not_payable" }, 409);
  }
  if (request.expires_at && new Date(request.expires_at) <= new Date()) {
    return json({ error: "expired" }, 409);
  }
  if (!request.ticket_checked_at) {
    return json({ error: "checks_missing" }, 409);
  }

  // Mobile money: the network must be one of the country's, and the number
  // a whole one with the country's calling code.
  let wallet = "";
  if (mobile) {
    const [{ data: net }, { data: place }] = await Promise.all([
      db.from("mobile_money_networks")
        .select("provider")
        .eq("provider", network)
        .eq("country_code", country)
        .maybeSingle(),
      db.from("countries")
        .select("phone_code")
        .eq("iso_code", country)
        .maybeSingle(),
    ]);
    wallet = msisdn(phone, String(place?.phone_code ?? "")) ?? "";
    if (!net || !wallet) return json({ error: "phone_rejected" }, 422);
  }

  // The payer's email, for Flutterwave: the account's, else the one given
  // at checkout (kept for next time), else the one given last time.
  let email = "";
  if (!mobile && !viaStripe) {
    email = String(user.email ?? "").trim();
    if (!email && EMAIL.test(givenEmail)) {
      email = givenEmail;
      const { error } = await db.from("payer_emails").upsert({
        user_id: user.id,
        email,
        updated_at: new Date().toISOString(),
      });
      if (error) console.error("[create-payment] payer email", error);
    }
    if (!email) {
      const { data: saved } = await db
        .from("payer_emails")
        .select("email")
        .eq("user_id", user.id)
        .maybeSingle();
      email = String(saved?.email ?? "");
    }
    if (!email) return json({ error: "email_required" }, 409);
  }

  const baseAmount = Number(request.display_total);
  const baseCurrency = String(request.display_currency ?? "USD").trim().toUpperCase();
  let amount = baseAmount;
  let currency = baseCurrency;
  const paymentOptions = OPTIONS[method] ?? "";
  if (mobile) {
    const { data: charge, error } = await db
      .rpc("mobile_money_charge", { p_request_id: requestId, p_country: country })
      .maybeSingle();
    if (error || !charge) {
      const msg = String(error?.message ?? "");
      if (msg.includes("rate_unavailable")) return json({ error: "rate_unavailable" }, 409);
      return json({ error: "mobile_money_unavailable" }, 409);
    }
    const c = charge as { amount: number; currency: string };
    amount = Number(c.amount);
    currency = String(c.currency).trim().toUpperCase();
  } else if (method === "bank_transfer") {
    const { data: charge, error } = await db
      .rpc("local_charge", { p_request_id: requestId, p_currency: "NGN" })
      .maybeSingle();
    if (error || !charge) {
      const msg = String(error?.message ?? "");
      if (msg.includes("rate_unavailable")) return json({ error: "rate_unavailable" }, 409);
      return json({ error: "not_payable" }, 409);
    }
    const c = charge as { amount: number; currency: string };
    amount = Number(c.amount);
    currency = String(c.currency).trim().toUpperCase();
  }
  // The fee, in the currency charged.
  const fee = Number(request.display_fee ?? 0) * (amount / baseAmount);

  // Cards and Apple Pay: the PaymentIntent first, so the payment's tx_ref
  // can be its id.
  if (viaStripe) {
    const pi = await stripe("/payment_intents", {
      method: "POST",
      idempotencyKey: `nata-${requestId}-${crypto.randomUUID()}`,
      form: {
        amount: String(toStripeAmount(amount, currency)),
        currency: currency.toLowerCase(),
        // Cards only (Apple Pay and Google Pay are cards too): nothing that
        // sends the payer elsewhere or settles days later.
        "payment_method_types[]": "card",
        description: "Nata delivery, held in escrow until delivery",
        "metadata[request_id]": requestId,
        "metadata[sender_id]": user.id,
        ...(user.email ? { receipt_email: String(user.email) } : {}),
      },
    });
    const piId = String(pi.body.id ?? "");
    const clientSecret = String(pi.body.client_secret ?? "");
    if (pi.status !== 200 || !piId || !clientSecret) {
      const err = pi.body.error as { message?: string } | undefined;
      console.error("[create-payment] stripe", pi.status, err?.message);
      return json({ error: "provider_error" }, 502);
    }
    const { error: stripeInsert } = await db.from("payments").insert({
      request_id: requestId,
      sender_id: user.id,
      provider: "stripe",
      tx_ref: piId,
      amount,
      service_fee: Math.round(fee * 100) / 100,
      currency,
      base_amount: baseAmount,
      base_currency: baseCurrency,
      country_code: null,
      method,
      status: "pending",
    });
    if (stripeInsert) {
      console.error("[create-payment] insert", stripeInsert);
      await stripe(`/payment_intents/${piId}/cancel`, { method: "POST", form: {} });
      return json({ error: "provider_error" }, 502);
    }
    return json({
      tx_ref: piId,
      client_secret: clientSecret,
      publishable_key: Deno.env.get("STRIPE_PUBLISHABLE_KEY")?.trim() ?? "",
      merchant_country: "US",
      apple_merchant_id: Deno.env.get("STRIPE_APPLE_MERCHANT_ID")?.trim() || null,
    });
  }
  // pawaPay's deposit id is a bare UUID; Flutterwave's reference starts with
  // nata- (its webhook ignores anything else).
  const txRef = mobile
    ? crypto.randomUUID()
    : `nata-${requestId.slice(0, 8)}-${crypto.randomUUID()}`;

  const { error: insertError } = await db.from("payments").insert({
    request_id: requestId,
    sender_id: user.id,
    provider: mobile ? "pawapay" : "flutterwave",
    tx_ref: txRef,
    amount,
    service_fee: Math.round(fee * 100) / 100,
    currency,
    base_amount: baseAmount,
    base_currency: baseCurrency,
    country_code: mobile
      ? country
      : method === "bank_transfer"
      ? "NG"
      : null,
    method,
    status: "pending",
  });
  if (insertError) {
    console.error("[create-payment] insert", insertError);
    return json({ error: "provider_error" }, 502);
  }

  if (mobile) {
    const res = await pawapay("/v2/deposits", {
      method: "POST",
      body: {
        depositId: txRef,
        amount: String(amount),
        currency,
        payer: {
          type: "MMO",
          accountDetails: { phoneNumber: wallet, provider: network },
        },
        clientReferenceId: requestId,
        customerMessage: "Nata delivery",
      },
    });
    const status = String(res.body.status ?? "");
    if (status === "ACCEPTED" || status === "DUPLICATE_IGNORED") {
      return json({ tx_ref: txRef, direct: true });
    }
    // No answer (pawaPay down, or a 500): it may still have started, so
    // verify-payment finds out (NOT_FOUND there fails it).
    if (res.status === 0 || res.status >= 500) {
      console.error("[create-payment] pawapay unanswered", res.status);
      return json({ tx_ref: txRef, direct: true });
    }
    const reason = res.body.failureReason as
      | { failureCode?: string; failureMessage?: string }
      | undefined;
    const code = String(reason?.failureCode ?? "");
    console.error("[create-payment] pawapay", res.status, code, reason?.failureMessage);
    await db.rpc("fail_payment", { p_tx_ref: txRef, p_transaction_id: null });
    if (PHONE_REFUSALS.includes(code)) return json({ error: "phone_rejected" }, 422);
    if (code === "AMOUNT_OUT_OF_BOUNDS" || code === "INVALID_AMOUNT") {
      return json({ error: "amount_out_of_bounds" }, 409);
    }
    if (code === "PROVIDER_TEMPORARILY_UNAVAILABLE") {
      return json({ error: "network_unavailable" }, 503);
    }
    return json({ error: "provider_error" }, 502);
  }

  const { data: profile } = await db
    .from("profiles")
    .select("first_name, last_name")
    .eq("id", user.id)
    .maybeSingle();
  const name = [profile?.first_name, profile?.last_name]
    .filter((p) => p && String(p).trim())
    .join(" ");

  const res = await flutterwave("/payments", {
    method: "POST",
    body: {
      tx_ref: txRef,
      amount,
      currency,
      payment_options: paymentOptions,
      redirect_url: `${Deno.env.get("SUPABASE_URL")}/functions/v1/payment-return`,
      customer: {
        email,
        name: name || undefined,
        phonenumber: user.phone || undefined,
      },
      customizations: {
        title: "Nata",
        description: "Delivery payment, held in escrow until delivery",
      },
      meta: { request_id: requestId },
    },
  });
  const link = (res.body.data as { link?: string } | undefined)?.link;
  if (!res.ok || !link) {
    console.error("[create-payment] flutterwave", res.status, res.body.message);
    await db.rpc("fail_payment", { p_tx_ref: txRef, p_transaction_id: null });
    return json({ error: "provider_error" }, 502);
  }

  return json({ link, tx_ref: txRef });
});
