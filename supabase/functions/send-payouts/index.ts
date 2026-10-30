/**
 * send-payouts — pays travelers: pawaPay payouts to their mobile money
 * (20240169), Stripe transfers to the Stripe account of travelers paid to
 * a bank (20240170), which Stripe then pays out to their bank, and
 * Flutterwave transfers to the bank of travelers living in Nigeria
 * (20240198). Flutterwave only takes transfers from whitelisted addresses,
 * so the database sends those itself (nata.flutterwave_transfer) and
 * flutterwave-webhook records the result.
 *
 * Called by the app (with the traveler's JWT) right after a delivery is
 * confirmed, after adding a payout account, and from Withdraw
 * ({ withdraw: true }), which sends that traveler's payouts, including what
 * they keep in their Nata balance (20240187); or with the x-job-secret header (matching
 * PAYMENT_JOBS_SECRET) from the payment-jobs schedule
 * (nata.call_send_payouts), with { traveler } or for everyone's.
 *
 * nata.claim_payouts takes the pending payouts that have an account to go
 * to (a pawaPay network, a Stripe account Stripe allows payouts on, or a
 * Nigerian bank). A Stripe transfer carries the payout's reference as its
 * transfer_group, and Stripe is asked first whether one was already made,
 * so a payout is never transferred twice; it is paid as soon as Stripe
 * makes it. Each pawaPay attempt has its own pawaPay payoutId (pawaPay never
 * pays one twice), kept on the payout before it is sent so an attempt
 * pawaPay took without answering is still found. Payouts with nowhere to go
 * yet (no payout
 * account, or a bank account: bank payouts aren't sent yet) stay pending.
 * pawaPay reports the result to pawapay-callback; the schedule also looks
 * again at payouts still in progress after a few minutes (Flutterwave's
 * through nata.check_flutterwave_transfer).
 *
 * Responds 200 with { sent, failed } (sent: taken by pawaPay). Errors:
 * 401 unauthorized, 503 payments_unavailable.
 */

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

/** The signed-in user calling the function, from their JWT. */
async function caller(req: Request) {
  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) return null;
  const { data: { user } } = await admin.auth.getUser(token);
  return user ?? null;
}

/** A call from the payment-jobs schedule, which may send everyone's. */
function isJob(req: Request): boolean {
  const secret = Deno.env.get("PAYMENT_JOBS_SECRET")?.trim();
  return !!secret && req.headers.get("x-job-secret") === secret;
}

/** pawaPay failures worth trying again later (Nata's wallet was short). */
const PAWAPAY_RETRY = ["PAWAPAY_WALLET_OUT_OF_FUNDS", "UNKNOWN_ERROR"];

/**
 * Looks the pawaPay payout [payoutId] up and records it: 'paid' (completed:
 * the escrow payment is released), 'failed', 'pending' (still in
 * progress), or 'not_found' when pawaPay never got it.
 */
async function recordPayout(reference: string, payoutId: string): Promise<string> {
  const res = await pawapay(`/v2/payouts/${encodeURIComponent(payoutId)}`);
  if (res.status !== 200) return "pending";
  if (res.body.status === "NOT_FOUND") return "not_found";
  const d = res.body.data as Record<string, unknown> | undefined;
  if (res.body.status !== "FOUND" || !d || d.payoutId !== payoutId) return "pending";
  const db = admin.schema("nata");
  if (d.status === "COMPLETED") {
    const { error } = await db.rpc("release_payout", {
      p_reference: reference,
      p_provider_id: payoutId,
    });
    if (error) throw error;
    return "paid";
  }
  if (d.status === "FAILED") {
    const reason = d.failureReason as
      | { failureCode?: string; failureMessage?: string }
      | undefined;
    const { error } = await db.rpc("payout_failed", {
      p_reference: reference,
      p_reason: String(reason?.failureMessage ?? reason?.failureCode ?? "Payout failed"),
      p_retry: PAWAPAY_RETRY.includes(String(reason?.failureCode ?? "")),
    });
    if (error) throw error;
    return "failed";
  }
  return "pending";
}

/**
 * Sends the payout [p] to the traveler's Stripe account ([p.account_number])
 * as a transfer in US dollars, and records it paid, or failed (tried again
 * later when Nata's Stripe balance was short or Stripe didn't answer).
 */
async function transferWithStripe(p: {
  reference: string;
  amount: number;
  currency: string;
  account_number: string;
}): Promise<boolean> {
  const db = admin.schema("nata");
  const fail = async (reason: string, retry: boolean) => {
    await db.rpc("payout_failed", {
      p_reference: p.reference,
      p_reason: reason,
      p_retry: retry,
    });
    return false;
  };
  if (!stripeKey()) return fail("Stripe isn't set up", true);
  if (p.currency.toUpperCase() !== "USD") {
    return fail(`A Stripe payout in ${p.currency}`, false);
  }

  // Already transferred (Stripe took it without answering last time)?
  const existing = await stripe(
    `/transfers?transfer_group=${encodeURIComponent(p.reference)}&limit=10`,
  );
  if (existing.status === 0 || existing.status >= 500) {
    return fail(`Stripe unreachable (HTTP ${existing.status})`, true);
  }
  const made = ((existing.body.data ?? []) as { id?: string; reversed?: boolean }[])
    .find((x) => x.id && !x.reversed);
  if (made?.id) {
    await db.rpc("release_payout", { p_reference: p.reference, p_provider_id: made.id });
    return true;
  }

  const res = await stripe("/transfers", {
    method: "POST",
    idempotencyKey: `${p.reference}-${crypto.randomUUID()}`,
    form: {
      amount: String(Math.round(Number(p.amount) * 100)),
      currency: "usd",
      destination: p.account_number,
      transfer_group: p.reference,
      description: "Nata delivery payout",
      "metadata[payout_reference]": p.reference,
    },
  });
  const id = String(res.body.id ?? "");
  if (res.status === 200 && id.startsWith("tr_")) {
    await db.rpc("release_payout", { p_reference: p.reference, p_provider_id: id });
    return true;
  }
  const err = res.body.error as { code?: string; message?: string } | undefined;
  console.error("[send-payouts] stripe", res.status, err?.code, err?.message);
  return fail(
    err?.message || `Stripe transfer HTTP ${res.status}`,
    res.status === 0 || res.status >= 500 || res.status === 429 ||
      err?.code === "balance_insufficient",
  );
}

