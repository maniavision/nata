/**
 * create-payment — starts paying an accepted request into escrow, for its
 * sender.
 *
 * Called by the app (with the sender's JWT) with { request_id, method,
 * country, phone, network }, where method is card, apple_pay or
 * mobile_money. The amount and currency are the ones fixed when the
 * traveler accepted (display_total / display_currency), never taken from the
 * app. Mobile money is charged in the currency of the wallet's [country]
 * instead, converted at the latest rate (nata.mobile_money_charge); the fixed
 * price is kept as base_amount.
 *
 * Allowed only for the request's sender, while it is accepted and before its
 * payment deadline, once the sender checked the ticket. (The traveler's ID is
 * checked in person, at the handover.)
 *
 * The method must fit where the sender and the traveler live
 * (nata.checkout_kind, 20240173): mobile money only when both live in a
 * country where pawaPay takes it, card or Apple Pay otherwise.
 *
 * Cards and Apple Pay are a Stripe PaymentIntent, paid in the app's own
 * Stripe payment sheet (no page to leave for): the payment's tx_ref is the
 * PaymentIntent's id, and verify-payment and stripe-webhook settle it. It is
 * charged in the price's own currency.
 *
 * Mobile money is a pawaPay deposit (20240165): the wallet's [phone]
 * (international, +<code><number>) on its [network] (pawaPay's provider code,
 * one of nata.mobile_money_networks for that country) gets a prompt to
 * approve, with no payment page. The payment's tx_ref is the deposit id;
 * verify-payment and pawapay-callback settle it.
 *
 * With { purpose: "deposit" } it is the traveler's refundable deposit
 * instead (20240195_item_deposits.sql): allowed for the request's traveler
 * while it is accepted or paid and a deposit is due (nata.deposit_due); the
 * amount is the declared value, or the same in the wallet's currency for
 * mobile money (nata.deposit_charge), with the same method rule. It is held
 * until delivery and never changes the request's status.
 *
 * Responds 200 with { tx_ref, client_secret, publishable_key,
 * merchant_country, apple_merchant_id, customer_id, ephemeral_key } (Stripe's
 * sheet, with the member's saved cards: 20240196_stripe_customers.sql), or
 * { tx_ref, direct: true } (mobile money, waiting for the payer's approval).
 * Errors: 401 unauthorized, 403 not_allowed, 409 not_payable / expired /
 * checks_missing / method_not_offered / mobile_money_unavailable /
 * rate_unavailable /
 * amount_out_of_bounds, 422 phone_rejected (the number or network doesn't
 * fit, or pawaPay refused it), 503 payments_unavailable (no key for the
 * provider) / network_unavailable (the network is down), 502 provider_error.
 */

// ── Stripe, pawaPay and Supabase helpers (the same in each payment function, so
// each can be deployed on its own, also from the dashboard) ──────────────

import { createClient } from "jsr:@supabase/supabase-js@2";

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

function stripeKey(): string | null {
  const key = Deno.env.get("STRIPE_SECRET_KEY")?.trim();
  return key ? key : null;
}

