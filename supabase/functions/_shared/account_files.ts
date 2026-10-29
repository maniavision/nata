/**
 * Erasing a member's files and sign-in, once their personal data is gone
 * (delete-account before 20240191, purge-deleted-accounts since).
 */

import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";

/** Folders that hold only this user's files, by bucket. */
const FOLDERS = (uid: string) => [
  { bucket: "identity-documents", prefix: uid },
  { bucket: "user-assets", prefix: `avatars/${uid}` },
];

/** Every file under [prefix], subfolders included. */
async function listFiles(
  admin: SupabaseClient,
  bucket: string,
  prefix: string,
): Promise<string[]> {
  const files: string[] = [];
  const { data, error } = await admin.storage.from(bucket).list(prefix, {
    limit: 1000,
  });
  if (error) throw new Error(`${bucket}/${prefix}: ${error.message}`);
  for (const item of data ?? []) {
    const path = `${prefix}/${item.name}`;
    // Folders have no id.
    if (item.id) files.push(path);
    else files.push(...await listFiles(admin, bucket, path));
  }
  return files;
}

/** Removes [uid]'s files, then their auth user. Safe to repeat. */
export async function eraseFilesAndSignIn(
  admin: SupabaseClient,
  uid: string,
): Promise<void> {
  for (const { bucket, prefix } of FOLDERS(uid)) {
    const files = await listFiles(admin, bucket, prefix);
    for (let i = 0; i < files.length; i += 100) {
      const { error } = await admin.storage.from(bucket).remove(
        files.slice(i, i + 100),
      );
      if (error) throw new Error(`${bucket}: ${error.message}`);
    }
  }
  const { error } = await admin.auth.admin.deleteUser(uid);
  // Already gone: nothing left to do.
  if (error && !/not.?found/i.test(error.message)) {
    throw new Error(`auth user: ${error.message}`);
  }
}
