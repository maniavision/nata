/**
 * review-sign-in — signs the store reviewers' demo account in without a
 * code, as Google Play and App Review require (no SMS, no one-time code to
 * fetch).
 *
 * The demo account (supabase/seed/demo_accounts.md) uses a Supabase test
 * phone number, which has a fixed code. Called by the app (anon key) with
 * { phone } when that number is entered on Log in: for REVIEW_PHONE only, it
 * confirms the number with REVIEW_OTP (both function secrets, so the code
 * never ships in the app) and returns the session for the app to use.
 *
 * Responds 200 with { access_token, refresh_token }. Errors: 404 not_found
 * (any other number), 503 unavailable (secrets missing), 502 failed.
 */

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

/** Digits only, so "+1 202-555-0101" matches "+12025550101". */
const digits = (s: string) => s.replace(/\D/g, "");

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const reviewPhone = Deno.env.get("REVIEW_PHONE")?.trim() ?? "";
  const reviewOtp = Deno.env.get("REVIEW_OTP")?.trim() ?? "";
  if (!reviewPhone || !reviewOtp) return json({ error: "unavailable" }, 503);

  let phone = "";
  try {
    phone = String((await req.json()).phone ?? "");
  } catch (_) {
    return json({ error: "bad_request" }, 400);
  }
  if (!phone || digits(phone) !== digits(reviewPhone)) {
    return json({ error: "not_found" }, 404);
  }

  const res = await fetch(`${Deno.env.get("SUPABASE_URL")}/auth/v1/verify`, {
    method: "POST",
    headers: {
      apikey: Deno.env.get("SUPABASE_ANON_KEY")!,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      type: "sms",
      phone: `+${digits(reviewPhone)}`,
      token: reviewOtp,
    }),
  });
  const body = await res.json().catch(() => ({}));
  if (!res.ok || !body.refresh_token) {
    console.error("[review-sign-in] verify", res.status, body.error_code ?? body.msg);
    return json({ error: "failed" }, 502);
  }
  return json({
    access_token: body.access_token,
    refresh_token: body.refresh_token,
  });
});
