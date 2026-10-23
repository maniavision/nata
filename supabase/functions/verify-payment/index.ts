/**
 * verify-payment — where a payment the sender started stands. The app asks
 * while the sender is on Flutterwave's page (or approving a mobile money
 * prompt on their phone), so it doesn't depend on the
 * webhook arriving first.
 *
 * Called by the app (with the sender's JWT) with { tx_ref }. A pending
 * payment is checked with its provider and recorded once it is settled:
 * Flutterwave for cards, Apple Pay and bank transfer, pawaPay for mobile
 * money (20240165; the tx_ref is the deposit id).
 *
 * Responds 200 with { status: pending | successful | failed }: successful
 * once the money is held in escrow (or already released).
 * Errors: 401 unauthorized, 404 not_found, 503 payments_unavailable.
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

  if (!secretKey()) return json({ error: "payments_unavailable" }, 503);
  try {
    const tx = await transactionByRef(txRef);
    // No transaction yet: the sender hasn't paid.
    if (!tx || tx.tx_ref !== txRef) return json({ status: "pending" });
    return json({ status: await record(tx) });
  } catch (e) {
    console.error("[verify-payment]", e);
    return json({ status: "pending" });
  }
});
