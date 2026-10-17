/**
 * send-refunds — gives senders their money back with Flutterwave refunds.
 *
 * Called by the app (with the sender's JWT) right after a paid request is
 * cancelled, which sends that sender's pending refunds; or with the service
 * role key (a schedule, or support) to send everyone's. Refunds are queued by
 * the database (20240145_refunds.sql): a cancellation after payment keeps
 * Nata's 10% fee, a payment flagged needs_refund is refunded in full.
 *
 * Responds 200 with { sent, failed }. Errors: 401 unauthorized,
 * 503 payments_unavailable.
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

// ── This function ──────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  if (!secretKey()) return json({ error: "payments_unavailable" }, 503);

  // The service role sends everyone's refunds; a signed-in sender, their own.
  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  const isService = !!token &&
    token === Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
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
  for (const r of (claimed ?? []) as {
    payment_id: string;
    transaction_id: string;
    amount: number;
  }[]) {
    try {
      const res = await flutterwave(
        `/transactions/${encodeURIComponent(r.transaction_id)}/refund`,
        { method: "POST", body: { amount: Number(r.amount) } },
      );
      const message = String(res.body.message ?? "");
      if (res.ok || /already been refunded|fully refunded/i.test(message)) {
        const id = (res.body.data as { id?: unknown } | undefined)?.id;
        await db.rpc("refund_sent", {
          p_payment_id: r.payment_id,
          p_provider_id: id == null ? null : String(id),
        });
        sent++;
      } else {
        await db.rpc("refund_failed", {
          p_payment_id: r.payment_id,
          p_reason: message || `HTTP ${res.status}`,
          p_retry: res.status >= 500,
        });
        failed++;
      }
    } catch (e) {
      // It may not have reached Flutterwave: try again later.
      await db.rpc("refund_failed", {
        p_payment_id: r.payment_id,
        p_reason: String(e),
        p_retry: true,
      });
      failed++;
    }
  }
  return json({ sent, failed });
});
