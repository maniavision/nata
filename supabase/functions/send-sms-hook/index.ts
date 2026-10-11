/**
 * Supabase Send SMS Hook — Bird SMS Gateway
 *
 * Receives { user: { phone }, sms: { otp } } from Supabase Auth.
 * Supabase passes phone WITHOUT the leading + (e.g. "12029106345").
 * We add the + before forwarding to Bird.
 */

const BIRD_API_URL = "https://us1.platform.bird.com/v1/sms/messages";
const BIRD_API_KEY = Deno.env.get("BIRD_API_KEY") ??
  "bk_us1_FxwCn5LWMINmTljpUSjgTkD1aL0Fy";

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  let body: { user?: { phone?: string }; sms?: { otp?: string } };
  try {
    body = await req.json();
  } catch {
    console.error("[send-sms-hook] Failed to parse body");
    return new Response(JSON.stringify({}), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  const rawPhone = body?.user?.phone ?? "";
  const otp = body?.sms?.otp ?? "";

  // Supabase strips the leading + — add it back for E.164 format
  const phone = rawPhone.startsWith("+") ? rawPhone : `+${rawPhone}`;

  console.log(`[send-sms-hook] Sending OTP to ${phone} (raw: ${rawPhone})`);

  if (!rawPhone || !otp) {
    console.error("[send-sms-hook] Missing phone or otp:", JSON.stringify(body));
    return new Response(JSON.stringify({}), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  const birdResponse = await fetch(BIRD_API_URL, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${BIRD_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      to: phone,
      template: {
        slug: "bird_otp_verification",
        parameters: { code: otp },
      },
    }),
  });

  const birdData = await birdResponse.json();

  if (!birdResponse.ok) {
    console.error("[send-sms-hook] Bird error:", JSON.stringify(birdData));
    // Return 200 so Supabase keeps the OTP valid
    return new Response(JSON.stringify({}), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  console.log(`[send-sms-hook] Delivered — id: ${birdData.id}, status: ${birdData.status}`);

  return new Response(JSON.stringify({}), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
