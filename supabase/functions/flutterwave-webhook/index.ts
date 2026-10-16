/**
 * flutterwave-webhook — Flutterwave's notice that a payment was made.
 *
 * Set in the Flutterwave dashboard (Settings > Webhooks) to
 *   https://<project>.supabase.co/functions/v1/flutterwave-webhook
 * with a secret hash, also stored as the FLW_SECRET_HASH secret. Deployed
 * with --no-verify-jwt: Flutterwave has no Supabase login, so requests are
 * checked with the `verif-hash` header instead.
 *
 * The notice itself is not trusted: the transaction is looked up again with
 * Flutterwave before anything is recorded.
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


/** Compares without leaking how much of the hash matched. */
function sameSecret(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const expected = Deno.env.get("FLW_SECRET_HASH")?.trim() ?? "";
  const given = req.headers.get("verif-hash")?.trim() ?? "";
  if (!expected || !secretKey() || !sameSecret(given, expected)) {
    return json({ error: "unauthorized" }, 401);
  }

  let id = "";
  try {
    const body = await req.json();
    id = String(body?.data?.id ?? "");
  } catch (_) {
    return json({ error: "bad_request" }, 400);
  }
  if (!id) return json({ received: true });

  try {
    const tx = await transactionById(id);
    // Not one of ours (no nata- reference): nothing to record.
    if (tx && tx.tx_ref.startsWith("nata-")) await record(tx);
    return json({ received: true });
  } catch (e) {
    console.error("[flutterwave-webhook]", e);
    // Flutterwave retries on errors.
    return json({ error: "retry" }, 500);
  }
});
