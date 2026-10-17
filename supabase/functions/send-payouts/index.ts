/**
 * send-payouts — sends the signed-in traveler's pending payouts with
 * Flutterwave transfers.
 *
 * Called by the app (with the traveler's JWT) right after a delivery is
 * confirmed, after adding a payout account, and from Withdraw. Payouts with
 * nowhere to go yet (no payout account) stay pending. Each transfer carries
 * the payout's own reference, which Flutterwave refuses twice, so a payout
 * is never paid twice. Flutterwave then reports the result to
 * flutterwave-webhook (paid, or failed with its reason).
 *
 * Responds 200 with { sent, failed }. Errors: 401 unauthorized,
 * 503 payments_unavailable.
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

  const db = admin.schema("nata");
  const { data: claimed, error } = await db.rpc("claim_payouts", {
    p_traveler: user.id,
  });
  if (error) {
    console.error("[send-payouts] claim", error);
    return json({ sent: 0, failed: 0 });
  }

  let sent = 0;
  let failed = 0;
  for (const p of (claimed ?? []) as {
    reference: string;
    amount: number;
    currency: string;
    account_bank: string;
    account_number: string;
    holder_name: string;
    debit_currency: string;
  }[]) {
    try {
      const res = await flutterwave("/transfers", {
        method: "POST",
        body: {
          account_bank: p.account_bank,
          account_number: p.account_number,
          amount: Number(p.amount),
          currency: p.currency,
          debit_currency: p.debit_currency,
          beneficiary_name: p.holder_name,
          narration: "Nata delivery payout",
          reference: p.reference,
        },
      });
      const message = String(res.body.message ?? "");
      if (res.ok || /duplicate|already exist/i.test(message)) {
        const id = (res.body.data as { id?: unknown } | undefined)?.id;
        await db.rpc("payout_accepted", {
          p_reference: p.reference,
          p_provider_id: id == null ? null : String(id),
        });
        sent++;
      } else {
        // Refused (a wrong account, not enough balance...): support looks.
        await db.rpc("payout_failed", {
          p_reference: p.reference,
          p_reason: message || `HTTP ${res.status}`,
          p_retry: res.status >= 500,
        });
        failed++;
      }
    } catch (e) {
      // It may not have reached Flutterwave: try again later, same reference.
      await db.rpc("payout_failed", {
        p_reference: p.reference,
        p_reason: String(e),
        p_retry: true,
      });
      failed++;
    }
  }
  return json({ sent, failed });
});
