/**
 * payout-options — where a traveler in [country] can be paid: the mobile
 * money networks pawaPay pays out to there (nata.mobile_money_networks), with
 * the country's currency, and their bank through Stripe where Stripe Connect
 * can pay out (20240170: the US, the UK, the EEA, Canada and Switzerland).
 *
 * Called by the app (with the traveler's JWT) with { country } (ISO code).
 * Responds 200 with { currency, banks, mobile_money: [{ code, name }] };
 * banks is [{ code: STRIPE, name }] where Stripe can pay out (the bank is
 * then connected through stripe-connect), else empty. Errors:
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
  return json({
    currency,
    banks: STRIPE_COUNTRIES.has(country)
      ? [{ code: "STRIPE", name: "Bank account (Stripe)" }]
      : [],
    mobile_money: currency ? await networks(country) : [],
  });
});
