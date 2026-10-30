/**
 * stripe-cards — the signed-in member's cards saved with Stripe
 * (20240196_stripe_customers.sql). Card numbers go from Stripe's own sheet
 * straight to Stripe; Nata only ever sees the brand, last 4 digits and
 * expiry.
 *
 * Called by the app (with the member's JWT) with { action }:
 *   * list: { cards: [{ id, brand, last4, exp_month, exp_year, is_default }] }
 *     (none until the member has a Stripe Customer).
 *   * setup: starts saving a card: { setup_intent, client_secret,
 *     customer_id, ephemeral_key, publishable_key, merchant_country,
 *     apple_merchant_id } for the sheet in setup mode.
 *   * finish_setup { setup_intent, make_default }: once the sheet saved it,
 *     makes it the default when asked, or when there is none yet.
 *   * set_default { card_id } and remove { card_id }: only the member's own.
 *
 * Errors: 401 unauthorized, 400 bad_request, 404 not_found (not their card),
 * 503 payments_unavailable, 502 provider_error.
 */

// ── Stripe and Supabase helpers (the same in each payment function, so
// each can be deployed on its own, also from the dashboard) ──────────────

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

function stripeKey(): string | null {
  const key = Deno.env.get("STRIPE_SECRET_KEY")?.trim();
  return key ? key : null;
}

/** Calls Stripe (form-encoded); [status] 0 when it couldn't be reached. */
async function stripe(
  path: string,
  init: {
    method?: string;
    form?: Record<string, string>;
    idempotencyKey?: string;
    stripeVersion?: string;
  } = {},
): Promise<{ status: number; body: Record<string, unknown> }> {
  const headers: Record<string, string> = {
    Authorization: `Bearer ${stripeKey()}`,
  };
  if (init.form) headers["Content-Type"] = "application/x-www-form-urlencoded";
  if (init.idempotencyKey) headers["Idempotency-Key"] = init.idempotencyKey;
  if (init.stripeVersion) headers["Stripe-Version"] = init.stripeVersion;
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


/** The signed-in user calling the function, from their JWT. */
async function caller(req: Request) {
  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) return null;
  const { data: { user } } = await admin.auth.getUser(token);
  return user ?? null;
}

/** The API version the mobile payment sheet's ephemeral keys are made for. */
const SHEET_API_VERSION = "2024-06-20";

/**
 * The member's Stripe Customer (nata.stripe_customers, 20240196), made the
 * first time; null when Stripe can't be reached.
 */
async function stripeCustomer(
  userId: string,
  email?: string | null,
): Promise<string | null> {
  const db = admin.schema("nata");
  const { data: row } = await db.from("stripe_customers")
    .select("customer_id")
    .eq("user_id", userId)
    .maybeSingle();
  if (row?.customer_id) return String(row.customer_id);
  const res = await stripe("/customers", {
    method: "POST",
    idempotencyKey: `nata-customer-${userId}`,
    form: {
      "metadata[user_id]": userId,
      ...(email ? { email: String(email) } : {}),
    },
  });
  const id = String(res.body.id ?? "");
  if (res.status !== 200 || !id) {
    console.error("[stripe] customer", res.status);
    return null;
  }
  const { error } = await db.from("stripe_customers")
    .upsert({ user_id: userId, customer_id: id }, { onConflict: "user_id", ignoreDuplicates: true });
  if (error) console.error("[stripe] save customer", error.message);
  // Another call may have saved one first: that one wins.
  const { data: saved } = await db.from("stripe_customers")
    .select("customer_id")
    .eq("user_id", userId)
    .maybeSingle();
  return saved?.customer_id ? String(saved.customer_id) : id;
}

/** A short-lived key letting the payment sheet show [customer]'s cards. */
async function ephemeralKey(customer: string): Promise<string | null> {
  const res = await stripe("/ephemeral_keys", {
    method: "POST",
    stripeVersion: SHEET_API_VERSION,
    form: { customer },
  });
  return res.status === 200 ? String(res.body.secret ?? "") || null : null;
}

// ── This function ──────────────────────────────────────────────────────────

type Card = {
  id: string;
  brand: string;
  last4: string;
  exp_month: number;
  exp_year: number;
  is_default: boolean;
};

/** The customer's default card (invoice_settings), or null. */
async function defaultCard(customer: string): Promise<string | null> {
  const res = await stripe(`/customers/${encodeURIComponent(customer)}`);
  const settings = res.body.invoice_settings as
    | { default_payment_method?: string | null }
    | undefined;
  return settings?.default_payment_method ?? null;
}

