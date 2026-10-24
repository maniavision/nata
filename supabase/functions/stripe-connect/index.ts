/**
 * stripe-connect — a traveler connects their bank through Stripe, to be paid
 * there (20240170). For travelers who live where Stripe Connect can pay out
 * to a bank from Nata's US account: the US, the UK, the EEA, Canada and
 * Switzerland.
 *
 * Called by the app (with the traveler's JWT) with { action }:
 *   * start: makes the traveler's Stripe account (Express, transfers only)
 *     if they have none, in their country of residence, and answers
 *     { url }: Stripe's own pages, where they give their identity and bank
 *     details (never to Nata). Stripe sends them back to
 *     stripe-connect-return.
 *   * status (with { save }): looks the account up with Stripe and keeps
 *     Nata in step (stripe-webhook does too, on account.updated). Answers
 *     { status }: none (no account yet), incomplete (Stripe's form isn't
 *     finished), pending (Stripe is checking it) or enabled (payouts can go
 *     to the bank: { bank: { institution_name, account_last4 } }, and
 *     { account } as add-payout-account answers once it is one of the
 *     traveler's payout accounts). The bank becomes one by itself the
 *     first time; after the traveler removed it, only with save
 *     (20240172).
 *
 * Errors: 401 unauthorized, 400 bad_request, 409 not_supported (no country
 * of residence, or one Stripe can't pay out to), 503 payments_unavailable,
 * 502 provider_error.
 */

// ── Stripe and Supabase helpers (the same in each payment function, so each
// can be deployed on its own, also from the dashboard) ──────────────────────

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

function stripeKey(): string | null {
  const key = Deno.env.get("STRIPE_SECRET_KEY")?.trim();
  return key ? key : null;
}

