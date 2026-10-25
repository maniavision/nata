/**
 * stripe-connect — a traveler is paid to their bank through Stripe
 * (20240170): they give their details and bank account in Nata's own form,
 * and Nata creates their Stripe account with them. For travelers who live
 * where Stripe Connect can pay out to a bank from Nata's US account: the US,
 * the UK, the EEA, Canada and Switzerland.
 *
 * The account is an Accounts v2 recipient that takes Stripe transfers, with
 * no Stripe dashboard: Nata collects what Stripe needs (its "requirements"),
 * collects fees and covers losses. The traveler accepts Stripe's Connected
 * Account Agreement in the form; Nata records that acceptance (date, IP,
 * device) on the account. Travelers have no business website, so Nata gives
 * Stripe a description of what they do instead (PROFILE), which Stripe takes
 * in place of one. ID numbers and bank numbers are passed straight to
 * Stripe and not kept; Nata keeps only the bank's name and last 4 digits.
 *
 * Called by the app (with the traveler's JWT) with { action }:
 *   * submit, with { first_name, last_name, dob: { day, month, year },
 *     phone, address: { line1, city, state, postal_code }, id_number
 *     (US: the last 4 digits of the SSN), bank: { routing_number,
 *     account_number } (IBAN countries: account_number only), email
 *     (only when Nata has none), tos_accepted: true }: creates (or
 *     updates) the account and adds the bank account, then answers as
 *     status does.
 *   * status (with { save }): looks the account up with Stripe and keeps
 *     Nata in step (stripe-webhook does too, on account.updated). Answers
 *     { status }: none (no account yet), pending (Stripe is checking it),
 *     action_needed (Stripe needs more than the form gives, such as an ID
 *     photo, or a review) or enabled (payouts can go to the bank: { bank:
 *     { institution_name, account_last4 } }, and { account } once it is one
 *     of the traveler's payout accounts). The bank becomes one by itself the
 *     first time, and after submit; after the traveler removed it, only
 *     with save ("Use this bank", 20240172).
 *   * finish: { url } of Stripe's page for what is left (action_needed),
 *     which sends them back to stripe-connect-return.
 *
 * Errors: 401 unauthorized, 400 bad_request / invalid ({ message }: what
 * Stripe refused, such as a routing number), 409 not_supported (no country
 * of residence, or one Stripe can't pay out to) / email_required /
 * tos_required / limit_reached (already two payout accounts, and this bank
 * isn't one of them: 20240175), 503 payments_unavailable, 502 provider_error.
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

/**
 * Whether Stripe answered [status] for an account it doesn't know under
 * these keys: not found, or forbidden (an account of another Stripe account
 * or sandbox).
 */
function notOurs(status: number): boolean {
  return status === 404 || status === 403;
}

/** The same check as nata.payer_emails. */
const EMAIL = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

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

/** Where Stripe sends the traveler back (a page that says to go back). */
function returnUrl(again: boolean): string {
  return `${Deno.env.get("SUPABASE_URL")}/functions/v1/stripe-connect-return` +
    (again ? "?again=1" : "");
}

/** What a traveler does, for Stripe: travelers have no website, and Stripe
 * takes a product description in place of one (otherwise the account is
 * restricted until a website is given). */
const PROFILE = {
  product_description:
    "Carries parcels for senders on Nata, a peer-to-peer delivery app, " +
    "on trips they are already taking, and is paid out by Nata once the " +
    "delivery is confirmed.",
};

/** Stripe asks for a website or a description of the business. */
function needsProfile(account: Record<string, unknown>): boolean {
  const req = (account.requirements ?? {}) as {
    currently_due?: string[];
    past_due?: string[];
  };
  return [...(req.currently_due ?? []), ...(req.past_due ?? [])].some((r) =>
    r === "business_profile.url" ||
    r === "business_profile.product_description"
  );
}

/** The ID number Stripe needs from an individual, by country. */
const ID_NUMBER_TYPE: Record<string, string> = { US: "us_ssn_last_4" };

