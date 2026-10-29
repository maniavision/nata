/**
 * delete-account — closes the signed-in user's account; their data is erased
 * 7 days later (20240191_account_deletion_grace.sql).
 *
 * Called by the app (with the user's JWT), no body. First
 * public.schedule_account_deletion() runs as the user: it refuses while money
 * or a delivery is in flight, otherwise it cancels what is open, stops pushes
 * and marks the account for deletion. Then the user is signed out on every
 * device. Signing in within 7 days lets them restore the account
 * (public.restore_my_account); after that the purge-deleted-accounts function
 * erases their data, files and sign-in.
 *
 * Responds 200 with { deleted: true, scheduled: true, purge_after } (the app
 * builds from before 20240191 only look at the status). Errors:
 * 401 unauthorized, 409 with { error: "nata:..." } when the account can't be
 * deleted yet, 500 failed (safe to call again).
 *
 * SUPABASE_URL, SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY are provided
 * by Supabase.
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

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }

  const auth = req.headers.get("Authorization") ?? "";
  const token = auth.replace(/^Bearer\s+/i, "");
  if (!token) return json({ error: "unauthorized" }, 401);
  const { data: { user } } = await admin.auth.getUser(token);
  if (!user) return json({ error: "unauthorized" }, 401);

  // As the user, so auth.uid() is theirs.
  const asUser = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    {
      auth: { persistSession: false },
      global: { headers: { Authorization: auth } },
    },
  );
  const { data: purgeAfter, error: rpcError } = await asUser.rpc(
    "schedule_account_deletion",
  );
  if (rpcError) {
    const code = rpcError.message.match(/nata:[a-z_]+/)?.[0];
    if (code) return json({ error: code }, 409);
    console.error("[delete-account] rpc:", rpcError.message);
    return json({ error: "failed" }, 500);
  }

  // Signed out on every device: coming back means signing in again, which
  // offers to restore the account.
  const { error: signOutError } = await admin.auth.admin.signOut(
    token,
    "global",
  );
  if (signOutError) {
    // The account is closed either way; the app signs out this device.
    console.error("[delete-account] sign out:", signOutError.message);
  }

  return json({ deleted: true, scheduled: true, purge_after: purgeAfter });
});
