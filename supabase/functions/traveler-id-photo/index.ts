/**
 * traveler-id-photo — the photo on a traveler's ID, for a sender about to
 * pay, so they can check the traveler looks real and matches the ticket.
 *
 * Only the face is shared, never the ID page: the passport number, date of
 * birth, signature and the rest of the document stay private. The crop is cut
 * from the ID image kept for face matching ({user_id}/id_face.jpg in the
 * private `identity-documents` bucket) using AWS Rekognition DetectFaces, and
 * kept next to it as {user_id}/id_photo.jpg so it is only made once.
 *
 * Called by the app (with the sender's JWT) with { request_id }. Allowed only
 * for the sender of that request, once the traveler accepted it (accepted,
 * paid, handed off or delivered), and only if the traveler is verified.
 *
 * Responds 200 with { url, idDocumentType, verifiedAt }: url is a link to the
 * crop valid for 5 minutes. Errors: 401 unauthorized, 403 not_allowed,
 * 404 not_verified / no_photo, 502 face_detection_unavailable.
 *
 * Secrets: the same AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY and AWS_REGION as
 * verify-identity. SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided by
 * Supabase.
 */

import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  DetectFacesCommand,
  RekognitionClient,
} from "npm:@aws-sdk/client-rekognition@3";
import { Image } from "https://deno.land/x/imagescript@1.3.0/mod.ts";

const BUCKET = "identity-documents";
const LINK_SECONDS = 300;

/** Room around the face, as a share of its size, so it looks like a photo. */
const PADDING = 0.35;

const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

const rekognition = new RekognitionClient({
  region: Deno.env.get("AWS_REGION") ?? "us-east-1",
  credentials: {
    accessKeyId: Deno.env.get("AWS_ACCESS_KEY_ID") ?? "",
    secretAccessKey: Deno.env.get("AWS_SECRET_ACCESS_KEY") ?? "",
  },
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

async function download(path: string): Promise<Uint8Array | null> {
  const { data, error } = await admin.storage.from(BUCKET).download(path);
  if (error || !data) return null;
  return new Uint8Array(await data.arrayBuffer());
}

async function signedUrl(path: string): Promise<string | null> {
  const { data } = await admin.storage
    .from(BUCKET)
    .createSignedUrl(path, LINK_SECONDS);
  return data?.signedUrl ?? null;
}

/**
 * The face on [idImage], with some room around it, as a JPEG. An ID often
 * shows the face twice (main photo and a small "ghost" image): the largest
 * face is the photo. Null if no face is found.
 */
async function cropFace(idImage: Uint8Array): Promise<Uint8Array | null> {
  const result = await rekognition.send(
    new DetectFacesCommand({ Image: { Bytes: idImage } }),
  );
  const faces = (result.FaceDetails ?? [])
    .map((f) => f.BoundingBox)
    .filter((b) => b?.Width && b?.Height);
  if (faces.length === 0) return null;
  const box = faces.reduce((a, b) =>
    a!.Width! * a!.Height! >= b!.Width! * b!.Height! ? a : b
  )!;

  const image = await Image.decode(idImage);
  const faceW = box.Width! * image.width;
  const faceH = box.Height! * image.height;
  const left = Math.max(0, Math.floor(box.Left! * image.width - faceW * PADDING));
  const top = Math.max(0, Math.floor(box.Top! * image.height - faceH * PADDING));
  const width = Math.min(image.width - left, Math.ceil(faceW * (1 + 2 * PADDING)));
  const height = Math.min(image.height - top, Math.ceil(faceH * (1 + 2 * PADDING)));
  if (width < 8 || height < 8) return null;

  return await image.crop(left, top, width, height).encodeJPEG(90);
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

  const { data: check } = await db
    .from("identity_verifications")
    .select("status, id_document_type, verified_at")
    .eq("user_id", travelerId)
    .maybeSingle();
  if (!check || check.status !== "verified") {
    return json({ error: "not_verified" }, 404);
  }
  const details = {
    idDocumentType: check.id_document_type ?? null,
    verifiedAt: check.verified_at ?? null,
  };

  // Made once, then reused.
  const photoPath = `${travelerId}/id_photo.jpg`;
  const existing = await signedUrl(photoPath);
  if (existing) return json({ url: existing, ...details });

  const idImage = await download(`${travelerId}/id_face.jpg`);
  if (!idImage) return json({ error: "no_photo" }, 404);

  let crop: Uint8Array | null;
  try {
    crop = await cropFace(idImage);
  } catch (e) {
    console.error("[traveler-id-photo] crop:", (e as Error).message);
    return json({ error: "face_detection_unavailable" }, 502);
  }
  if (!crop) return json({ error: "no_photo" }, 404);

  const { error: uploadError } = await admin.storage
    .from(BUCKET)
    .upload(photoPath, crop, { contentType: "image/jpeg", upsert: true });
  if (uploadError) {
    console.error("[traveler-id-photo] save:", uploadError.message);
    return json({ error: "server_error" }, 500);
  }

  const url = await signedUrl(photoPath);
  if (!url) return json({ error: "server_error" }, 500);
  return json({ url, ...details });
});
