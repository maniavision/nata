/**
 * send-refunds — gives senders their money back: Stripe refunds for cards
 * and Apple Pay, pawaPay refunds for mobile money. A payment made through a
 * provider Nata no longer uses (Flutterwave) is marked failed, for support
 * to refund by hand.
 *
 * Called by the app (with the sender's JWT) right after a paid request is
 * cancelled, which sends that sender's pending refunds; or with the service
 * role key (support) or from the payment-jobs schedule (the x-job-secret
 * header, matching PAYMENT_JOBS_SECRET; 20240147) to send everyone's. Refunds are queued by
 * the database (20240145_refunds.sql): a cancellation after payment keeps
 * Nata's 10% fee, a payment flagged needs_refund is refunded in full.
 *
 * A pawaPay refund finishes later: its id is kept (nata.refund_started,
 * 20240165) and it is marked sent once pawaPay completes it, by its callback
 * (pawapay-callback) or by this function looking again at refunds still in
 * progress after a few minutes.
 *
 * A Stripe refund is marked sent once Stripe takes it (succeeded, or
 * pending at the card's bank). Stripe is asked first whether the payment
 * already has a refund, so one Stripe took without answering is never sent
 * twice.
 *
 * Responds 200 with { sent, failed, started }. Errors: 401 unauthorized,
 * 503 payments_unavailable.
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

/** pawaPay failures worth trying again later (Nata's wallet was short). */
const PAWAPAY_RETRY = ["PAWAPAY_WALLET_OUT_OF_FUNDS", "UNKNOWN_ERROR"];

/**
 * Looks a pawaPay refund up and records it: 'sent' (completed), 'failed',
 * 'pending' (still processing), or 'not_found'.
 */