// ── This function ──────────────────────────────────────────────────────────

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  if (!pawapayToken() && !stripeKey()) {
    return json({ error: "payments_unavailable" }, 503);
  }
  const job = isJob(req);
  const user = job ? null : await caller(req);
  if (!job && !user) return json({ error: "unauthorized" }, 401);

  // The schedule may name one traveler; the app always sends its own.
  // Withdraw ({ withdraw: true }, from the app) also sends what the member
  // keeps in their Nata balance (20240187).
  let traveler: string | null = user?.id ?? null;
  let withdraw = false;
  let body: Record<string, unknown> = {};
  try {
    body = (await req.json()) ?? {};
  } catch (_) {
    body = {};
  }
  if (job) {
    const t = String(body.traveler ?? "");
    traveler = UUID.test(t) ? t : null;
  } else {
    withdraw = body.withdraw === true;
  }

  const db = admin.schema("nata");
  const { data: claimed, error } = await db.rpc("claim_payouts", {
    p_traveler: traveler,
    p_withdraw: withdraw,
  });
  if (error) {
    console.error("[send-payouts] claim", error);
    return json({ sent: 0, failed: 0 });
  }

  let sent = 0;
  let failed = 0;
  for (const p of (claimed ?? []) as {
    payout_id: string;
    reference: string;
    amount: number;
    currency: string;
    account_bank: string;
    account_number: string;
    provider: string;
  }[]) {
    if (p.provider === "flutterwave") {
      const { data: outcome, error: flwError } = await db.rpc(
        "flutterwave_transfer",
        { p_reference: p.reference },
      );
      if (flwError) console.error("[send-payouts] flutterwave", flwError);
      if (outcome === "sent") sent++;
      else failed++;
      continue;
    }
    if (p.provider === "stripe" || p.account_bank === "STRIPE") {
      if (await transferWithStripe(p)) sent++;
      else failed++;
      continue;
    }
    if (!pawapayToken()) {
      await db.rpc("payout_failed", {
        p_reference: p.reference,
        p_reason: "pawaPay isn't set up",
        p_retry: true,
      });
      failed++;
      continue;
    }
    const payoutId = crypto.randomUUID();
    await db.rpc("payout_accepted", {
      p_reference: p.reference,
      p_provider_id: payoutId,
    });
    const res = await pawapay("/v2/payouts", {
      method: "POST",
      body: {
        payoutId,
        amount: String(Number(p.amount)),
        currency: p.currency,
        recipient: {
          type: "MMO",
          accountDetails: {
            phoneNumber: p.account_number,
            provider: p.account_bank,
          },
        },
        clientReferenceId: p.reference,
        customerMessage: "Nata payout",
      },
    });
    const status = String(res.body.status ?? "");
    if (
      status === "ACCEPTED" || status === "DUPLICATE_IGNORED" ||
      // No answer: it may have been taken, so it's looked up again later
      // (and sent again, as a new attempt, if pawaPay never got it).
      res.status === 0 || res.status >= 500
    ) {
      sent++;
      continue;
    }
    const reason = res.body.failureReason as
      | { failureCode?: string; failureMessage?: string }
      | undefined;
    const code = String(reason?.failureCode ?? "");
    console.error("[send-payouts] pawapay", res.status, code, reason?.failureMessage);
    await db.rpc("payout_failed", {
      p_reference: p.reference,
      p_reason: String(reason?.failureMessage || code || `HTTP ${res.status}`),
      p_retry: PAWAPAY_RETRY.includes(code),
    });
    failed++;
  }

  // Payouts still in progress after a few minutes (a callback that never
  // came): ask pawaPay or Flutterwave. Only the schedule does this.
  if (job) {
    const { data: waiting } = await db.from("payouts")
      .select("reference, provider_payout_id")
      .eq("status", "processing")
      .not("provider_payout_id", "is", null)
      .lt("updated_at", new Date(Date.now() - 5 * 60 * 1000).toISOString())
      .limit(50);
    for (const w of (waiting ?? []) as { reference: string; provider_payout_id: string }[]) {
      if (/^[0-9]+$/.test(w.provider_payout_id)) {
        // A Flutterwave transfer: the database asks, from its own address.
        const { error: checkError } = await db.rpc("check_flutterwave_transfer", {
          p_reference: w.reference,
        });
        if (checkError) console.error("[send-payouts] flutterwave check", checkError);
        continue;
      }
      if (!UUID.test(w.provider_payout_id)) continue; // not a pawaPay payout
      try {
        const status = await recordPayout(w.reference, w.provider_payout_id);
        if (status === "not_found") {
          // pawaPay never got it: queue it again (a new attempt).
          await db.rpc("payout_failed", {
            p_reference: w.reference,
            p_reason: "Not received by pawaPay",
            p_retry: true,
          });
        }
      } catch (e) {
        console.error("[send-payouts] pawapay check", e);
      }
    }
  }

  return json({ sent, failed });
});