async function listCards(customer: string): Promise<Card[] | null> {
  const [res, def] = await Promise.all([
    stripe(
      `/customers/${encodeURIComponent(customer)}/payment_methods?type=card&limit=20`,
    ),
    defaultCard(customer),
  ]);
  if (res.status !== 200) return null;
  const data = (res.body.data ?? []) as {
    id: string;
    card?: { brand?: string; last4?: string; exp_month?: number; exp_year?: number };
  }[];
  // The default first, then the newest.
  const cards = data.map((pm) => ({
    id: pm.id,
    brand: String(pm.card?.brand ?? "card"),
    last4: String(pm.card?.last4 ?? ""),
    exp_month: Number(pm.card?.exp_month ?? 0),
    exp_year: Number(pm.card?.exp_year ?? 0),
    is_default: pm.id === def,
  }));
  return cards.sort((a, b) => Number(b.is_default) - Number(a.is_default));
}

async function setDefault(customer: string, card: string): Promise<boolean> {
  const res = await stripe(`/customers/${encodeURIComponent(customer)}`, {
    method: "POST",
    form: { "invoice_settings[default_payment_method]": card },
  });
  return res.status === 200;
}

/** [card] belongs to [customer]. */
async function owns(customer: string, card: string): Promise<boolean> {
  const res = await stripe(`/payment_methods/${encodeURIComponent(card)}`);
  return res.status === 200 && res.body.customer === customer;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  const user = await caller(req);
  if (!user) return json({ error: "unauthorized" }, 401);
  if (!stripeKey()) return json({ error: "payments_unavailable" }, 503);

  let body: Record<string, unknown> = {};
  try {
    body = await req.json();
  } catch (_) {
    return json({ error: "bad_request" }, 400);
  }
  const action = String(body.action ?? "");

  if (action === "list") {
    const { data: row } = await admin.schema("nata").from("stripe_customers")
      .select("customer_id")
      .eq("user_id", user.id)
      .maybeSingle();
    if (!row?.customer_id) return json({ cards: [] });
    const cards = await listCards(String(row.customer_id));
    if (!cards) return json({ error: "provider_error" }, 502);
    return json({ cards });
  }

  const customer = await stripeCustomer(user.id, user.email);
  if (!customer) return json({ error: "provider_error" }, 502);

  switch (action) {
    case "setup": {
      const [si, key] = await Promise.all([
        stripe("/setup_intents", {
          method: "POST",
          form: {
            customer,
            usage: "off_session",
            "payment_method_types[]": "card",
            "metadata[user_id]": user.id,
          },
        }),
        ephemeralKey(customer),
      ]);
      const secret = String(si.body.client_secret ?? "");
      if (si.status !== 200 || !secret || !key) {
        console.error("[stripe-cards] setup", si.status);
        return json({ error: "provider_error" }, 502);
      }
      return json({
        setup_intent: si.body.id,
        client_secret: secret,
        customer_id: customer,
        ephemeral_key: key,
        publishable_key: Deno.env.get("STRIPE_PUBLISHABLE_KEY")?.trim() ?? "",
        merchant_country: "US",
        apple_merchant_id: Deno.env.get("STRIPE_APPLE_MERCHANT_ID")?.trim() || null,
      });
    }
    case "finish_setup": {
      const id = String(body.setup_intent ?? "");
      if (!id) return json({ error: "bad_request" }, 400);
      const si = await stripe(`/setup_intents/${encodeURIComponent(id)}`);
      if (si.status !== 200 || si.body.customer !== customer) {
        return json({ error: "not_found" }, 404);
      }
      const card = String(si.body.payment_method ?? "");
      if (si.body.status !== "succeeded" || !card) {
        return json({ error: "not_found" }, 404);
      }
      if (body.make_default === true || !(await defaultCard(customer))) {
        if (!(await setDefault(customer, card))) {
          return json({ error: "provider_error" }, 502);
        }
      }
      return json({ cards: (await listCards(customer)) ?? [] });
    }
    case "set_default":
    case "remove": {
      const card = String(body.card_id ?? "");
      if (!card) return json({ error: "bad_request" }, 400);
      if (!(await owns(customer, card))) return json({ error: "not_found" }, 404);
      if (action === "set_default") {
        if (!(await setDefault(customer, card))) {
          return json({ error: "provider_error" }, 502);
        }
      } else {
        const wasDefault = (await defaultCard(customer)) === card;
        const res = await stripe(
          `/payment_methods/${encodeURIComponent(card)}/detach`,
          { method: "POST", form: {} },
        );
        if (res.status !== 200) return json({ error: "provider_error" }, 502);
        // The newest other card becomes the default.
        if (wasDefault) {
          const rest = await listCards(customer);
          if (rest?.length) await setDefault(customer, rest[0].id);
        }
      }
      return json({ cards: (await listCards(customer)) ?? [] });
    }
  }
  return json({ error: "bad_request" }, 400);
});
