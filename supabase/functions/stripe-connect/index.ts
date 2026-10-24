/**
 * stripe-connect — a traveler connects their bank through Stripe, to be paid
 * there (20240170). For travelers who live where Stripe Connect can pay out
 * to a bank from Nata's US account: the US, the UK, the EEA, Canada and
 * Switzerland.
 *
 * Called by the app (with the traveler's JWT) with { action }:
 *   * start: makes the traveler's Stripe account if they have none, in
 *     their country of residence (Accounts v2, which Stripe requires for new
 *     Connect platforms: a recipient that takes Stripe transfers, with the
 *     Express dashboard, Nata collecting fees and covering losses), and
 *     answers
 *     { url }: Stripe's own pages, where they give their identity and bank
 *     details (never to Nata). Stripe sends them back to
 *     stripe-connect-return.
 *   * status: looks the account up with Stripe and keeps Nata in step
 *     (stripe-webhook does too, on account.updated). Answers { status }:
 *     none (no account yet), incomplete (Stripe's form isn't finished),
 *     pending (Stripe is checking it) or enabled (payouts go to the bank;
 *     it is now one of the traveler's payout accounts, given as { account },
 *     as add-payout-account answers).
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
 * Stripe returns it) of [userId]. Once Stripe allows payouts, the account is
 * one of the traveler's payout accounts (kind bank, paid in US dollars):
 * added the first time, as their default, its bank's name and last digits
 * kept up to date.
 */
async function syncAccount(userId: string, account: Record<string, unknown>) {
  const db = admin.schema("nata");
  const id = String(account.id ?? "");
  const payoutsEnabled = account.payouts_enabled === true;
  await db.from("stripe_accounts").update({
    details_submitted: account.details_submitted === true,
    payouts_enabled: payoutsEnabled,
    updated_at: new Date().toISOString(),
  }).eq("user_id", userId).eq("account_id", id);
  if (!payoutsEnabled) return;

  const banks = ((account.external_accounts as { data?: unknown[] } | undefined)
    ?.data ?? []) as { bank_name?: string; last4?: string }[];
  const bank = banks[0] ?? {};
  const institution = String(bank.bank_name ?? "").trim().slice(0, 80) ||
    "Bank account";
  const last4 = String(bank.last4 ?? "").toUpperCase().replace(/[^0-9A-Z]/g, "")
    .slice(-4).padStart(4, "0");

  const { data: existing } = await db.from("payout_destinations")
    .select("account_id")
    .eq("account_bank", "STRIPE")
    .eq("account_number", id)
    .maybeSingle();
  if (existing) {
    await db.from("payout_accounts")
      .update({ institution_name: institution.length >= 2 ? institution : "Bank account", account_last4: last4 })
      .eq("id", existing.account_id)
      .eq("user_id", userId);
    return;
  }

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
    institution_name: institution.length >= 2 ? institution : "Bank account",
    country_code: String(account.country ?? "").toUpperCase() || null,
    account_last4: last4,
    holder_name: holder.length >= 2 ? holder : "Nata traveler",
    // The bank the traveler just connected is where they want to be paid.
    is_default: true,
  }).select("id").single();
  if (error || !saved) {
    console.error("[stripe-connect] payout account", error);
    return;
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
  }
}

/** Stripe's v2 API (Accounts v2): JSON in and out. */
const STRIPE_V2_VERSION = "2026-09-30.endive";

async function stripeV2(
  path: string,
  body: unknown,
  idempotencyKey?: string,
): Promise<{ status: number; body: Record<string, unknown> }> {
  const headers: Record<string, string> = {
    Authorization: `Bearer ${stripeKey()}`,
    "Content-Type": "application/json",
    "Stripe-Version": STRIPE_V2_VERSION,
  };
  if (idempotencyKey) headers["Idempotency-Key"] = idempotencyKey;
  let res: Response;
  try {
    res = await fetch(`https://api.stripe.com/v2${path}`, {
      method: "POST",
      headers,
      body: JSON.stringify(body),
    });
  } catch (_) {
    return { status: 0, body: {} };
  }
  let parsed: Record<string, unknown> = {};
  try {
    parsed = await res.json();
  } catch (_) {
    // Not JSON: keep the empty body.
  }
  return { status: res.status, body: parsed };
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
  try {
    action = String((await req.json()).action ?? "");
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
    await syncAccount(user.id, res.body);
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
    return json({ status: "enabled", account });
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
    const { data: person } = await db.from("profiles")
      .select("first_name, last_name")
      .eq("id", user.id)
      .maybeSingle();
    const name = [person?.first_name, person?.last_name]
      .filter((p) => p && String(p).trim())
      .join(" ").trim();
    const created = await stripeV2(
      "/core/accounts",
      {
        display_name: name || "Nata traveler",
        ...(user.email ? { contact_email: String(user.email) } : {}),
        identity: { country: country.toLowerCase(), entity_type: "individual" },
        configuration: {
          recipient: {
            capabilities: {
              stripe_balance: { stripe_transfers: { requested: true } },
            },
          },
        },
        // The Express dashboard needs Nata to collect fees and cover losses.
        dashboard: "express",
        defaults: {
          responsibilities: {
            fees_collector: "application",
            losses_collector: "application",
          },
        },
        metadata: { user_id: user.id },
      },
      // One account per traveler even if saving it below fails and they
      // try again within the hour; a refusal isn't replayed for longer.
      `nata-connect-${user.id}-${Math.floor(Date.now() / 3600000)}`,
    );
    accountId = String(created.body.id ?? "");
    if (created.status !== 200 || !accountId.startsWith("acct_")) {
      const err = created.body.error as { code?: string; message?: string } | undefined;
      console.error("[stripe-connect] account", created.status, err?.code, err?.message);
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

  const link = await stripeV2("/core/account_links", {
    account: accountId,
    use_case: {
      type: "account_onboarding",
      account_onboarding: {
        configurations: ["recipient"],
        refresh_url: returnUrl(true),
        return_url: returnUrl(false),
      },
    },
  });
  const url = String(link.body.url ?? "");
  if (link.status !== 200 || !url) {
    const err = link.body.error as { code?: string; message?: string } | undefined;
    console.error("[stripe-connect] link", link.status, err?.code, err?.message);
    return json({ error: "provider_error" }, 502);
  }
  return json({ url });
});
