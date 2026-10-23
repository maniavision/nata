/**
 * pawapay-callback — pawaPay tells Nata a deposit (a sender's mobile money
 * payment) or a refund reached its final status (20240165).
 *
 * Set as the deposits and refunds callback URL in pawaPay's dashboard, and
 * deployed with --no-verify-jwt: pawaPay has no Supabase login. The body is
 * never trusted: the deposit or refund is looked up again with pawaPay
 * (PAWAPAY_API_TOKEN) and only what pawaPay answers is recorded, so a forged
 * callback can do no more than ask for that check.
 *
 * Responds 200 { received: true }; 500 when recording failed, so pawaPay
 * sends it again.
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

/**
 * Looks a pawaPay deposit up and records it as record() does for
 * Flutterwave: 'successful', 'failed', 'pending', or 'not_found' while
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

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  if (!pawapayToken()) return json({ error: "payments_unavailable" }, 503);

  let depositId = "";
  let refundId = "";
  try {
    const body = await req.json();
    depositId = String(body?.depositId ?? "");
    refundId = String(body?.refundId ?? "");
  } catch (_) {
    return json({ error: "bad_request" }, 400);
  }

  const db = admin.schema("nata");
  try {
    if (UUID.test(refundId)) {
      const { data: payment } = await db.from("payments")
        .select("id")
        .eq("provider", "pawapay")
        .eq("refund_provider_id", refundId)
        .maybeSingle();
      if (payment) await recordRefund(String(payment.id), refundId);
    } else if (UUID.test(depositId)) {
      const { data: payment } = await db.from("payments")
        .select("id, status")
        .eq("provider", "pawapay")
        .eq("tx_ref", depositId)
        .maybeSingle();
      if (payment?.status === "pending") await recordDeposit(depositId);
    }
    // Anything else (a payout, or not one of ours): nothing to record.
    return json({ received: true });
  } catch (e) {
    console.error("[pawapay-callback]", e);
    return json({ error: "retry" }, 500);
  }
});