/** Calls Stripe (form-encoded); [status] 0 when it couldn't be reached. */
async function stripe(
  path: string,
  init: {
    method?: string;
    form?: Record<string, string>;
    idempotencyKey?: string;
    stripeVersion?: string;
  } = {},
): Promise<{ status: number; body: Record<string, unknown> }> {
  const headers: Record<string, string> = {
    Authorization: `Bearer ${stripeKey()}`,
  };
  if (init.form) headers["Content-Type"] = "application/x-www-form-urlencoded";
  if (init.idempotencyKey) headers["Idempotency-Key"] = init.idempotencyKey;
  if (init.stripeVersion) headers["Stripe-Version"] = init.stripeVersion;
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

/** The API version the mobile payment sheet's ephemeral keys are made for. */
const SHEET_API_VERSION = "2024-06-20";

/**
 * The member's Stripe Customer (nata.stripe_customers, 20240196), made the
 * first time; null when Stripe can't be reached.
 */
async function stripeCustomer(
  userId: string,
  email?: string | null,
): Promise<string | null> {
  const db = admin.schema("nata");
  const { data: row } = await db.from("stripe_customers")
    .select("customer_id")
    .eq("user_id", userId)
    .maybeSingle();
  if (row?.customer_id) return String(row.customer_id);
  const res = await stripe("/customers", {
    method: "POST",
    idempotencyKey: `nata-customer-${userId}`,
    form: {
      "metadata[user_id]": userId,
      ...(email ? { email: String(email) } : {}),
    },
  });
  const id = String(res.body.id ?? "");
  if (res.status !== 200 || !id) {
    console.error("[stripe] customer", res.status);
    return null;
  }
  const { error } = await db.from("stripe_customers")
    .upsert({ user_id: userId, customer_id: id }, { onConflict: "user_id", ignoreDuplicates: true });
  if (error) console.error("[stripe] save customer", error.message);
  // Another call may have saved one first: that one wins.
  const { data: saved } = await db.from("stripe_customers")
    .select("customer_id")
    .eq("user_id", userId)
    .maybeSingle();
  return saved?.customer_id ? String(saved.customer_id) : id;
}

/** A short-lived key letting the payment sheet show [customer]'s cards. */
async function ephemeralKey(customer: string): Promise<string | null> {
  const res = await stripe("/ephemeral_keys", {
    method: "POST",
    stripeVersion: SHEET_API_VERSION,
    form: { customer },
  });
  return res.status === 200 ? String(res.body.secret ?? "") || null : null;
}

// ── This function ──────────────────────────────────────────────────────────


const METHODS = ["card", "apple_pay", "mobile_money"];

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

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const user = await caller(req);
  if (!user) return json({ error: "unauthorized" }, 401);

  let requestId = "";
  let method = "card";
  let country = "";
  let phone = "";
  let network = "";
  let deposit = false;
  try {
    const body = await req.json();
    requestId = String(body.request_id ?? "");
    method = String(body.method ?? "card");
    country = String(body.country ?? "").trim().toUpperCase();
    phone = String(body.phone ?? "").trim();
    network = String(body.network ?? "").trim().toUpperCase();
    deposit = body.purpose === "deposit";
  } catch (_) {
    return json({ error: "bad_request" }, 400);
  }
  if (!requestId || !METHODS.includes(method)) {
    return json({ error: "bad_request" }, 400);
  }
  const mobile = method === "mobile_money";
  if (mobile && !/^[A-Z]{2}$/.test(country)) {
    return json({ error: "bad_request" }, 400);
  }
  if (mobile ? !pawapayToken() : !stripeKey()) {
    return json({ error: "payments_unavailable" }, 503);
  }

  const db = admin.schema("nata");
  const { data: request } = await db
    .from("delivery_requests")
    .select(
      "id, sender_id, status, expires_at, display_total, display_fee, display_currency, ticket_checked_at, trips(traveler_id)",
    )
    .eq("id", requestId)
    .maybeSingle();
  const travelerId = (request?.trips as { traveler_id?: string } | null)
    ?.traveler_id;
  if (deposit) {
    // The traveler's deposit: before pickup, and only while one is due and
    // none is held yet.
    if (!request || travelerId !== user.id) {
      return json({ error: "not_allowed" }, 403);
    }
    if (request.status !== "accepted" && request.status !== "paid") {
      return json({ error: "not_payable" }, 409);
    }
    const [{ data: due }, { data: held }] = await Promise.all([
      db.rpc("deposit_due", { p_request_id: requestId }).maybeSingle(),
      db.from("payments")
        .select("id")
        .eq("request_id", requestId)
        .eq("purpose", "deposit")
        .in("status", ["held", "released"])
        .eq("needs_refund", false)
        .limit(1),
    ]);
    if (!(due as { required?: boolean } | null)?.required || (held ?? []).length) {
      return json({ error: "not_payable" }, 409);
    }
  } else {
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
  }

  // Mobile money between two members living where pawaPay takes it; card or
  // Apple Pay otherwise.
  const { data: kind, error: kindError } = await db.rpc("checkout_kind", {
    p_request_id: requestId,
  });
  if (kindError) {
    console.error("[create-payment] checkout kind", kindError);
    return json({ error: "provider_error" }, 502);
  }
  if ((kind === "mobile_money") !== mobile) {
    return json({ error: "method_not_offered" }, 409);
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

  let baseAmount = Number(request.display_total);
  let baseCurrency = String(request.display_currency ?? "USD").trim().toUpperCase();
  if (deposit) {
    // The declared value, as it is (a card) or in the wallet's currency.
    const { data: charge, error } = await db
      .rpc("deposit_charge", { p_request_id: requestId, p_country: null })
      .maybeSingle();
    if (error || !charge) {
      console.error("[create-payment] deposit", error);
      return json({ error: "not_payable" }, 409);
    }
    const c = charge as { amount: number; currency: string };
    baseAmount = Number(c.amount);
    baseCurrency = String(c.currency).trim().toUpperCase();
  }
  let amount = baseAmount;
  let currency = baseCurrency;
  if (mobile) {
    const { data: charge, error } = await db
      .rpc(deposit ? "deposit_charge" : "mobile_money_charge", {
        p_request_id: requestId,
        p_country: country,
      })
      .maybeSingle();
    if (error || !charge) {
      const msg = String(error?.message ?? "");
      if (msg.includes("rate_unavailable")) return json({ error: "rate_unavailable" }, 409);
      return json({ error: "mobile_money_unavailable" }, 409);
    }
    const c = charge as { amount: number; currency: string };
    amount = Number(c.amount);
    currency = String(c.currency).trim().toUpperCase();
  }
  // The fee, in the currency charged (a deposit has none).
  const fee = deposit ? 0 : Number(request.display_fee ?? 0) * (amount / baseAmount);
  const purpose = deposit ? "deposit" : "delivery";

  // Cards and Apple Pay: the PaymentIntent first, so the payment's tx_ref
  // can be its id.
  if (!mobile) {
    // The member's saved cards (20240196): the sheet offers them, with the
    // default first, and can save a new one. Without a customer it still
    // takes a card.
    const customer = await stripeCustomer(user.id, user.email);
    const key = customer ? await ephemeralKey(customer) : null;
    const pi = await stripe("/payment_intents", {
      method: "POST",
      idempotencyKey: `nata-${requestId}-${crypto.randomUUID()}`,
      form: {
        amount: String(toStripeAmount(amount, currency)),
        currency: currency.toLowerCase(),
        // Cards only (Apple Pay and Google Pay are cards too): nothing that
        // sends the payer elsewhere or settles days later.
        "payment_method_types[]": "card",
        description: deposit
          ? "Nata deposit, refunded after delivery"
          : "Nata delivery, held in escrow until delivery",
        "metadata[request_id]": requestId,
        "metadata[purpose]": purpose,
        "metadata[sender_id]": user.id,
        ...(customer && key ? { customer } : {}),
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
      purpose,
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
      customer_id: customer && key ? customer : null,
      ephemeral_key: customer && key ? key : null,
    });
  }
  // Mobile money: pawaPay's deposit id, a bare UUID.
  const txRef = crypto.randomUUID();

  const { error: insertError } = await db.from("payments").insert({
    request_id: requestId,
    sender_id: user.id,
    provider: "pawapay",
    tx_ref: txRef,
    amount,
    service_fee: Math.round(fee * 100) / 100,
    currency,
    base_amount: baseAmount,
    base_currency: baseCurrency,
    country_code: country,
    method,
    purpose,
    status: "pending",
  });
  if (insertError) {
    console.error("[create-payment] insert", insertError);
    return json({ error: "provider_error" }, 502);
  }

  {
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
        customerMessage: deposit ? "Nata deposit" : "Nata delivery",
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
});