/** Calls Stripe (form-encoded); [status] 0 when it couldn't be reached. */
async function stripe(
  path: string,
  init: { method?: string; form?: Record<string, string>; idempotencyKey?: string } = {},
): Promise<{ status: number; body: Record<string, unknown> }> {
  const headers: Record<string, string> = {
    Authorization: `Bearer ${stripeKey()}`,
  };
  if (init.form) headers["Content-Type"] = "application/x-www-form-urlencoded";
  if (init.idempotencyKey) headers["Idempotency-Key"] = init.idempotencyKey;
  let res: Response;
  try {
    res = await fetch(`https://api.stripe.com/v1${path}`, {
      method: init.method ?? "GET",
      headers,
      body: init.form ? new URLSearchParams(init.form).toString() : undefined,
    });
  } catch (_) {
    return { status: 0, body: {} };
  }
  let body: Record<string, unknown> = {};
  try {
    body = await res.json();
  } catch (_) {
    // Not JSON: keep the empty body.
  }
  return { status: res.status, body };
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

/**
 * Keeps nata.stripe_accounts in step with the Stripe account [account] (as
 * Stripe returns it) of [userId]. Once Stripe allows payouts, the bank is one
 * of the traveler's payout accounts (kind bank, paid in US dollars): added
 * as their default the first time (20240172), and again only when [save]
 * (the traveler tapped "Use this bank"), so a removed one stays removed. A
 * bank already among their accounts gets its name and last digits kept up
 * to date. Answers the bank's name and last digits once payouts are allowed.
 */
async function syncAccount(
  userId: string,
  account: Record<string, unknown>,
  save = false,
): Promise<{ institution: string; last4: string } | null> {
  const db = admin.schema("nata");
  const id = String(account.id ?? "");
  const payoutsEnabled = account.payouts_enabled === true;
  await db.from("stripe_accounts").update({
    details_submitted: account.details_submitted === true,
    payouts_enabled: payoutsEnabled,
    updated_at: new Date().toISOString(),
  }).eq("user_id", userId).eq("account_id", id);
  if (!payoutsEnabled) return null;

  const banks = ((account.external_accounts as { data?: unknown[] } | undefined)
    ?.data ?? []) as { bank_name?: string; last4?: string }[];
  const bank = banks[0] ?? {};
  let institution = String(bank.bank_name ?? "").trim().slice(0, 80) ||
    "Bank account";
  if (institution.length < 2) institution = "Bank account";
  const last4 = String(bank.last4 ?? "").toUpperCase().replace(/[^0-9A-Z]/g, "")
    .slice(-4).padStart(4, "0");

  const { data: existing } = await db.from("payout_destinations")
    .select("account_id")
    .eq("account_bank", "STRIPE")
    .eq("account_number", id)
    .maybeSingle();
  if (existing) {
    await db.from("payout_accounts")
      .update({ institution_name: institution, account_last4: last4 })
      .eq("id", existing.account_id)
      .eq("user_id", userId);
    return { institution, last4 };
  }

  // Added once by itself; after the traveler removed it, only when asked.
  const { data: row } = await db.from("stripe_accounts")
    .select("bank_added_at")
    .eq("user_id", userId)
    .eq("account_id", id)
    .maybeSingle();
  if (row?.bank_added_at && !save) return { institution, last4 };

  const { data: profile } = await db.from("profiles")
    .select("first_name, last_name")
    .eq("id", userId)
    .maybeSingle();
  const holder = [profile?.first_name, profile?.last_name]
    .filter((p) => p && String(p).trim())
    .join(" ").trim().slice(0, 80);
  const { data: saved, error } = await db.from("payout_accounts").insert({
    user_id: userId,
    kind: "bank",
    institution_name: institution,
    country_code: String(account.country ?? "").toUpperCase() || null,
    account_last4: last4,
    holder_name: holder.length >= 2 ? holder : "Nata traveler",
    // The bank the traveler just connected is where they want to be paid.
    is_default: true,
  }).select("id").single();
  if (error || !saved) {
    console.error("[stripe-connect] payout account", error);
    return { institution, last4 };
  }
  const { error: destError } = await db.from("payout_destinations").insert({
    account_id: saved.id,
    account_bank: "STRIPE",
    account_number: id,
    currency: "USD",
  });
  if (destError) {
    console.error("[stripe-connect] payout destination", destError);
    await db.from("payout_accounts").delete().eq("id", saved.id);
    return { institution, last4 };
  }
  await db.from("stripe_accounts")
    .update({ bank_added_at: new Date().toISOString() })
    .eq("user_id", userId)
    .eq("account_id", id);
  return { institution, last4 };
}

// ── This function ──────────────────────────────────────────────────────────

/** Where Stripe sends the traveler back (a page that says to go back). */
function returnUrl(again: boolean): string {
  return `${Deno.env.get("SUPABASE_URL")}/functions/v1/stripe-connect-return` +
    (again ? "?again=1" : "");
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  if (!stripeKey()) return json({ error: "payments_unavailable" }, 503);
  const user = await caller(req);
  if (!user) return json({ error: "unauthorized" }, 401);

  let action = "";
  let save = false;
  try {
    const body = await req.json();
    action = String(body.action ?? "");
    save = body.save === true;
  } catch (_) {
    return json({ error: "bad_request" }, 400);
  }
  if (action !== "start" && action !== "status") {
    return json({ error: "bad_request" }, 400);
  }

  const db = admin.schema("nata");
  const { data: row } = await db.from("stripe_accounts")
    .select("account_id")
    .eq("user_id", user.id)
    .maybeSingle();

  if (action === "status") {
    if (!row) return json({ status: "none" });
    const res = await stripe(`/accounts/${encodeURIComponent(row.account_id)}`);
    if (res.status !== 200) {
      console.error("[stripe-connect] status", res.status);
      return json({ error: "provider_error" }, 502);
    }
    const bank = await syncAccount(user.id, res.body, save);
    if (res.body.payouts_enabled !== true) {
      return json({
        status: res.body.details_submitted === true ? "pending" : "incomplete",
      });
    }
    const { data: dest } = await db.from("payout_destinations")
      .select("account_id")
      .eq("account_bank", "STRIPE")
      .eq("account_number", row.account_id)
      .maybeSingle();
    const { data: account } = dest
      ? await db.from("payout_accounts")
        .select("id, kind, institution_name, country_code, account_last4, holder_name, is_default")
        .eq("id", dest.account_id)
        .maybeSingle()
      : { data: null };
    return json({
      status: "enabled",
      account,
      bank: bank
        ? { institution_name: bank.institution, account_last4: bank.last4 }
        : null,
    });
  }

  // start: the account, then a link to Stripe's pages.
  let accountId = row?.account_id as string | undefined;
  if (!accountId) {
    const { data: profile } = await db.from("profiles")
      .select("country_of_residence")
      .eq("id", user.id)
      .maybeSingle();
    const country = String(profile?.country_of_residence ?? "").trim()
      .toUpperCase();
    if (!STRIPE_COUNTRIES.has(country)) {
      return json({ error: "not_supported" }, 409);
    }
    const created = await stripe("/accounts", {
      method: "POST",
      idempotencyKey: `nata-connect-${user.id}`,
      form: {
        type: "express",
        country,
        business_type: "individual",
        "capabilities[transfers][requested]": "true",
        "business_profile[product_description]":
          "Carries parcels for senders on Nata, paid per delivery",
        "metadata[user_id]": user.id,
        ...(user.email ? { email: String(user.email) } : {}),
      },
    });
    accountId = String(created.body.id ?? "");
    if (created.status !== 200 || !accountId.startsWith("acct_")) {
      const err = created.body.error as { message?: string } | undefined;
      console.error("[stripe-connect] account", created.status, err?.message);
      return json({ error: "provider_error" }, 502);
    }
    const { error } = await db.from("stripe_accounts").insert({
      user_id: user.id,
      account_id: accountId,
      country,
    });
    if (error) {
      console.error("[stripe-connect] save", error);
      return json({ error: "provider_error" }, 502);
    }
  }

  const link = await stripe("/account_links", {
    method: "POST",
    form: {
      account: accountId,
      type: "account_onboarding",
      refresh_url: returnUrl(true),
      return_url: returnUrl(false),
    },
  });
  const url = String(link.body.url ?? "");
  if (link.status !== 200 || !url) {
    const err = link.body.error as { message?: string } | undefined;
    console.error("[stripe-connect] link", link.status, err?.message);
    return json({ error: "provider_error" }, 502);
  }
  return json({ url });
});