/** Where the traveler's bank account stands with Stripe. */
function statusOf(account: Record<string, unknown>): string {
  if (account.payouts_enabled === true) return "enabled";
  const req = (account.requirements ?? {}) as {
    currently_due?: string[];
    past_due?: string[];
  };
  const due = [...(req.currently_due ?? []), ...(req.past_due ?? [])];
  return due.length > 0 ? "action_needed" : "pending";
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  if (!stripeKey()) return json({ error: "payments_unavailable" }, 503);
  const user = await caller(req);
  if (!user) return json({ error: "unauthorized" }, 401);

  let body: Record<string, unknown> = {};
  try {
    body = await req.json();
  } catch (_) {
    return json({ error: "bad_request" }, 400);
  }
  const action = String(body.action ?? "");
  if (!["submit", "status", "finish"].includes(action)) {
    return json({ error: "bad_request" }, 400);
  }

  const db = admin.schema("nata");
  const { data: row } = await db.from("stripe_accounts")
    .select("account_id")
    .eq("user_id", user.id)
    .maybeSingle();
  let accountId = row?.account_id as string | undefined;
  if (accountId) {
    // Made with other Stripe keys (test mode, then a sandbox, or live):
    // Stripe no longer knows it, so it is as good as none.
    const known = await stripe(`/accounts/${encodeURIComponent(accountId)}`);
    if (notOurs(known.status)) {
      await db.from("stripe_accounts").delete()
        .eq("user_id", user.id)
        .eq("account_id", accountId);
      accountId = undefined;
    }
  }

  /** Where it stands now, as status answers; [save] adds the bank. */
  const answer = async (save = false) => {
    if (!accountId) return json({ status: "none" });
    let res = await stripe(`/accounts/${encodeURIComponent(accountId)}`);
    if (res.status === 200 && needsProfile(res.body)) {
      // Made before Nata gave the description: given now, then looked up
      // again.
      const given = await stripeV2(
        `/core/accounts/${encodeURIComponent(accountId)}`,
        { defaults: { profile: PROFILE } },
      );
      if (given.status === 200) {
        res = await stripe(`/accounts/${encodeURIComponent(accountId)}`);
      } else {
        console.error("[stripe-connect] profile", given.status);
      }
    }
    if (res.status !== 200) {
      console.error("[stripe-connect] status", res.status);
      return json({ error: "provider_error" }, 502);
    }
    const bank = await syncAccount(user.id, res.body, save);
    const status = statusOf(res.body);
    if (status !== "enabled") return json({ status });
    const { data: dest } = await db.from("payout_destinations")
      .select("account_id")
      .eq("account_bank", "STRIPE")
      .eq("account_number", accountId)
      .maybeSingle();
    const { data: account } = dest
      ? await db.from("payout_accounts")
        .select("id, kind, institution_name, country_code, account_last4, holder_name, is_default")
        .eq("id", dest.account_id)
        .maybeSingle()
      : { data: null };
    return json({
      status,
      account,
      bank: bank
        ? { institution_name: bank.institution, account_last4: bank.last4 }
        : null,
    });
  };

  /** Two payout accounts already, and none is this Stripe bank. */
  const full = async () => {
    const { data: accounts } = await db.from("payout_accounts")
      .select("id")
      .eq("user_id", user.id);
    if ((accounts ?? []).length < 2) return false;
    if (!accountId) return true;
    const { data: dest } = await db.from("payout_destinations")
      .select("account_id")
      .eq("account_bank", "STRIPE")
      .eq("account_number", accountId)
      .maybeSingle();
    return !dest;
  };

  if (action === "status") {
    if (body.save === true && await full()) {
      return json({ error: "limit_reached" }, 409);
    }
    return answer(body.save === true);
  }

  if (action === "finish") {
    if (!accountId) return json({ error: "bad_request" }, 400);
    const link = await stripeV2("/core/account_links", {
      account: accountId,
      use_case: {
        type: "account_onboarding",
        account_onboarding: {
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
  }

  // submit: the traveler's details and bank account, from Nata's form.
  if (await full()) return json({ error: "limit_reached" }, 409);
  const { data: profile } = await db.from("profiles")
    .select("country_of_residence")
    .eq("id", user.id)
    .maybeSingle();
  const country = String(profile?.country_of_residence ?? "").trim()
    .toUpperCase();
  if (!STRIPE_COUNTRIES.has(country)) {
    return json({ error: "not_supported" }, 409);
  }
  if (body.tos_accepted !== true) return json({ error: "tos_required" }, 409);

  const text = (v: unknown, max = 100) => String(v ?? "").trim().slice(0, max);
  const firstName = text(body.first_name, 80);
  const lastName = text(body.last_name, 80);
  const phone = text(body.phone, 20);
  const dob = (body.dob ?? {}) as Record<string, unknown>;
  const day = Number(dob.day), month = Number(dob.month), year = Number(dob.year);
  const address = (body.address ?? {}) as Record<string, unknown>;
  const bank = (body.bank ?? {}) as Record<string, unknown>;
  const accountNumber = text(bank.account_number, 40).replace(/[\s-]/g, "")
    .toUpperCase();
  const routing = text(bank.routing_number, 20).replace(/\s/g, "");
  const idNumber = text(body.id_number, 20).replace(/\D/g, "");
  const idType = ID_NUMBER_TYPE[country];
  if (
    firstName.length < 1 || lastName.length < 1 ||
    !Number.isInteger(day) || !Number.isInteger(month) ||
    !Number.isInteger(year) || year < 1900 ||
    !text(address.line1) || !text(address.city) ||
    !text(address.postal_code, 20) || accountNumber.length < 4 ||
    (idType && !idNumber)
  ) {
    return json({ error: "bad_request" }, 400);
  }

  // Stripe needs an email: the account's, the one given at checkout, or
  // the one given now (kept for next time).
  let email = String(user.email ?? "").trim();
  if (!email) {
    const { data: saved } = await db.from("payer_emails")
      .select("email")
      .eq("user_id", user.id)
      .maybeSingle();
    email = String(saved?.email ?? "");
  }
  const givenEmail = text(body.email, 200).toLowerCase();
  if (!email && EMAIL.test(givenEmail)) {
    email = givenEmail;
    const { error } = await db.from("payer_emails").upsert({
      user_id: user.id,
      email,
      updated_at: new Date().toISOString(),
    });
    if (error) console.error("[stripe-connect] email", error);
  }
  if (!email) return json({ error: "email_required" }, 409);

  const identity = {
    country: country.toLowerCase(),
    entity_type: "individual",
    individual: {
      given_name: firstName,
      surname: lastName,
      email,
      ...(phone ? { phone } : {}),
      date_of_birth: { day, month, year },
      address: {
        country: country.toLowerCase(),
        line1: text(address.line1),
        ...(text(address.line2) ? { line2: text(address.line2) } : {}),
        city: text(address.city),
        ...(text(address.state, 40) ? { state: text(address.state, 40) } : {}),
        postal_code: text(address.postal_code, 20),
      },
      ...(idType ? { id_numbers: [{ type: idType, value: idNumber }] } : {}),
    },
    attestations: {
      terms_of_service: {
        account: {
          date: new Date().toISOString(),
          ip: (req.headers.get("x-forwarded-for") ?? "").split(",")[0].trim() ||
            "0.0.0.0",
          user_agent: text(req.headers.get("user-agent"), 300) || "Nata app",
        },
      },
    },
  };
  const refused = (res: { status: number; body: Record<string, unknown> }, what: string) => {
    const err = res.body.error as { code?: string; message?: string } | undefined;
    console.error(`[stripe-connect] ${what}`, res.status, err?.code, err?.message);
    return res.status === 400 && err?.message
      ? json({ error: "invalid", message: err.message }, 400)
      : json({ error: "provider_error" }, 502);
  };

  if (!accountId) {
    const created = await stripeV2(
      "/core/accounts",
      {
        display_name: `${firstName} ${lastName}`,
        contact_email: email,
        identity,
        configuration: {
          recipient: {
            capabilities: {
              stripe_balance: { stripe_transfers: { requested: true } },
            },
          },
        },
        // No Stripe dashboard: Nata collects what Stripe needs, which
        // means Nata also collects fees and covers losses.
        dashboard: "none",
        defaults: {
          profile: PROFILE,
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
    const id = String(created.body.id ?? "");
    if (created.status !== 200 || !id.startsWith("acct_")) {
      return refused(created, "account");
    }
    accountId = id;
    const { error } = await db.from("stripe_accounts").insert({
      user_id: user.id,
      account_id: accountId,
      country,
    });
    if (error) {
      console.error("[stripe-connect] save", error);
      return json({ error: "provider_error" }, 502);
    }
  } else {
    // Given again (a correction, or what Stripe asked for): updated.
    const updated = await stripeV2(
      `/core/accounts/${encodeURIComponent(accountId)}`,
      { contact_email: email, identity, defaults: { profile: PROFILE } },
    );
    if (updated.status !== 200) return refused(updated, "update");
  }

  // The bank account, paid out to in the country's currency.
  const currency = await countryCurrency(country);
  const external = await stripe(
    `/accounts/${encodeURIComponent(accountId)}/external_accounts`,
    {
      method: "POST",
      form: {
        "external_account[object]": "bank_account",
        "external_account[country]": country,
        "external_account[currency]": (currency ?? "USD").toLowerCase(),
        "external_account[account_number]": accountNumber,
        ...(routing ? { "external_account[routing_number]": routing } : {}),
        "external_account[account_holder_name]": `${firstName} ${lastName}`,
        "external_account[account_holder_type]": "individual",
        default_for_currency: "true",
      },
    },
  );
  if (external.status !== 200) return refused(external, "bank");

  // Just given in the form: this bank is where they want to be paid.
  return answer(true);
});
