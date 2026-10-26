/**
 * send-delivery-code — texts the delivery code to the recipient, so they can
 * give it to the traveler at handover.
 *
 * Called by the app (with the sender's JWT) with { request_id }, right after
 * the payment goes through and from "Send code by SMS" on the request card.
 * Allowed only for the request's sender while it is paid or picked up, and
 * at most once every 2 minutes.
 *
 * Responds 200 with { sent_at }. Errors: 401 unauthorized, 403 not_allowed,
 * 404 no_code, 429 too_soon, 503 sms_unavailable (SMS not set up),
 * 502 sms_failed.
 *
 * Sent as free text: Bird's built-in templates don't fit this message, and
 * both free text and workspace templates need a sender of our own anyway.
 * It carries the link to the recipient's page (20240181_recipient_link.sql),
 * in the sender's language.
 *
 * Secrets: BIRD_API_KEY (as for the sign-in SMS), BIRD_SENDER, a sender
 * held by the Bird workspace (SMS > Senders) such as the sender ID "Nata",
 * and BIRD_SENDER_US, an owned number in E.164 used for +1 recipients, since
 * the US and Canada don't accept alphanumeric senders. SUPABASE_URL and
 * SUPABASE_SERVICE_ROLE_KEY are provided by Supabase.
 */

import { createClient } from "jsr:@supabase/supabase-js@2";
import { pageLink, sendSms, smsText } from "../_shared/recipient_sms.ts";

const RESEND_AFTER_MS = 2 * 60 * 1000;

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
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  if (!Deno.env.get("BIRD_API_KEY")?.trim() || !Deno.env.get("BIRD_SENDER")?.trim()) {
    return json({ error: "sms_unavailable" }, 503);
  }

  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  const { data: { user } } = token
    ? await admin.auth.getUser(token)
    : { data: { user: null } };
  if (!user) return json({ error: "unauthorized" }, 401);

  let requestId = "";
  try {
    requestId = String((await req.json()).request_id ?? "");
  } catch (_) {
    return json({ error: "bad_request" }, 400);
  }
  if (!requestId) return json({ error: "bad_request" }, 400);

  const db = admin.schema("nata");
  const { data: request } = await db
    .from("delivery_requests")
    .select("sender_id, status")
    .eq("id", requestId)
    .maybeSingle();
  if (
    !request || request.sender_id !== user.id ||
    !["paid", "handed_off"].includes(request.status)
  ) {
    return json({ error: "not_allowed" }, 403);
  }

  const { data: code } = await db
    .from("delivery_codes")
    .select("code, sms_sent_at")
    .eq("request_id", requestId)
    .maybeSingle();
  if (!code) return json({ error: "no_code" }, 404);
  if (
    code.sms_sent_at &&
    Date.now() - new Date(code.sms_sent_at).getTime() < RESEND_AFTER_MS
  ) {
    return json({ error: "too_soon" }, 429);
  }

  const { data: recipient } = await db
    .from("request_recipients")
    .select("phone")
    .eq("request_id", requestId)
    .maybeSingle();
  const phone = String(recipient?.phone ?? "").trim();
  if (!phone) return json({ error: "not_allowed" }, 403);

  const [{ data: sender }, { data: lang }, { data: linkToken }] = await Promise.all([
    db.from("profiles").select("first_name").eq("id", user.id).maybeSingle(),
    db.from("user_settings").select("language").eq("user_id", user.id)
      .maybeSingle(),
    db.rpc("recipient_token", { p_request_id: requestId }),
  ]);

  const text = smsText(lang?.language, "code", {
    sender: String(sender?.first_name ?? "").trim() || "Someone",
    link: pageLink(String(linkToken ?? "")),
    code: String(code.code),
  });
  const result = await sendSms(phone, text);
  if (result === "unavailable") return json({ error: "sms_unavailable" }, 503);
  if (result === "failed") return json({ error: "sms_failed" }, 502);

  await db.rpc("mark_code_sent", { p_request_id: requestId });
  return json({ sent_at: new Date().toISOString() });
});
