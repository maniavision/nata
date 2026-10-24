/**
 * stripe-webhook — Stripe's notices about card and Apple Pay payments
 * (payment_intent.succeeded, payment_intent.canceled), and about travelers'
 * connected accounts for bank payouts (account.updated, 20240170).
 *
 * Set in the Stripe dashboard (Developers > Webhooks) to
 *   https://<project>.supabase.co/functions/v1/stripe-webhook
 * twice: for those payment events on Nata's account (its signing secret is
 * the STRIPE_WEBHOOK_SECRET secret), and for account.updated on connected
 * accounts (STRIPE_CONNECT_WEBHOOK_SECRET).
 * Deployed with --no-verify-jwt: Stripe has no Supabase login, so each
 * notice's Stripe-Signature is checked instead (and must be under 5 minutes
 * old).
 *
 * The notice itself is not trusted: the PaymentIntent or account is looked
 * up again with Stripe before anything is recorded. Ones that aren't Nata's
 * are ignored.
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

/**
 * Keeps nata.stripe_accounts in step with the Stripe account [account] (as
 * Stripe returns it) of [userId]. Once Stripe allows payouts, the bank is one
 * of the traveler's payout accounts (kind bank, paid in US dollars): added
 * as their default the first time (20240172), and again only when [save]
 * (the traveler tapped "Use this bank"), so a removed one stays removed. A
 * bank already among their accounts gets its name and last digits kept up
 * to date. Answers the bank's name and last digits once payouts are allowed.
 */
async function syncAccount(
  userId: string,
  account: Record<string, unknown>,
  save = false,
): Promise<{ institution: string; last4: string } | null> {
  const db = admin.schema("nata");
  const id = String(account.id ?? "");
  const payoutsEnabled = account.payouts_enabled === true;
  await db.from("stripe_accounts").update({
    details_submitted: account.details_submitted === true,
    payouts_enabled: payoutsEnabled,
    updated_at: new Date().toISOString(),
  }).eq("user_id", userId).eq("account_id", id);
  if (!payoutsEnabled) return null;

  const banks = ((account.external_accounts as { data?: unknown[] } | undefined)
    ?.data ?? []) as { bank_name?: string; last4?: string }[];
  const bank = banks[0] ?? {};
  let institution = String(bank.bank_name ?? "").trim().slice(0, 80) ||
    "Bank account";
  if (institution.length < 2) institution = "Bank account";
  const last4 = String(bank.last4 ?? "").toUpperCase().replace(/[^0-9A-Z]/g, "")
    .slice(-4).padStart(4, "0");

  const { data: existing } = await db.from("payout_destinations")
    .select("account_id")
    .eq("account_bank", "STRIPE")
    .eq("account_number", id)
    .maybeSingle();
  if (existing) {
    await db.from("payout_accounts")
      .update({ institution_name: institution, account_last4: last4 })
      .eq("id", existing.account_id)
      .eq("user_id", userId);
    return { institution, last4 };
  }

  // Added once by itself; after the traveler removed it, only when asked.
  const { data: row } = await db.from("stripe_accounts")
    .select("bank_added_at")
    .eq("user_id", userId)
    .eq("account_id", id)
    .maybeSingle();
  if (row?.bank_added_at && !save) return { institution, last4 };

  const { data: profile } = await db.from("profiles")
    .select("first_name, last_name")
    .eq("id", userId)
    .maybeSingle();
  const holder = [profile?.first_name, profile?.last_name]
    .filter((p) => p && String(p).trim())
    .join(" ").trim().slice(0, 80);
  const { data: saved, error } = await db.from("payout_accounts").insert({
    user_id: userId,
    kind: "bank",
    institution_name: institution,
    country_code: String(account.country ?? "").toUpperCase() || null,
    account_last4: last4,
    holder_name: holder.length >= 2 ? holder : "Nata traveler",
    // The bank the traveler just connected is where they want to be paid.
    is_default: true,
  }).select("id").single();
  if (error || !saved) {
    console.error("[stripe-webhook] payout account", error);
    return { institution, last4 };
  }
  const { error: destError } = await db.from("payout_destinations").insert({
    account_id: saved.id,
    account_bank: "STRIPE",
    account_number: id,
    currency: "USD",
  });
  if (destError) {
    console.error("[stripe-webhook] payout destination", destError);
    await db.from("payout_accounts").delete().eq("id", saved.id);
    return { institution, last4 };
  }
  await db.from("stripe_accounts")
    .update({ bank_added_at: new Date().toISOString() })
    .eq("user_id", userId)
    .eq("account_id", id);
  return { institution, last4 };
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

  const payload = await req.text();
  const signature = req.headers.get("Stripe-Signature") ?? "";
  const secrets = [
    Deno.env.get("STRIPE_WEBHOOK_SECRET")?.trim() ?? "",
    Deno.env.get("STRIPE_CONNECT_WEBHOOK_SECRET")?.trim() ?? "",
  ].filter((s) => s);
  let signed = false;
  for (const secret of secrets) {
    if (await signedByStripe(payload, signature, secret)) signed = true;
  }
  if (!stripeKey() || !signed) return json({ error: "unauthorized" }, 401);

  let type = "";
  let id = "";
  try {
    const event = JSON.parse(payload);
    type = String(event?.type ?? "");
    id = String(event?.data?.object?.id ?? "");
  } catch (_) {
    return json({ error: "bad_request" }, 400);
  }
  if (type === "account.updated" && id.startsWith("acct_")) {
    try {
      const { data: row } = await admin.schema("nata").from("stripe_accounts")
        .select("user_id")
        .eq("account_id", id)
        .maybeSingle();
      if (row) {
        const res = await stripe(`/accounts/${encodeURIComponent(id)}`);
        if (res.status !== 200) return json({ error: "retry" }, 500);
        await syncAccount(String(row.user_id), res.body);
      }
      return json({ received: true });
    } catch (e) {
      console.error("[stripe-webhook] account", e);
      return json({ error: "retry" }, 500);
    }
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
