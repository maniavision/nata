/**
 * verify-payment — where a payment the sender started stands. The app asks
 * once the sender has paid in Stripe's sheet, or while they approve a mobile
 * money prompt on their phone, so it doesn't depend on the webhook or
 * callback arriving first.
 *
 * Called by the app (with the sender's JWT) with { tx_ref }. A pending
 * payment is checked with its provider and recorded once it is settled:
 * Stripe for cards and Apple Pay (the tx_ref is the PaymentIntent's id),
 * pawaPay for mobile money (20240165; the tx_ref is the deposit id),
 * Flutterwave for cards of members living in Nigeria (20240198; paid on
 * Flutterwave's page, the tx_ref is ours).
 *
 * Responds 200 with { status: pending | successful | failed }: successful
 * once the money is held in escrow (or already released).
 * Errors: 401 unauthorized, 404 not_found, 503 payments_unavailable.
 */

// ── Stripe, pawaPay, Flutterwave and Supabase helpers (the same in each payment function, so
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

/** A Stripe amount (smallest unit) back in whole units of [currency]. */
function fromStripeAmount(amount: number, currency: string): number {
  return ZERO_DECIMAL.has(currency.toUpperCase()) ? amount : amount / 100;
}

/**
 * Looks the PaymentIntent [id] up with Stripe and records it: 'successful'
 * (held in escrow), 'failed' (cancelled) or 'pending' (not paid yet, or
 * Stripe couldn't be asked).
 */
async function recordPaymentIntent(id: string): Promise<string> {
  const res = await stripe(`/payment_intents/${encodeURIComponent(id)}`);
  if (res.status !== 200) return "pending";
  const pi = res.body;
  const db = admin.schema("nata");
  const status = String(pi.status ?? "");
  if (status === "succeeded") {
    const currency = String(pi.currency ?? "").toUpperCase();
    const { data, error } = await db.rpc("complete_payment", {
      p_tx_ref: id,
      p_transaction_id: id,
      p_amount: fromStripeAmount(Number(pi.amount_received ?? 0), currency),
      p_currency: currency,
      p_payment_type: "card",
    });
    if (error) throw error;
    return data === "mismatch" || data === "not_found" ? "failed" : "successful";
  }
  if (status === "canceled") {
    const { error } = await db.rpc("fail_payment", {
      p_tx_ref: id,
      p_transaction_id: id,
    });
    if (error) throw error;
    return "failed";
  }
  // requires_payment_method (a declined card can be tried again in the
  // sheet), requires_action, processing...
  return "pending";
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

/**
 * Looks a pawaPay deposit up and records it: 'successful' (held in
 * escrow), 'failed', 'pending', or 'not_found' while
 * pawaPay has no such deposit.
 */
async function recordDeposit(depositId: string): Promise<string> {
  const res = await pawapay(`/v2/deposits/${encodeURIComponent(depositId)}`);
  if (res.status !== 200) return "pending";
  if (res.body.status === "NOT_FOUND") return "not_found";
  const d = res.body.data as Record<string, unknown> | undefined;
  if (res.body.status !== "FOUND" || !d || d.depositId !== depositId) {
    return "pending";
  }
  const db = admin.schema("nata");
  if (d.status === "COMPLETED") {
    const account = (d.payer as { accountDetails?: { provider?: string } } | undefined)
      ?.accountDetails;
    const { data, error } = await db.rpc("complete_payment", {
      p_tx_ref: depositId,
      p_transaction_id: depositId,
      p_amount: Number(d.amount ?? 0),
      p_currency: String(d.currency ?? ""),
      p_payment_type: String(account?.provider ?? "mobile_money"),
    });
    if (error) throw error;
    return data === "mismatch" || data === "not_found" ? "failed" : "successful";
  }
  if (d.status === "FAILED") {
    const { error } = await db.rpc("fail_payment", {
      p_tx_ref: depositId,
      p_transaction_id: depositId,
    });
    if (error) throw error;
    return "failed";
  }
  return "pending";
}

function flutterwaveKey(): string | null {
  const key = Deno.env.get("FLW_SECRET_KEY")?.trim();
  return key ? key : null;
}

/** Calls Flutterwave; [ok] when it answered with success. */
async function flutterwave(
  path: string,
  init: { method?: string; body?: unknown } = {},
): Promise<{ ok: boolean; status: number; body: Record<string, unknown> }> {
  let res: Response;
  try {
    res = await fetch(`https://api.flutterwave.com/v3${path}`, {
      method: init.method ?? "GET",
      headers: {
        Authorization: `Bearer ${flutterwaveKey()}`,
        "Content-Type": "application/json",
      },
      body: init.body === undefined ? undefined : JSON.stringify(init.body),
    });
  } catch (_) {
    return { ok: false, status: 0, body: {} };
  }
  let body: Record<string, unknown> = {};
  try {
    body = await res.json();
  } catch (_) {
    // Not JSON: keep the empty body.
  }
  return { ok: res.ok && body.status === "success", status: res.status, body };
}

/**
 * Looks a Flutterwave payment up by our reference and records it:
 * 'successful' (held in escrow), 'failed', or 'pending' (not paid yet, or
 * still in progress).
 */
async function recordFlutterwave(txRef: string): Promise<string> {
  const res = await flutterwave(
    `/transactions/verify_by_reference?tx_ref=${encodeURIComponent(txRef)}`,
  );
  const d = res.body.data as Record<string, unknown> | undefined;
  if (!res.ok || !d || d.tx_ref !== txRef || d.id == null) return "pending";
  const db = admin.schema("nata");
  const status = String(d.status ?? "");
  if (status === "successful") {
    const { data, error } = await db.rpc("complete_payment", {
      p_tx_ref: txRef,
      p_transaction_id: String(d.id),
      p_amount: Number(d.amount ?? 0),
      p_currency: String(d.currency ?? ""),
      p_payment_type: String(d.payment_type ?? "card"),
    });
    if (error) throw error;
    return data === "mismatch" || data === "not_found" ? "failed" : "successful";
  }
  if (status === "failed" || status === "cancelled") {
    const { error } = await db.rpc("fail_payment", {
      p_tx_ref: txRef,
      p_transaction_id: String(d.id),
    });
    if (error) throw error;
    return "failed";
  }
  return "pending";
}

/** The signed-in user calling the function, from their JWT. */
async function caller(req: Request) {
  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) return null;
  const { data: { user } } = await admin.auth.getUser(token);
  return user ?? null;
}

