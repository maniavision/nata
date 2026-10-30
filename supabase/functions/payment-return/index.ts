/**
 * payment-return — where Flutterwave sends the sender after paying. The app
 * notices the payment by itself and closes this page, so it only has to say
 * where to go next. Plain text: Supabase doesn't serve HTML pages from
 * functions. Deployed with --no-verify-jwt (opened from the browser).
 */

const MESSAGE = [
  "Nata",
  "",
  "You can close this page and go back to the Nata app.",
  "Vous pouvez fermer cette page et revenir à l'application Nata.",
  "Puedes cerrar esta página y volver a la aplicación Nata.",
].join("\n");

Deno.serve(() =>
  new Response(MESSAGE, {
    headers: { "Content-Type": "text/plain; charset=utf-8" },
  })
);
