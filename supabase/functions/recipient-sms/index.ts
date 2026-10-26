/**
 * recipient-sms — texts the recipient (who isn't on Nata) as their parcel
 * moves, with the link to their page (20240181_recipient_link.sql).
 *
 * Called by the database (pg_net) with the payment-jobs secret in the
 * x-job-secret header (PAYMENT_JOBS_SECRET) and { request_id, event }:
 *   picked_up  the traveler has the parcel (status handed_off)
 *   arriving   the traveler lands today (daily job)
 *   delivered  delivered, with the invitation to get Nata
 *   message    the traveler wrote and the recipient isn't on the page
 * Each update is sent once; "message" at most every 30 minutes. Written in
 * the sender's language.
 *
 * Responds 200 with { sent } (false when skipped). Errors: 401, 400,
 * 503 sms_unavailable, 502 sms_failed.
 */

import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  appLink,
  pageLink,
  sendSms,
  type SmsEvent,
  smsText,
} from "../_shared/recipient_sms.ts";

const EVENTS: SmsEvent[] = ["picked_up", "arriving", "delivered", "message"];
const MESSAGE_EVERY_MS = 30 * 60 * 1000;

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
  const secret = Deno.env.get("PAYMENT_JOBS_SECRET")?.trim();
  if (!secret || req.headers.get("x-job-secret") !== secret) {
    return json({ error: "unauthorized" }, 401);
  }

  let requestId = "";
  let event = "" as SmsEvent;
  try {
    const body = await req.json();
    requestId = String(body.request_id ?? "");
    event = String(body.event ?? "") as SmsEvent;
  } catch (_) {
    return json({ error: "bad_request" }, 400);
  }
  if (!requestId || !EVENTS.includes(event)) {
    return json({ error: "bad_request" }, 400);
  }

  const db = admin.schema("nata");
  const { data: already } = await db
    .from("recipient_sms")
    .select("sent_at")
    .eq("request_id", requestId)
    .eq("event", event)
    .maybeSingle();
  if (already) {
    const recent = Date.now() - new Date(already.sent_at).getTime() <
      MESSAGE_EVERY_MS;
    if (event !== "message" || recent) return json({ sent: false });
  }

  const { data: request } = await db
    .from("delivery_requests")
    .select("sender_id, status, trip_id")
    .eq("id", requestId)
    .maybeSingle();
  if (!request) return json({ sent: false });

  const [{ data: trip }, { data: recipient }, { data: sender }, { data: lang }] =
    await Promise.all([
      db.from("trips")
        .select("traveler_id, arrival_city_id")
        .eq("id", request.trip_id)
        .maybeSingle(),
      db.from("request_recipients")
        .select("phone")
        .eq("request_id", requestId)
        .maybeSingle(),
      db.from("profiles")
        .select("first_name")
        .eq("id", request.sender_id)
        .maybeSingle(),
      db.from("user_settings")
        .select("language")
        .eq("user_id", request.sender_id)
        .maybeSingle(),
    ]);
  const phone = String(recipient?.phone ?? "").trim();
  if (!phone || !trip) return json({ sent: false });

  const [{ data: traveler }, { data: city }, { data: token }] = await Promise.all([
    db.from("profiles")
      .select("first_name")
      .eq("id", trip.traveler_id)
      .maybeSingle(),
    db.from("cities")
      .select("name")
      .eq("id", trip.arrival_city_id)
      .maybeSingle(),
    db.rpc("recipient_token", { p_request_id: requestId }),
  ]);

  const text = smsText(lang?.language, event, {
    sender: String(sender?.first_name ?? "").trim() || "Someone",
    traveler: String(traveler?.first_name ?? "").trim() || "The traveler",
    city: String(city?.name ?? "").trim(),
    link: pageLink(String(token ?? "")),
    app: appLink,
  });
  const result = await sendSms(phone, text);
  if (result === "unavailable") return json({ error: "sms_unavailable" }, 503);
  if (result === "failed") return json({ error: "sms_failed" }, 502);

  await db.from("recipient_sms").upsert({
    request_id: requestId,
    event,
    sent_at: new Date().toISOString(),
  });
  return json({ sent: true });
});
