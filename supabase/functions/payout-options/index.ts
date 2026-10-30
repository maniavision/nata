/**
 * payout-options — where a traveler in [country] can be paid: the mobile
 * money networks pawaPay pays out to there (nata.mobile_money_networks), with
 * the country's currency, and their bank through Stripe where Stripe Connect
 * can pay out (20240170: the US, the UK, the EEA, Canada and Switzerland).
 * In Nigeria, only a bank, paid by Flutterwave (20240198).
 *
 * Called by the app (with the traveler's JWT) with { country } (ISO code).
 * Responds 200 with { currency, banks, mobile_money: [{ code, name }] };
 * banks is [{ code: STRIPE, name }] where Stripe can pay out (the bank is
 * then connected through stripe-connect), Flutterwave's Nigerian banks in
 * Nigeria (the bank code and account number are then saved with
 * add-payout-account), else empty. Errors:
 * 401 unauthorized.
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

/** The signed-in user calling the function, from their JWT. */
async function caller(req: Request) {
  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) return null;
  const { data: { user } } = await admin.auth.getUser(token);
  return user ?? null;
}

function flutterwaveKey(): string | null {
  const key = Deno.env.get("FLW_SECRET_KEY")?.trim();
  return key ? key : null;
}

/** Calls Flutterwave; [ok] when it answered with success. */
async function flutterwave(
  path: string,
  init: { method?: string; body?: unknown } = {},
): Promise<{ ok: boolean; status: number; body: Record<string, unknown> }> {
  let res: Response;
  try {
    res = await fetch(`https://api.flutterwave.com/v3${path}`, {
      method: init.method ?? "GET",
      headers: {
        Authorization: `Bearer ${flutterwaveKey()}`,
        "Content-Type": "application/json",
      },
      body: init.body === undefined ? undefined : JSON.stringify(init.body),
    });
  } catch (_) {
    return { ok: false, status: 0, body: {} };
  }
  let body: Record<string, unknown> = {};
  try {
    body = await res.json();
  } catch (_) {
    // Not JSON: keep the empty body.
  }
  return { ok: res.ok && body.status === "success", status: res.status, body };
}

/** The Nigerian banks Flutterwave pays out to, by name (empty if it can't
 * be reached). */
async function nigerianBanks(): Promise<{ code: string; name: string }[]> {
  if (!flutterwaveKey()) return [];
  const res = await flutterwave("/banks/NG");
  return res.ok && Array.isArray(res.body.data)
    ? (res.body.data as { code?: unknown; name?: unknown }[])
      .map((b) => ({ code: String(b.code ?? ""), name: String(b.name ?? "").trim() }))
      .filter((b) => b.code && b.name)
      .sort((a, b) => a.name.localeCompare(b.name))
    : [];
}

/** The currency of [country] (nata.countries), or null. */
async function countryCurrency(country: string): Promise<string | null> {
  const { data } = await admin
    .schema("nata")
    .from("countries")
    .select("currency_code")
    .eq("iso_code", country)
    .maybeSingle();
  const c = String(data?.currency_code ?? "").trim().toUpperCase();
  return /^[A-Z]{3}$/.test(c) ? c : null;
}

/** The mobile money networks pawaPay pays out to in [country]. */
async function networks(country: string): Promise<{ code: string; name: string }[]> {
  const { data } = await admin
    .schema("nata")
    .from("mobile_money_networks")
    .select("provider, name")
    .eq("country_code", country)
    .order("position");
  return ((data ?? []) as { provider: string; name: string }[])
    .map((n) => ({ code: n.provider, name: n.name }));
}

/** Where Stripe Connect can pay out to a bank from Nata's US account:
 * the US, the UK, the EEA, Canada and Switzerland (cross-border payouts). */
const STRIPE_COUNTRIES = new Set([
  "US", "GB", "CA", "CH",
  // The EEA.
  "AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR", "DE", "GR",
  "HU", "IS", "IE", "IT", "LV", "LI", "LT", "LU", "MT", "NL", "NO", "PL",
  "PT", "RO", "SK", "SI", "ES", "SE",
]);

// ── This function ──────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  if (!(await caller(req))) return json({ error: "unauthorized" }, 401);

  let country = "";
  try {
    country = String((await req.json()).country ?? "").trim().toUpperCase();
  } catch (_) {
    return json({ error: "bad_request" }, 400);
  }
  if (!/^[A-Z]{2}$/.test(country)) return json({ error: "bad_request" }, 400);

  const currency = await countryCurrency(country);
  if (country === "NG") {
    return json({ currency, banks: await nigerianBanks(), mobile_money: [] });
  }
  return json({
    currency,
    banks: STRIPE_COUNTRIES.has(country)
      ? [{ code: "STRIPE", name: "Bank account (Stripe)" }]
      : [],
    mobile_money: currency ? await networks(country) : [],
  });
});
