/**
 * send-push — pushes notifications to the user's phones with Firebase Cloud
 * Messaging (HTTP v1).
 *
 * Called by the database (nata.request_push, 20240155) with { ids } and the
 * x-job-secret header (PAYMENT_JOBS_SECRET). For each notification not yet
 * pushed, it writes the title and body in the user's language
 * (nata.user_settings.language; texts.ts, generated from the app's .arb
 * files), sends it to every registered device, removes tokens Firebase says
 * are gone, and stamps pushed_at. The push carries the notification's id,
 * event and related request so the app opens the right page on tap.
 *
 * Secret: FCM_SERVICE_ACCOUNT, the Firebase service account JSON
 * (scripts/setup_push.sh). Without it: 503 push_unavailable.
 *
 * Responds 200 with { pushed, devices, removed }.
 */

import { createClient } from "jsr:@supabase/supabase-js@2";
import { TEXTS } from "./texts.ts";

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

type ServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
};

function serviceAccount(): ServiceAccount | null {
  try {
    const sa = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT") ?? "");
    return sa.project_id && sa.client_email && sa.private_key ? sa : null;
  } catch (_) {
    return null;
  }
}

// ── Google OAuth token for FCM (a JWT signed with the service account) ──────

function b64url(data: Uint8Array | string): string {
  const bytes = typeof data === "string" ? new TextEncoder().encode(data) : data;
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

let cached: { token: string; expires: number } | null = null;

async function accessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cached && cached.expires > now + 60) return cached.token;

  const pem = sa.private_key
    .replace(/-----[^-]+-----/g, "")
    .replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const unsigned = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" })) +
    "." +
    b64url(JSON.stringify({
      iss: sa.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    }));
  const signature = new Uint8Array(
    await crypto.subtle.sign(
      "RSASSA-PKCS1-v1_5",
      key,
      new TextEncoder().encode(unsigned),
    ),
  );
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${unsigned}.${b64url(signature)}`,
    }),
  });
  const body = await res.json();
  if (!res.ok || !body.access_token) {
    throw new Error(`oauth ${res.status} ${JSON.stringify(body)}`);
  }
  cached = { token: body.access_token, expires: now + (body.expires_in ?? 3600) };
  return cached.token;
}

// ── Text in the user's language ─────────────────────────────────────────────

/** Whose name {name} is, per event (as notification_text.dart passes it). */
const NAME_FROM: Record<string, "sender" | "traveler"> = {
  request_new: "sender",
  request_accepted: "traveler",
  request_declined: "traveler",
  request_expired_unanswered: "traveler",
  request_expired_unpaid_traveler: "sender",
  request_cancelled_by_traveler: "traveler",
  request_cancelled_by_sender: "sender",
  request_paid: "sender",
  item_picked_up: "traveler",
  item_delivered: "traveler",
};

const SYMBOLS: Record<string, string> = { USD: "$", EUR: "€", GBP: "£" };

/** "$28" or "XOF 16,400", as PriceFormatter.write. */
function money(amount: number, currency: string): string {
  const text = Math.round(amount).toLocaleString("en-US");
  const c = currency.toUpperCase();
  return SYMBOLS[c] ? `${SYMBOLS[c]}${text}` : `${c} ${text}`;
}

function textFor(
  lang: string,
  event: string,
  payload: Record<string, unknown>,
  stored: { title: string; body: string },
): { title: string; body: string } {
  const pair = (TEXTS[lang] ?? TEXTS.en)[event];
  if (!pair) return stored;
  const s = (k: string) => String(payload[k] ?? "").trim();
  const values: Record<string, string> = {
    sender: s("sender"),
    traveler: s("traveler"),
    route: s("route"),
    name: NAME_FROM[event] ? s(NAME_FROM[event]) : "",
    amount: money(Number(payload.amount ?? 0), s("currency")),
  };
  const fill = (t: string) => t.replace(/\{(\w+)\}/g, (_, k) => values[k] ?? "");
  return { title: fill(pair[0]), body: fill(pair[1]) };
}

// ── This function ───────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  const secret = Deno.env.get("PAYMENT_JOBS_SECRET")?.trim();
  if (!secret || req.headers.get("x-job-secret") !== secret) {
    return json({ error: "unauthorized" }, 401);
  }
  const sa = serviceAccount();
  if (!sa) return json({ error: "push_unavailable" }, 503);

  let ids: string[] = [];
  try {
    const body = await req.json();
    ids = (Array.isArray(body.ids) ? body.ids : []).map(String).slice(0, 200);
  } catch (_) {
    return json({ error: "bad_request" }, 400);
  }
  if (ids.length === 0) return json({ pushed: 0, devices: 0, removed: 0 });

  const db = admin.schema("nata");
  const { data: notes, error } = await db
    .from("notifications")
    .select("id, user_id, type, title, body, related_id, payload")
    .in("id", ids)
    .is("pushed_at", null);
  if (error) {
    console.error("[send-push] notifications", error);
    return json({ error: "db_error" }, 500);
  }
  if (!notes?.length) return json({ pushed: 0, devices: 0, removed: 0 });

  const users = [...new Set(notes.map((n) => n.user_id as string))];
  const [{ data: tokens }, { data: settings }] = await Promise.all([
    db.from("push_tokens").select("token, user_id").in("user_id", users),
    db.from("user_settings").select("user_id, language").in("user_id", users),
  ]);
  const langOf = new Map(
    (settings ?? []).map((s) => [s.user_id as string, String(s.language ?? "en")]),
  );

  const fcm = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;
  const auth = `Bearer ${await accessToken(sa)}`;
  let devices = 0;
  const dead: string[] = [];
  const pushed: string[] = [];

  for (const n of notes) {
    const payload = (n.payload ?? {}) as Record<string, unknown>;
    const event = String(payload.event ?? "");
    const { title, body } = textFor(
      langOf.get(n.user_id) ?? "en",
      event,
      payload,
      { title: String(n.title ?? ""), body: String(n.body ?? "") },
    );
    const mine = (tokens ?? []).filter((t) => t.user_id === n.user_id);
    for (const t of mine) {
      const res = await fetch(fcm, {
        method: "POST",
        headers: { Authorization: auth, "Content-Type": "application/json" },
        body: JSON.stringify({
          message: {
            token: t.token,
            notification: { title, body },
            data: {
              notification_id: String(n.id),
              event,
              type: String(n.type ?? ""),
              related_id: String(n.related_id ?? ""),
            },
            android: { priority: "high", notification: { sound: "default" } },
            apns: { payload: { aps: { sound: "default" } } },
          },
        }),
      });
      if (res.ok) {
        devices++;
      } else {
        const text = await res.text();
        if (res.status === 404 || /UNREGISTERED|INVALID_ARGUMENT/.test(text)) {
          dead.push(t.token);
        } else {
          console.error("[send-push] fcm", res.status, text);
        }
      }
    }
    pushed.push(n.id as string);
  }

  if (dead.length) await db.from("push_tokens").delete().in("token", dead);
  await db
    .from("notifications")
    .update({ pushed_at: new Date().toISOString() })
    .in("id", pushed);

  return json({ pushed: pushed.length, devices, removed: dead.length });
});
