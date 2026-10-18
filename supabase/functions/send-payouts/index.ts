/**
 * send-payouts — sends the signed-in traveler's pending payouts with
 * Flutterwave transfers.
 *
 * Called by the app (with the traveler's JWT) right after a delivery is
 * confirmed, after adding a payout account, and from Withdraw, which sends
 * that traveler's payouts; or with the x-job-secret header (matching
 * PAYMENT_JOBS_SECRET) to send everyone's.
 *
 * The transfers themselves are asked for by the database
 * (nata.send_payouts, 20240151): Flutterwave only takes them from a
 * whitelisted IP address, which edge functions don't have. Payouts with
 * nowhere to go yet (no payout account) stay pending. Flutterwave then
 * reports the result to flutterwave-webhook (paid, or failed with its
 * reason).
 *
 * Responds 200 with { sent, failed }. Errors: 401 unauthorized,
 * 503 payments_unavailable.
 */

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

/** The signed-in user calling the function, from their JWT. */
async function caller(req: Request) {
  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) return null;
  const { data: { user } } = await admin.auth.getUser(token);
  return user ?? null;
}

/** A call from the payment-jobs schedule or support, which sends everyone's. */
function isJob(req: Request): boolean {
  const secret = Deno.env.get("PAYMENT_JOBS_SECRET")?.trim();
  return !!secret && req.headers.get("x-job-secret") === secret;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  if (!Deno.env.get("FLW_SECRET_KEY")?.trim()) {
    return json({ error: "payments_unavailable" }, 503);
  }
  const job = isJob(req);
  const user = job ? null : await caller(req);
  if (!job && !user) return json({ error: "unauthorized" }, 401);

  const { data, error } = await admin
    .schema("nata")
    .rpc("send_payouts", { p_traveler: user?.id ?? null })
    .maybeSingle();
  if (error) {
    console.error("[send-payouts]", error);
    return json({ sent: 0, failed: 0 });
  }
  const result = data as { sent?: number; failed?: number } | null;
  return json({ sent: result?.sent ?? 0, failed: result?.failed ?? 0 });
});
