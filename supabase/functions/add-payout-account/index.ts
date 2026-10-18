/**
 * add-payout-account — saves where a traveler is paid.
 *
 * Called by the app (with the traveler's JWT) with { kind: bank |
 * mobile_money, country, bank_code, institution_name, account_number,
 * holder_name }. The bank code must be one Flutterwave pays out to in that
 * country (see payout-options). The full number goes to
 * nata.payout_destinations, which only the server reads; the app keeps the
 * last 4 digits (nata.payout_accounts). A first account becomes the default.
 *
 * Responds 200 with the account { id, kind, institution_name, country_code,
 * account_last4, holder_name, is_default }. Errors: 401 unauthorized,
 * 400 invalid, 409 not_supported, 503 payments_unavailable.
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
 */
const FRANCO = [
  { code: "FMM", name: "Orange Money" },
  { code: "FMM", name: "MTN Mobile Money" },
  { code: "FMM", name: "Moov Money" },
];
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
  SN: FRANCO, CI: FRANCO, BF: FRANCO, ML: FRANCO, BJ: FRANCO, TG: FRANCO,
  NE: FRANCO, CM: FRANCO, GA: FRANCO, CG: FRANCO, TD: FRANCO, CF: FRANCO,
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
  const user = await caller(req);
  if (!user) return json({ error: "unauthorized" }, 401);

  let b: Record<string, unknown> = {};
  try {
    b = await req.json();
  } catch (_) {
    return json({ error: "bad_request" }, 400);
  }
  const kind = String(b.kind ?? "");
  const country = String(b.country ?? "").trim().toUpperCase();
  const bankCode = String(b.bank_code ?? "").trim();
  const institution = String(b.institution_name ?? "").trim();
  const holder = String(b.holder_name ?? "").trim().replace(/\s+/g, " ");
  // Digits only (a mobile number with its country code, no +).
  const number = String(b.account_number ?? "").replace(/[\s+-]/g, "")
    .toUpperCase();

  if (
    !["bank", "mobile_money"].includes(kind) || !/^[A-Z]{2}$/.test(country) ||
    !bankCode || institution.length < 2 || institution.length > 80 ||
    holder.length < 2 || holder.length > 80 ||
    (kind === "bank" && !/^[0-9A-Z]{6,34}$/.test(number)) ||
    (kind === "mobile_money" && !/^[0-9]{8,15}$/.test(number))
  ) {
    return json({ error: "invalid" }, 400);
  }

  const currency = await countryCurrency(country);
  if (!currency) return json({ error: "not_supported" }, 409);

  // Only codes Flutterwave pays out to there.
  if (kind === "mobile_money") {
    if (!(MOBILE_MONEY[country] ?? []).some((m) => m.code === bankCode)) {
      return json({ error: "not_supported" }, 409);
    }
  } else {
    const res = await flutterwave(`/banks/${country}`);
    const known = res.ok && Array.isArray(res.body.data) &&
      (res.body.data as { code?: unknown }[]).some((x) => String(x.code) === bankCode);
    if (!known) return json({ error: "not_supported" }, 409);
  }

  const db = admin.schema("nata");
  const { data: account, error } = await db
    .from("payout_accounts")
    .insert({
      user_id: user.id,
      kind,
      institution_name: institution,
      country_code: country,
      account_last4: number.slice(-4),
      holder_name: holder,
    })
    .select("id, kind, institution_name, country_code, account_last4, holder_name, is_default")
    .single();
  if (error || !account) {
    console.error("[add-payout-account] account", error);
    return json({ error: "invalid" }, 400);
  }

  const { error: destError } = await db.from("payout_destinations").insert({
    account_id: account.id,
    account_bank: bankCode,
    account_number: number,
    currency,
  });
  if (destError) {
    console.error("[add-payout-account] destination", destError);
    await db.from("payout_accounts").delete().eq("id", account.id);
    return json({ error: "invalid" }, 400);
  }

  return json(account);
});