async function recordRefund(paymentId: string, refundId: string): Promise<string> {
  const res = await pawapay(`/v2/refunds/${encodeURIComponent(refundId)}`);
  if (res.status !== 200) return "pending";
  if (res.body.status === "NOT_FOUND") return "not_found";
  const d = res.body.data as Record<string, unknown> | undefined;
  if (res.body.status !== "FOUND" || !d || d.refundId !== refundId) return "pending";
  const db = admin.schema("nata");
  if (d.status === "COMPLETED") {
    const { error } = await db.rpc("refund_sent", {
      p_payment_id: paymentId,
      p_provider_id: refundId,
    });
    if (error) throw error;
    return "sent";
  }
  if (d.status === "FAILED") {
    const reason = d.failureReason as
      | { failureCode?: string; failureMessage?: string }
      | undefined;
    const { error } = await db.rpc("refund_failed", {
      p_payment_id: paymentId,
      p_reason: String(reason?.failureMessage ?? reason?.failureCode ?? "Refund failed"),
      p_retry: PAWAPAY_RETRY.includes(String(reason?.failureCode ?? "")),
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

/**
 * Refunds [r.amount] of the PaymentIntent [r.transaction_id] through Stripe,
 * and records it sent or failed.
 */
async function refundWithStripe(r: {
  payment_id: string;
  transaction_id: string;
  amount: number;
  currency: string;
}): Promise<"sent" | "failed"> {
  const db = admin.schema("nata");
  const fail = async (reason: string, retry: boolean) => {
    await db.rpc("refund_failed", {
      p_payment_id: r.payment_id,
      p_reason: reason,
      p_retry: retry,
    });
    return "failed" as const;
  };
  if (!stripeKey()) return fail("Stripe isn't set up", true);

  // Already refunded (a refund Stripe took without answering last time)?
  const existing = await stripe(
    `/refunds?payment_intent=${encodeURIComponent(r.transaction_id)}&limit=10`,
  );
  if (existing.status === 0 || existing.status >= 500) {
    return fail(`Stripe unreachable (HTTP ${existing.status})`, true);
  }
  const taken = ((existing.body.data ?? []) as { id?: string; status?: string }[])
    .find((x) => x.status === "succeeded" || x.status === "pending");
  if (taken?.id) {
    await db.rpc("refund_sent", {
      p_payment_id: r.payment_id,
      p_provider_id: taken.id,
    });
    return "sent";
  }

  const res = await stripe("/refunds", {
    method: "POST",
    idempotencyKey: `nata-refund-${r.payment_id}-${Date.now()}`,
    form: {
      payment_intent: r.transaction_id,
      amount: String(toStripeAmount(Number(r.amount), r.currency)),
      "metadata[payment_id]": r.payment_id,
    },
  });
  const status = String(res.body.status ?? "");
  if (res.status === 200 && (status === "succeeded" || status === "pending")) {
    await db.rpc("refund_sent", {
      p_payment_id: r.payment_id,
      p_provider_id: String(res.body.id ?? ""),
    });
    return "sent";
  }
  const err = res.body.error as { message?: string } | undefined;
  return fail(
    err?.message || `Stripe refund ${status || `HTTP ${res.status}`}`,
    res.status === 0 || res.status >= 500 || res.status === 429,
  );
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  if (!pawapayToken() && !stripeKey()) {
    return json({ error: "payments_unavailable" }, 503);
  }

  // The service role sends everyone's refunds; a signed-in sender, their own.
  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  const jobSecret = Deno.env.get("PAYMENT_JOBS_SECRET")?.trim();
  const isService = (!!token &&
    token === Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")) ||
    (!!jobSecret && req.headers.get("x-job-secret") === jobSecret);
  const user = isService ? null : await caller(req);
  if (!isService && !user) return json({ error: "unauthorized" }, 401);

  const db = admin.schema("nata");
  const { data: claimed, error } = await db.rpc("claim_refunds", {
    p_sender: user?.id ?? null,
  });
  if (error) {
    console.error("[send-refunds] claim", error);
    return json({ sent: 0, failed: 0 });
  }

  let sent = 0;
  let failed = 0;
  let started = 0;
  const refunds = (claimed ?? []) as {
    payment_id: string;
    transaction_id: string;
    amount: number;
    currency: string;
  }[];
  const { data: providers } = refunds.length
    ? await db.from("payments")
      .select("id, provider")
      .in("id", refunds.map((r) => r.payment_id))
    : { data: [] };
  const providerOf = new Map(
    ((providers ?? []) as { id: string; provider: string }[])
      .map((p) => [p.id, p.provider]),
  );
  const viaPawapay = new Set(
    [...providerOf].filter(([, p]) => p === "pawapay").map(([id]) => id),
  );

  for (const r of refunds) {
    if (providerOf.get(r.payment_id) === "stripe") {
      const outcome = await refundWithStripe(r);
      if (outcome === "sent") sent++;
      else failed++;
      continue;
    }
    if (viaPawapay.has(r.payment_id)) {
      if (!pawapayToken()) {
        await db.rpc("refund_failed", {
          p_payment_id: r.payment_id,
          p_reason: "pawaPay isn't set up",
          p_retry: true,
        });
        failed++;
        continue;
      }
      // The id is kept first, so a refund pawaPay took without answering
      // is still found later.
      const refundId = crypto.randomUUID();
      await db.rpc("refund_started", {
        p_payment_id: r.payment_id,
        p_provider_id: refundId,
      });
      const res = await pawapay("/v2/refunds", {
        method: "POST",
        body: {
          refundId,
          depositId: r.transaction_id,
          amount: String(Number(r.amount)),
          currency: r.currency,
        },
      });
      const status = String(res.body.status ?? "");
      if (status === "ACCEPTED" || status === "DUPLICATE_IGNORED") {
        started++;
      } else if (res.status === 0 || res.status >= 500) {
        // Unknown: looked at again below on a later run.
        started++;
      } else {
        const reason = res.body.failureReason as
          | { failureCode?: string; failureMessage?: string }
          | undefined;
        const code = String(reason?.failureCode ?? "");
        await db.rpc("refund_failed", {
          p_payment_id: r.payment_id,
          p_reason: String(reason?.failureMessage ?? code ?? `HTTP ${res.status}`),
          p_retry: PAWAPAY_RETRY.includes(code),
        });
        failed++;
      }
      continue;
    }
    // Flutterwave is no longer used: support refunds these by hand.
    await db.rpc("refund_failed", {
      p_payment_id: r.payment_id,
      p_reason: "Paid through Flutterwave, no longer used: refund by hand",
      p_retry: false,
    });
    failed++;
  }

  // pawaPay refunds still in progress after a few minutes (a callback that
  // never came): ask pawaPay. Only the schedule or support does this.
  if (isService && pawapayToken()) {
    const { data: waiting } = await db.from("payments")
      .select("id, refund_provider_id")
      .eq("provider", "pawapay")
      .eq("refund_status", "processing")
      .not("refund_provider_id", "is", null)
      .lt("updated_at", new Date(Date.now() - 5 * 60 * 1000).toISOString())
      .limit(50);
    for (const p of (waiting ?? []) as { id: string; refund_provider_id: string }[]) {
      try {
        const status = await recordRefund(p.id, p.refund_provider_id);
        if (status === "sent") sent++;
        if (status === "failed") failed++;
        if (status === "not_found") {
          // pawaPay never took it: queue it again.
          await db.rpc("refund_failed", {
            p_payment_id: p.id,
            p_reason: "Not received by pawaPay",
            p_retry: true,
          });
        }
      } catch (e) {
        console.error("[send-refunds] pawapay check", e);
      }
    }
  }

  return json({ sent, failed, started });
});
