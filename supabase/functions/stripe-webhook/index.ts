/**
 * stripe-webhook — Stripe's notices about card and Apple Pay payments
 * (payment_intent.succeeded, payment_intent.canceled).
 *
 * Set in the Stripe dashboard (Developers > Webhooks) to
 *   https://<project>.supabase.co/functions/v1/stripe-webhook
 * for those events; its signing secret is the STRIPE_WEBHOOK_SECRET secret.
 * Deployed with --no-verify-jwt: Stripe has no Supabase login, so each
 * notice's Stripe-Signature is checked instead (and must be under 5 minutes
 * old).
 *
 * The notice itself is not trusted: the PaymentIntent is looked up again
 * with Stripe before anything is recorded. PaymentIntents that aren't one of
 * Nata's payments are ignored.
 */

// ── Stripe and Supabase helpers (the same in each payment function, so each
// can be deployed on its own, also from the dashboard) ──────────────────────

import { createClient } from "jsr:@supabase/supabase-js@2";

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

// ── This function ──────────────────────────────────────────────────────────

/** How old a notice may be, in seconds (Stripe's own default). */
const TOLERANCE = 300;

/** Compares without leaking how much of the signature matched. */
function sameSecret(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

/**
 * Whether [payload] was signed by Stripe with [secret]: the header is
 * "t=<time>,v1=<signature>[,v1=...]", the signature the HMAC-SHA256 of
 * "<time>.<payload>".
 */
async function signedByStripe(
  payload: string,
  header: string,
  secret: string,
): Promise<boolean> {
  let time = "";
  const signatures: string[] = [];
  for (const part of header.split(",")) {
    const [k, v] = part.split("=", 2);
    if (k?.trim() === "t") time = v?.trim() ?? "";
    if (k?.trim() === "v1" && v) signatures.push(v.trim());
  }
  const seconds = Number(time);
  if (!time || !Number.isFinite(seconds) || signatures.length === 0) return false;
  if (Math.abs(Date.now() / 1000 - seconds) > TOLERANCE) return false;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const mac = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(`${time}.${payload}`),
  );
  const expected = Array.from(new Uint8Array(mac))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
  return signatures.some((s) => sameSecret(s, expected));
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const secret = Deno.env.get("STRIPE_WEBHOOK_SECRET")?.trim() ?? "";
  const payload = await req.text();
  const signature = req.headers.get("Stripe-Signature") ?? "";
  if (!secret || !stripeKey() || !(await signedByStripe(payload, signature, secret))) {
    return json({ error: "unauthorized" }, 401);
  }

  let type = "";
  let id = "";
  try {
    const event = JSON.parse(payload);
    type = String(event?.type ?? "");
    id = String(event?.data?.object?.id ?? "");
  } catch (_) {
    return json({ error: "bad_request" }, 400);
  }
  if (!type.startsWith("payment_intent.") || !id.startsWith("pi_")) {
    return json({ received: true });
  }

  try {
    const { data: payment } = await admin
      .schema("nata")
      .from("payments")
      .select("status")
      .eq("provider", "stripe")
      .eq("tx_ref", id)
      .maybeSingle();
    // Not one of ours: nothing to record. (complete_payment and
    // fail_payment leave a payment already settled as it is.)
    if (payment) await recordPaymentIntent(id);
    return json({ received: true });
  } catch (e) {
    console.error("[stripe-webhook]", e);
    // Stripe retries on errors.
    return json({ error: "retry" }, 500);
  }
});
