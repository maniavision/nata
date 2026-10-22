/**
 * payout-options — where a traveler in [country] can be paid: the banks
 * Flutterwave transfers to there (its own list) and the mobile money it pays
 * out to, with the country's currency.
 *
 * Called by the app (with the traveler's JWT) with { country } (ISO code).
 * Responds 200 with { currency, banks: [{ code, name }], mobile_money:
 * [{ code, name }] }; both lists are empty where Flutterwave can't pay out.
 * Errors: 401 unauthorized, 503 payments_unavailable.
 */

// ── Flutterwave and Supabase helpers (the same in each payment function, so
// each can be deployed on its own, also from the dashboard) ──────────────

import { createClient } from "jsr:@supabase/supabase-js@2";

const FLW_API = "https://api.flutterwave.com/v3";

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

function secretKey(): string | null {
  const key = Deno.env.get("FLW_SECRET_KEY")?.trim();
  return key ? key : null;
}

/** The signed-in user calling the function, from their JWT. */
async function caller(req: Request) {
  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) return null;
  const { data: { user } } = await admin.auth.getUser(token);
  return user ?? null;
}

async function flutterwave(
  path: string,
  init: { method?: string; body?: unknown } = {},
): Promise<{ ok: boolean; status: number; body: Record<string, unknown> }> {
  const res = await fetch(`${FLW_API}${path}`, {
    method: init.method ?? "GET",
    headers: {
      Authorization: `Bearer ${secretKey()}`,
      "Content-Type": "application/json",
    },
    body: init.body === undefined ? undefined : JSON.stringify(init.body),
  });
  let body: Record<string, unknown> = {};
  try {
    body = await res.json();
  } catch (_) {
    // Not JSON: keep the empty body.
  }
  return { ok: res.ok && body.status === "success", status: res.status, body };
}

/**
 * The mobile money Flutterwave pays out to, by country, with its bank code.
 * Check these against Flutterwave's transfer docs in test mode before going
 * live; banks come from Flutterwave's own list instead.
 *
 * In the CFA franc countries (XOF / XAF) Flutterwave pays out with one code
 * (FMM) to the operators of that country, so each country lists its own.
 */
function fmm(...names: string[]): { code: string; name: string }[] {
  return names.map((name) => ({ code: "FMM", name }));
}
const MOBILE_MONEY: Record<string, { code: string; name: string }[]> = {
  KE: [{ code: "MPS", name: "M-Pesa" }],
  GH: [
    { code: "MTN", name: "MTN Mobile Money" },
    { code: "VDF", name: "Vodafone Cash" },
    { code: "ATL", name: "AirtelTigo Money" },
  ],
  UG: [
    { code: "MPS", name: "MTN Mobile Money" },
    { code: "MPS", name: "Airtel Money" },
  ],
  TZ: [{ code: "MPS", name: "M-Pesa" }, { code: "MPS", name: "Airtel Money" }],
  RW: [{ code: "MPS", name: "MTN Mobile Money" }, { code: "MPS", name: "Airtel Money" }],
  ZM: [{ code: "MPS", name: "MTN Mobile Money" }, { code: "MPS", name: "Airtel Money" }],
  // CFA franc countries (XOF / XAF).
  SN: fmm("Orange Money", "Free Money"),
  CI: fmm("Orange Money", "MTN Mobile Money", "Moov Money"),
  BF: fmm("Orange Money", "Moov Money"),
  ML: fmm("Orange Money", "Moov Money"),
  BJ: fmm("MTN Mobile Money", "Moov Money"),
  TG: fmm("Moov Money", "T-Money"),
  NE: fmm("Airtel Money", "Moov Money"),
  CM: fmm("MTN Mobile Money", "Orange Money"),
  GA: fmm("Airtel Money", "Moov Money"),
  CG: fmm("MTN Mobile Money", "Airtel Money"),
  TD: fmm("Airtel Money", "Moov Money"),
  CF: fmm("Orange Money", "Telecel Money"),
};

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

// ── This function ──────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  if (!secretKey()) return json({ error: "payments_unavailable" }, 503);
  if (!(await caller(req))) return json({ error: "unauthorized" }, 401);

  let country = "";
  try {
    country = String((await req.json()).country ?? "").trim().toUpperCase();
  } catch (_) {
    return json({ error: "bad_request" }, 400);
  }
  if (!/^[A-Z]{2}$/.test(country)) return json({ error: "bad_request" }, 400);

  const currency = await countryCurrency(country);
  const res = await flutterwave(`/banks/${country}`);
  const banks = res.ok && Array.isArray(res.body.data)
    ? (res.body.data as { code?: unknown; name?: unknown }[])
      .map((b) => ({ code: String(b.code ?? ""), name: String(b.name ?? "").trim() }))
      .filter((b) => b.code && b.name)
      .sort((a, b) => a.name.localeCompare(b.name))
    : [];

  return json({
    currency,
    banks,
    mobile_money: currency ? (MOBILE_MONEY[country] ?? []) : [],
  });
});
