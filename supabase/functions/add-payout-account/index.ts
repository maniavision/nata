/**
 * add-payout-account — saves where a traveler is paid: their mobile money,
 * paid out by pawaPay (20240169), or for a traveler living in Nigeria their
 * Nigerian bank account, paid by Flutterwave transfers (20240198).
 *
 * Called by the app (with the traveler's JWT) with { kind: mobile_money,
 * country, bank_code, institution_name, account_number, holder_name }. The
 * bank code is pawaPay's provider code of a network it pays out to in that
 * country (see payout-options), the number is the wallet's with the
 * country's calling code, and the country must be the traveler's country of
 * residence (nata.profiles.country_of_residence) when the profile has one.
 * A Nigerian bank account ({ kind: bank, country: NG }) has one of
 * Flutterwave's bank codes (see payout-options) and a 10-digit account
 * number, which Flutterwave must recognise: the holder's name is the one
 * the bank gives. Other banks are connected through Stripe instead
 * (stripe-connect). The
 * full number goes to nata.payout_destinations, which only the server reads;
 * the app keeps the last 4 digits (nata.payout_accounts). A first account
 * becomes the default.
 *
 * Responds 200 with the account { id, kind, institution_name, country_code,
 * account_last4, holder_name, is_default }. Errors: 401 unauthorized,
 * 400 invalid, 409 not_supported (a bank outside Nigeria, or a network
 * pawaPay doesn't pay out to there) / country_mismatch (not the country of
 * residence) / limit_reached (already two payout accounts, 20240175) /
 * account_not_found (Flutterwave doesn't recognise the bank account),
 * 503 payments_unavailable (Flutterwave can't be reached).
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

  // Payouts go to the country the traveler lives in.
  const { data: profile } = await admin
    .schema("nata")
    .from("profiles")
    .select("country_of_residence")
    .eq("id", user.id)
    .maybeSingle();
  const residence = String(profile?.country_of_residence ?? "").trim()
    .toUpperCase();
  if (residence && residence !== country) {
    return json({ error: "country_mismatch" }, 409);
  }

  const currency = await countryCurrency(country);
  if (!currency) return json({ error: "not_supported" }, 409);

  const db = admin.schema("nata");

  // A Nigerian bank: one Flutterwave pays out to, and an account it
  // recognises, saved under the name the bank gives.
  if (kind === "bank") {
    if (country !== "NG") return json({ error: "not_supported" }, 409);
    if (!/^[0-9]{10}$/.test(number)) return json({ error: "invalid" }, 400);
    if (!flutterwaveKey()) return json({ error: "payments_unavailable" }, 503);
    const banks = await nigerianBanks();
    if (!banks.length) return json({ error: "payments_unavailable" }, 503);
    const bank = banks.find((x) => x.code === bankCode);
    if (!bank) return json({ error: "not_supported" }, 409);
    const resolved = await flutterwave("/accounts/resolve", {
      method: "POST",
      body: { account_number: number, account_bank: bankCode },
    });
    if (resolved.status === 0 || resolved.status >= 500) {
      return json({ error: "payments_unavailable" }, 503);
    }
    const bankName = String(
      (resolved.body.data as { account_name?: unknown } | undefined)
        ?.account_name ?? "",
    ).trim().replace(/\s+/g, " ");
    if (!resolved.ok || bankName.length < 2) {
      return json({ error: "account_not_found" }, 409);
    }
    const { data: account, error } = await db
      .from("payout_accounts")
      .insert({
        user_id: user.id,
        kind,
        institution_name: bank.name.slice(0, 80),
        country_code: country,
        account_last4: number.slice(-4),
        holder_name: bankName.slice(0, 80),
      })
      .select("id, kind, institution_name, country_code, account_last4, holder_name, is_default")
      .single();
    if (error || !account) {
      if (error?.message?.includes("payout_account_limit")) {
        return json({ error: "limit_reached" }, 409);
      }
      console.error("[add-payout-account] account", error);
      return json({ error: "invalid" }, 400);
    }
    const { error: destError } = await db.from("payout_destinations").insert({
      account_id: account.id,
      account_bank: bankCode,
      account_number: number,
      currency: "NGN",
    });
    if (destError) {
      console.error("[add-payout-account] destination", destError);
      await db.from("payout_accounts").delete().eq("id", account.id);
      return json({ error: "invalid" }, 400);
    }
    return json(account);
  }

  // Only a network pawaPay pays out to there, and a number with the
  // country's calling code.
  const network = (await networks(country)).find((n) => n.code === bankCode);
  if (!network) return json({ error: "not_supported" }, 409);
  const { data: place } = await admin
    .schema("nata")
    .from("countries")
    .select("phone_code")
    .eq("iso_code", country)
    .maybeSingle();
  const dial = String(place?.phone_code ?? "").replace(/\D/g, "");
  if (!dial || !number.startsWith(dial) || number.length < dial.length + 7) {
    return json({ error: "invalid" }, 400);
  }

  const { data: account, error } = await db
    .from("payout_accounts")
    .insert({
      user_id: user.id,
      kind,
      // pawaPay's name for the network.
      institution_name: network.name,
      country_code: country,
      account_last4: number.slice(-4),
      holder_name: holder,
    })
    .select("id, kind, institution_name, country_code, account_last4, holder_name, is_default")
    .single();
  if (error || !account) {
    if (error?.message?.includes("payout_account_limit")) {
      return json({ error: "limit_reached" }, 409);
    }
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
