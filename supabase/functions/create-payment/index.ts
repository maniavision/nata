/**
 * create-payment — a Flutterwave payment link for the sender of an accepted
 * request, to pay its fixed price into escrow.
 *
 * Called by the app (with the sender's JWT) with { request_id, method,
 * country, email }, where method is card, mobile_money, bank_transfer or
 * apple_pay. The amount and currency are the ones fixed when the traveler
 * accepted (display_total / display_currency), never taken from the app.
 * Mobile money is charged in the currency of the wallet's [country] instead,
 * converted at the latest rate (nata.mobile_money_charge); the fixed price
 * is kept as base_amount. Bank transfer is charged in naira the same way
 * (nata.local_charge).
 *
 * Allowed only for the request's sender, while it is accepted and before its
 * payment deadline, once the sender checked the ticket. (The traveler's ID is
 * checked in person, at the handover.)
 *
 * Flutterwave needs the payer's email. It is the account's; for an account
 * made with a phone number, the [email] the sender gave at checkout, kept in
 * nata.payer_emails (20240148) for next time.
 *
 * Mobile money in a country listed in DIRECT, sent with the wallet's [phone]
 * (international, +<code><number>) and [network], is charged directly
 * (Flutterwave's charges API): the payer approves a prompt on their phone,
 * with no payment page. Elsewhere (Ghana, Uganda, Rwanda, Zambia, Senegal,
 * Burkina Faso... whose charges need a page, an OTP or a code) it goes
 * through Flutterwave's page as before.
 *
 * Responds 200 with { link, tx_ref }, or { tx_ref, direct: true } for a
 * direct charge waiting for the payer's approval (verify-payment and the
 * webhook settle it as any other). A direct charge that Flutterwave still
 * sends to a page answers with that page's link. Errors: 401 unauthorized,
 * 403 not_allowed, 409 not_payable / expired / checks_missing /
 * email_required / mobile_money_unavailable / rate_unavailable,
 * 422 phone_rejected (Flutterwave refused the number or network),
 * 503 payments_unavailable (no FLW_SECRET_KEY), 502 provider_error.
 */

// ── Flutterwave and Supabase helpers (the same in each payment function, so
// each can be deployed on its own, also from the dashboard) ──────────────

import { createClient } from "jsr:@supabase/supabase-js@2";

const FLW_API = "https://api.flutterwave.com/v3";

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


/** Flutterwave payment options for what the sender picked. */
const OPTIONS: Record<string, string> = {
  card: "card",
  apple_pay: "applepay, card",
  mobile_money: "",
  // A temporary Nigerian bank account to pay into, in naira.
  bank_transfer: "banktransfer",
};

/** The mobile money Flutterwave takes in each currency. */
const MOBILE_MONEY: Record<string, string> = {
  KES: "mpesa",
  GHS: "mobilemoneyghana",
  UGX: "mobilemoneyuganda",
  RWF: "mobilemoneyrwanda",
  ZMW: "mobilemoneyzambia",
  TZS: "mobilemoneytanzania",
  XOF: "mobilemoneyfranco",
  XAF: "mobilemoneyfranco",
};

/**
 * Where mobile money can be charged directly: Flutterwave's charge type, the
 * country's calling code, and the networks it takes (none to send for M-Pesa
 * and Tanzania, where the number settles it). These charges answer with a
 * pending payment and a prompt on the payer's phone; the other countries'
 * charges need a page, so they keep using Flutterwave's. Keep in step with
 * DirectMobileMoney in lib/services/request_service.dart.
 */
const DIRECT: Record<
  string,
  { type: string; dialCode: string; networks: string[] }
> = {
  KE: { type: "mpesa", dialCode: "254", networks: [] },
  TZ: { type: "mobile_money_tanzania", dialCode: "255", networks: [] },
  CM: { type: "mobile_money_franco", dialCode: "237", networks: ["MTN", "ORANGEMONEY"] },
  CI: {
    type: "mobile_money_franco",
    dialCode: "225",
    networks: ["MTN", "ORANGEMONEY", "MOOV"],
  },
};