// ── This function ──────────────────────────────────────────────────────────


Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const user = await caller(req);
  if (!user) return json({ error: "unauthorized" }, 401);

  let txRef = "";
  try {
    txRef = String((await req.json()).tx_ref ?? "");
  } catch (_) {
    return json({ error: "bad_request" }, 400);
  }
  if (!txRef) return json({ error: "bad_request" }, 400);

  const { data: payment } = await admin
    .schema("nata")
    .from("payments")
    .select("sender_id, status, provider, created_at")
    .eq("tx_ref", txRef)
    .maybeSingle();
  if (!payment || payment.sender_id !== user.id) {
    return json({ error: "not_found" }, 404);
  }
  if (payment.status === "held" || payment.status === "released") {
    return json({ status: "successful" });
  }
  if (payment.status !== "pending") return json({ status: "failed" });

  if (payment.provider === "stripe") {
    if (!stripeKey()) return json({ error: "payments_unavailable" }, 503);
    try {
      return json({ status: await recordPaymentIntent(txRef) });
    } catch (e) {
      console.error("[verify-payment] stripe", e);
      return json({ status: "pending" });
    }
  }

  if (payment.provider === "pawapay") {
    if (!pawapayToken()) return json({ error: "payments_unavailable" }, 503);
    try {
      const status = await recordDeposit(txRef);
      if (status !== "not_found") return json({ status });
      // pawaPay never got it (create-payment had no answer): give it a
      // couple of minutes, then call it failed.
      const age = Date.now() - new Date(String(payment.created_at)).getTime();
      if (age < 2 * 60 * 1000) return json({ status: "pending" });
      await admin.schema("nata").rpc("fail_payment", {
        p_tx_ref: txRef,
        p_transaction_id: null,
      });
      return json({ status: "failed" });
    } catch (e) {
      console.error("[verify-payment] pawapay", e);
      return json({ status: "pending" });
    }
  }

  if (payment.provider === "flutterwave") {
    if (!flutterwaveKey()) return json({ error: "payments_unavailable" }, 503);
    try {
      return json({ status: await recordFlutterwave(txRef) });
    } catch (e) {
      console.error("[verify-payment] flutterwave", e);
      return json({ status: "pending" });
    }
  }

  return json({ status: "failed" });
});
