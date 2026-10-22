/**
 * traveler-id-photo — the photo on a traveler's ID, for a sender about to
 * pay, so they can check the traveler looks real and matches the ticket.
 *
 * Gives a short-lived link to the ID image the traveler uploaded for
 * verification ({user_id}/id_face.jpg in the private `identity-documents`
 * bucket): the face area of the ID cut out on the phone, or the whole ID
 * photo when the phone could not find the face.
 *
 * Called by the app (with the sender's JWT) with { request_id }. Allowed only
 * for the sender of that request, once the traveler accepted it (accepted,
 * paid, handed off or delivered), and only if the traveler is verified
 * (profiles.verification_status, as everywhere else: a traveler verified by
 * the team has no automatic check behind it).
 *
 * Responds 200 with { url, idDocumentType, verifiedAt }: url is valid for
 * 5 minutes, or null when there is no ID image on file; the sender can still
 * confirm with the ID details. Errors: 401 unauthorized, 403 not_allowed,
 * 404 not_verified.
 *
 * SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided by Supabase.
 */

import { createClient } from "jsr:@supabase/supabase-js@2";

const BUCKET = "identity-documents";
const LINK_SECONDS = 300;

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

async function signedUrl(path: string): Promise<string | null> {
  const { data } = await admin.storage
    .from(BUCKET)
    .createSignedUrl(path, LINK_SECONDS);
  return data?.signedUrl ?? null;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) return json({ error: "unauthorized" }, 401);
  const { data: { user } } = await admin.auth.getUser(token);
  if (!user) return json({ error: "unauthorized" }, 401);

  let requestId = "";
  try {
    requestId = String((await req.json()).request_id ?? "");
  } catch (_) {
    return json({ error: "bad_request" }, 400);
  }
  if (!requestId) return json({ error: "bad_request" }, 400);

  const db = admin.schema("nata");

  // The caller must be the sender, and the traveler must have accepted.
  const { data: request } = await db
    .from("delivery_requests")
    .select("sender_id, status, trips!inner(traveler_id)")
    .eq("id", requestId)
    .maybeSingle();
  const travelerId = (request as { trips?: { traveler_id?: string } } | null)
    ?.trips?.traveler_id;
  if (
    !request || request.sender_id !== user.id || !travelerId ||
    !["accepted", "paid", "handed_off", "delivered"].includes(request.status)
  ) {
    return json({ error: "not_allowed" }, 403);
  }

  const { data: profile } = await db
    .from("profiles")
    .select("verification_status")
    .eq("id", travelerId)
    .maybeSingle();
  if (profile?.verification_status !== "verified") {
    return json({ error: "not_verified" }, 404);
  }
  const { data: check } = await db
    .from("identity_verifications")
    .select("id_document_type, verified_at")
    .eq("user_id", travelerId)
    .maybeSingle();
  const details = {
    idDocumentType: check?.id_document_type ?? null,
    verifiedAt: check?.verified_at ?? null,
  };
  // The ID image the traveler uploaded (the phone keeps the face area of the
  // ID, or the whole ID photo when it could not find the face).
  const url = await signedUrl(`${travelerId}/id_face.jpg`);
  return json({ url, ...details });
});
