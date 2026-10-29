/**
 * purge-deleted-accounts — erases the accounts whose 7 days after
 * "Delete account" are over (20240191_account_deletion_grace.sql).
 *
 * Called every day by nata.run_account_purge() (pg_cron) with the
 * x-job-secret header matching PAYMENT_JOBS_SECRET; nobody else. For each
 * account public.accounts_due_for_purge() lists, public.purge_due_account()
 * deletes the personal data and leaves the "Deleted user" profile, then the
 * member's files (identity-documents/<id>/, user-assets/avatars/<id>/) and
 * their sign-in are removed. An account with money or a delivery in flight
 * by then is skipped and tried again the next day, and so is one whose files
 * or sign-in couldn't be removed (public.finish_account_purge takes it off the
 * list once they are).
 *
 * Responds 200 with { purged, waiting, failed }. Errors: 401 unauthorized,
 * 500 failed.
 */

import { createClient } from "jsr:@supabase/supabase-js@2";
import { eraseFilesAndSignIn } from "../_shared/account_files.ts";

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

/** A call from the schedule (the payment-jobs secret, 20240147). */
function isJob(req: Request): boolean {
  const secret = Deno.env.get("PAYMENT_JOBS_SECRET")?.trim();
  return !!secret && req.headers.get("x-job-secret") === secret;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }
  if (!isJob(req)) return json({ error: "unauthorized" }, 401);

  const { data: due, error } = await admin.rpc("accounts_due_for_purge");
  if (error) {
    console.error("[purge-deleted-accounts] list:", error.message);
    return json({ error: "failed" }, 500);
  }

  let purged = 0, waiting = 0, failed = 0;
  for (const uid of (due ?? []) as string[]) {
    const { data: result, error: purgeError } = await admin.rpc(
      "purge_due_account",
      { p_user: uid },
    );
    if (purgeError) {
      console.error("[purge-deleted-accounts] purge", uid, purgeError.message);
      failed++;
      continue;
    }
    if (result !== "purged") {
      // Money or a delivery still in flight: tried again tomorrow.
      console.log("[purge-deleted-accounts] waiting", uid, result);
      waiting++;
      continue;
    }
    try {
      await eraseFilesAndSignIn(admin, uid);
      const { error: finishError } = await admin.rpc("finish_account_purge", {
        p_user: uid,
      });
      if (finishError) throw new Error(finishError.message);
      purged++;
    } catch (e) {
      // The data is gone; the account stays listed, so the next run tries
      // the files and the sign-in again.
      console.error(
        "[purge-deleted-accounts] files or sign-in left for",
        uid,
        (e as Error).message,
      );
      failed++;
    }
  }

  return json({ purged, waiting, failed });
});
