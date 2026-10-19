/**
 * delete-account — deletes the signed-in user's account.
 *
 * Called by the app (with the user's JWT), no body. First
 * public.delete_my_account() runs as the user: it refuses while money or a
 * delivery is in flight, otherwise it cancels what is open, deletes their
 * personal data and leaves an anonymised "Deleted user" profile behind (see
 * supabase/migrations/20240156_delete_account.sql). Then, with the service
 * role, their files are removed (identity-documents/<id>/ and
 * user-assets/avatars/<id>/) and the auth user is deleted.
 *
 * Responds 200 with { deleted: true }. Errors: 401 unauthorized, 409 with
 * { error: "nata:..." } when the account can't be deleted yet, 500 failed
 * (safe to call again: every step can be repeated).
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

/** Folders that hold only this user's files, by bucket. */
const FOLDERS = (uid: string) => [
  { bucket: "identity-documents", prefix: uid },
  { bucket: "user-assets", prefix: `avatars/${uid}` },
];

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

/** Every file under [prefix], subfolders included. */
async function listFiles(bucket: string, prefix: string): Promise<string[]> {
  const files: string[] = [];
  const { data, error } = await admin.storage.from(bucket).list(prefix, {
    limit: 1000,
  });
  if (error) throw new Error(`${bucket}/${prefix}: ${error.message}`);
  for (const item of data ?? []) {
    const path = `${prefix}/${item.name}`;
    // Folders have no id.
    if (item.id) files.push(path);
    else files.push(...await listFiles(bucket, path));
  }
  return files;
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
  const { error: rpcError } = await asUser.rpc("delete_my_account");
  if (rpcError) {
    const code = rpcError.message.match(/nata:[a-z_]+/)?.[0];
    if (code) return json({ error: code }, 409);
    console.error("[delete-account] rpc:", rpcError.message);
    return json({ error: "failed" }, 500);
  }

  try {
    for (const { bucket, prefix } of FOLDERS(user.id)) {
      const files = await listFiles(bucket, prefix);
      for (let i = 0; i < files.length; i += 100) {
        const { error } = await admin.storage.from(bucket).remove(
          files.slice(i, i + 100),
        );
        if (error) throw new Error(`${bucket}: ${error.message}`);
      }
    }
  } catch (e) {
    console.error("[delete-account] files:", (e as Error).message);
    return json({ error: "failed" }, 500);
  }

  const { error: authError } = await admin.auth.admin.deleteUser(user.id);
  if (authError) {
    console.error("[delete-account] auth user:", authError.message);
    return json({ error: "failed" }, 500);
  }

  return json({ deleted: true });
});
