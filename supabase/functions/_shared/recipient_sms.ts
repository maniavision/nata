/**
 * Texts to the recipient (who isn't on Nata), in the sender's language, and
 * the Bird call that sends them. Used by send-delivery-code (the code and
 * the link) and recipient-sms (the updates).
 *
 * Secrets: BIRD_API_KEY, BIRD_SENDER (a sender ID such as "Nata") and
 * BIRD_SENDER_US (an owned number for +1, which doesn't take sender IDs).
 */

const BIRD_API_URL = "https://us1.platform.bird.com/v1/sms/messages";

/** Where the recipient's page and the app invitation are (Firebase Hosting). */
export const WEB_BASE = "https://nata-app-a03de.web.app";
export const pageLink = (token: string) => `${WEB_BASE}/r/${token}`;
export const appLink = `${WEB_BASE}/app`;

type Lang = "en" | "fr" | "es";
export type SmsEvent = "code" | "picked_up" | "arriving" | "delivered" | "message";

// Each fits one SMS (160 characters of the plain SMS alphabet) except the
// code, which also carries the safety notes and takes two. Spanish is written
// without á, í, ó and ú, which would force the 70-character kind.
const TEXTS: Record<Lang, Record<SmsEvent, string>> = {
  en: {
    code: "{sender} sent you a parcel with Nata. Handover code: {code}. " +
      "Only give it to the traveler once the parcel is in your hands. " +
      "Always meet in a public place. Follow it and chat: {link}",
    picked_up: "{traveler} has your parcel from {sender} and is on the way " +
      "to {city}. Follow it: {link}",
    arriving: "{traveler} arrives in {city} today with your parcel from " +
      "{sender}. Meet in a public place: {link}",
    delivered: "Your parcel from {sender} was delivered. Thank you! Send or " +
      "carry parcels with Nata too: {app}",
    message: "{traveler}, who is bringing your parcel from {sender}, sent you " +
      "a message: {link}",
  },
  fr: {
    code: "{sender} vous envoie un colis avec Nata. Code de remise : {code}. " +
      "Ne le donnez au voyageur qu'une fois le colis en main. " +
      "Rencontrez-vous toujours dans un lieu public. Suivi et chat : {link}",
    picked_up: "{traveler} a votre colis de {sender} et part pour {city}. " +
      "Suivez-le : {link}",
    arriving: "{traveler} arrive à {city} aujourd'hui avec votre colis de " +
      "{sender}. Retrouvez-vous dans un lieu public : {link}",
    delivered: "Votre colis de {sender} a été livré. Merci ! Envoyez ou " +
      "transportez des colis vous aussi avec Nata : {app}",
    message: "{traveler}, qui apporte votre colis de {sender}, vous a écrit : " +
      "{link}",
  },
  es: {
    code: "{sender} te envio un paquete con Nata. Codigo de entrega: {code}. " +
      "Dalo al viajero solo cuando tengas el paquete en tus manos. " +
      "Reunanse siempre en un lugar publico. Siguelo y escribe: {link}",
    picked_up: "{traveler} tiene tu paquete de {sender} y va camino a " +
      "{city}. Siguelo: {link}",
    arriving: "{traveler} llega hoy a {city} con tu paquete de {sender}. " +
      "Reunanse en un lugar publico: {link}",
    delivered: "Tu paquete de {sender} fue entregado. ¡Gracias! Envia o " +
      "lleva paquetes tu también con Nata: {app}",
    message: "{traveler}, que lleva tu paquete de {sender}, te escribio: {link}",
  },
};

/** The [event] text in [language] (English if it isn't one of ours). */
export function smsText(
  language: string | null | undefined,
  event: SmsEvent,
  values: Record<string, string>,
): string {
  const lang = (["en", "fr", "es"].includes(String(language))
    ? language
    : "en") as Lang;
  return TEXTS[lang][event].replace(/\{(\w+)\}/g, (_, k) => values[k] ?? "");
}

export type SendResult = "sent" | "unavailable" | "failed";

/** Sends [text] to [phone] through Bird. */
export async function sendSms(phone: string, text: string): Promise<SendResult> {
  const apiKey = Deno.env.get("BIRD_API_KEY")?.trim();
  const senderId = Deno.env.get("BIRD_SENDER")?.trim();
  const senderUs = Deno.env.get("BIRD_SENDER_US")?.trim();
  if (!apiKey || !senderId) return "unavailable";
  const to = phone.startsWith("+") ? phone : `+${phone}`;
  // +1 (US, Canada) only accepts numbers as senders.
  const from = to.startsWith("+1") ? senderUs : senderId;
  if (!from) return "unavailable";
  const res = await fetch(BIRD_API_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ from, to, text, category: "transactional" }),
  });
  if (!res.ok) {
    console.error("[sms] bird", res.status, await res.text());
    return "failed";
  }
  return "sent";
}