/**
 * The wallet to charge directly, or null to use Flutterwave's page: the
 * country takes direct charges, and the number (digits, with the country's
 * code) and network fit it.
 */
function directWallet(
  country: string,
  phone: string,
  network: string,
): { type: string; phone: string; network: string } | null {
  const direct = DIRECT[country];
  if (!direct) return null;
  const digits = phone.replace(/\D/g, "");
  if (!digits.startsWith(direct.dialCode) || digits.length < 10 || digits.length > 15) {
    return null;
  }
  if (direct.networks.length > 0 && !direct.networks.includes(network)) return null;
  return { type: direct.type, phone: digits, network };
}

/** The same check as nata.payer_emails. */
const EMAIL = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  if (!secretKey()) return json({ error: "payments_unavailable" }, 503);

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
  if (!requestId || !(method in OPTIONS)) return json({ error: "bad_request" }, 400);
  if (method === "mobile_money" && !/^[A-Z]{2}$/.test(country)) {
    return json({ error: "bad_request" }, 400);
  }
  // A number given for a country that takes direct charges must fit it.
  const wallet = method === "mobile_money" && phone
    ? directWallet(country, phone, network)
    : null;
  if (method === "mobile_money" && phone && DIRECT[country] && !wallet) {
    return json({ error: "phone_rejected" }, 422);
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

  // The payer's email: the account's, else the one given at checkout (kept
  // for next time), else the one given last time.
  let email = String(user.email ?? "").trim();
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

  const { data: profile } = await db
    .from("profiles")
    .select("first_name, last_name")
    .eq("id", user.id)
    .maybeSingle();
  const name = [profile?.first_name, profile?.last_name]
    .filter((p) => p && String(p).trim())
    .join(" ");

  const baseAmount = Number(request.display_total);
  const baseCurrency = String(request.display_currency ?? "USD").trim().toUpperCase();
  let amount = baseAmount;
  let currency = baseCurrency;
  let paymentOptions = OPTIONS[method];
  if (method === "mobile_money") {
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
    paymentOptions = MOBILE_MONEY[currency] ?? "";
    if (!paymentOptions) return json({ error: "mobile_money_unavailable" }, 409);
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
  const txRef = `nata-${requestId.slice(0, 8)}-${crypto.randomUUID()}`;

  const { error: insertError } = await db.from("payments").insert({
    request_id: requestId,
    sender_id: user.id,
    provider: "flutterwave",
    tx_ref: txRef,
    amount,
    service_fee: Math.round(fee * 100) / 100,
    currency,
    base_amount: baseAmount,
    base_currency: baseCurrency,
    country_code: method === "mobile_money"
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

  if (wallet) {
    const res = await flutterwave(`/charges?type=${wallet.type}`, {
      method: "POST",
      body: {
        tx_ref: txRef,
        amount,
        currency,
        email,
        phone_number: wallet.phone,
        fullname: name || undefined,
        country: wallet.type === "mobile_money_franco" ? country : undefined,
        network: wallet.network || undefined,
        meta: { request_id: requestId },
      },
    });
    if (!res.ok) {
      console.error("[create-payment] charge", res.status, res.body.message);
      await db.rpc("fail_payment", { p_tx_ref: txRef, p_transaction_id: null });
      // Flutterwave answers 400 for a number or network it won't charge.
      return res.status === 400
        ? json({ error: "phone_rejected" }, 422)
        : json({ error: "provider_error" }, 502);
    }
    // Some wallets (Orange in Côte d'Ivoire, for one) still send the payer
    // to a page to approve: open it like Flutterwave's.
    const auth = (res.body.meta as { authorization?: Record<string, unknown> } | undefined)
      ?.authorization;
    const page = String(auth?.redirect ?? auth?.redirect_url ?? "");
    if (/^https:\/\//.test(page)) return json({ link: page, tx_ref: txRef });
    return json({ tx_ref: txRef, direct: true });
  }

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
