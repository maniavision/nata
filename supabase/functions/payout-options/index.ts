/**
 * payout-options — where a traveler in [country] can be paid: the mobile
 * money networks pawaPay pays out to there (nata.mobile_money_networks), with
 * the country's currency. Bank payouts aren't offered yet (20240169: they
 * will go through Stripe), so the bank list is empty.
 *
 * Called by the app (with the traveler's JWT) with { country } (ISO code).
 * Responds 200 with { currency, banks: [], mobile_money: [{ code, name }] };
 * mobile_money is empty where pawaPay can't pay out. Errors:
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
    banks: [],
    mobile_money: currency ? await networks(country) : [],
  });
});
