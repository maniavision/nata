/**
 * verify-identity — compares the user's live selfie with their ID photo.
 *
 * Called by the app (with the user's JWT) after the liveness check, once it
 * has uploaded both images to the private `identity-documents` bucket:
 *   {user_id}/id_face.jpg  the ID page showing the face
 *   {user_id}/selfie.jpg   the selfie taken after the liveness check
 *
 * Runs AWS Rekognition CompareFaces. On a match it marks the verification
 * and the profile 'verified' (only this function can: see
 * supabase/migrations/20240122_face_verification.sql). Each call counts as an
 * attempt; after FACE_MATCH_MAX_ATTEMPTS the verification stays 'pending' for
 * a person to review.
 *
 * Responds 200 with { verdict, similarity, attemptsLeft }, verdict being
 * "match" | "no_match" | "no_face" | "manual_review".
 *
 * Secrets (supabase secrets set ...): AWS_ACCESS_KEY_ID,
 * AWS_SECRET_ACCESS_KEY, AWS_REGION; optional FACE_MATCH_THRESHOLD (default
 * 90) and FACE_MATCH_MAX_ATTEMPTS (default 3). SUPABASE_URL and
 * SUPABASE_SERVICE_ROLE_KEY are provided by Supabase.
 */

import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  CompareFacesCommand,
  RekognitionClient,
} from "npm:@aws-sdk/client-rekognition@3";

const BUCKET = "identity-documents";
const THRESHOLD = Number(Deno.env.get("FACE_MATCH_THRESHOLD") ?? "90");
const MAX_ATTEMPTS = Number(Deno.env.get("FACE_MATCH_MAX_ATTEMPTS") ?? "3");

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

type Verdict = "match" | "no_match" | "no_face" | "manual_review";

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

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }

  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) return json({ error: "unauthorized" }, 401);
  const { data: { user } } = await admin.auth.getUser(token);
  if (!user) return json({ error: "unauthorized" }, 401);

  const db = admin.schema("nata");
  const { data: row, error: rowError } = await db
    .from("identity_verifications")
    .select("id, status, face_match_attempts")
    .eq("user_id", user.id)
    .maybeSingle();
  if (rowError) {
    console.error("[verify-identity] load:", rowError.message);
    return json({ error: "server_error" }, 500);
  }
  if (!row) return json({ error: "no_verification" }, 400);
  if (row.status === "verified") {
    return json({ verdict: "match", similarity: null, attemptsLeft: 0 });
  }

  const attempts: number = row.face_match_attempts ?? 0;
  if (attempts >= MAX_ATTEMPTS) {
    return json({ verdict: "manual_review", similarity: null, attemptsLeft: 0 });
  }

  const [selfie, idFace] = await Promise.all([
    download(`${user.id}/selfie.jpg`),
    download(`${user.id}/id_face.jpg`),
  ]);
  if (!selfie || !idFace) return json({ error: "missing_images" }, 400);

  // Count the attempt before calling AWS, so failures can't be retried for
  // free.
  await db
    .from("identity_verifications")
    .update({ face_match_attempts: attempts + 1 })
    .eq("id", row.id);
  const attemptsLeft = MAX_ATTEMPTS - attempts - 1;

  let similarity = 0;
  let noFace = false;
  try {
    // Source: the selfie (one face). Target: the ID image, which may show
    // the face twice (main photo and a small ghost image); the best match
    // counts. Threshold 0 so the similarity comes back even below a match.
    const result = await rekognition.send(
      new CompareFacesCommand({
        SourceImage: { Bytes: selfie },
        TargetImage: { Bytes: idFace },
        SimilarityThreshold: 0,
      }),
    );
    similarity = Math.max(
      0,
      ...(result.FaceMatches ?? []).map((m) => m.Similarity ?? 0),
    );
  } catch (e) {
    // Rekognition rejects images it finds no face in.
    if ((e as Error).name === "InvalidParameterException") {
      noFace = true;
    } else {
      console.error("[verify-identity] Rekognition:", (e as Error).message);
      return json({ error: "face_match_unavailable" }, 502);
    }
  }
  similarity = Math.round(similarity * 100) / 100;

  if (!noFace && similarity >= THRESHOLD) {
    const now = new Date().toISOString();
    await db
      .from("identity_verifications")
      .update({ status: "verified", face_similarity: similarity, verified_at: now })
      .eq("id", row.id);
    await db
      .from("profiles")
      .update({ verification_status: "verified" })
      .eq("id", user.id);
    console.log(`[verify-identity] ${user.id} verified (${similarity}%)`);
    return json({ verdict: "match", similarity, attemptsLeft });
  }

  await db
    .from("identity_verifications")
    .update({ face_similarity: noFace ? null : similarity })
    .eq("id", row.id);
  const verdict: Verdict = attemptsLeft <= 0
    ? "manual_review"
    : noFace
    ? "no_face"
    : "no_match";
  console.log(
    `[verify-identity] ${user.id} ${verdict} (${similarity}%, ${attemptsLeft} left)`,
  );
  return json({ verdict, similarity: noFace ? null : similarity, attemptsLeft });
});
