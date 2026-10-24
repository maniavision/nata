/**
 * stripe-connect-return — where Stripe sends a traveler back after its pages
 * for their bank (stripe-connect). The app checks the account itself once
 * they're back, so this only says where to go next (?again=1: the link had
 * expired; the app gives a new one). Plain text: Supabase doesn't serve HTML
 * pages from functions. Deployed with --no-verify-jwt (opened from the
 * browser).
 */

const DONE = [
  "Nata",
  "",
  "You can close this page and go back to the Nata app.",
  "Vous pouvez fermer cette page et revenir à l'application Nata.",
  "Puedes cerrar esta página y volver a la aplicación Nata.",
].join("\n");

const AGAIN = [
  "Nata",
  "",
  "This link has expired. Go back to the Nata app and tap Continue setup with Stripe.",
  "Ce lien a expiré. Revenez dans l'application Nata et touchez Continuer avec Stripe.",
  "Este enlace ha caducado. Vuelve a la aplicación Nata y toca Continuar con Stripe.",
].join("\n");

Deno.serve((req: Request) => {
  const again = new URL(req.url).searchParams.has("again");
  return new Response(again ? AGAIN : DONE, {
    headers: { "Content-Type": "text/plain; charset=utf-8" },
  });
});
