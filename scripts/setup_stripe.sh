#!/usr/bin/env bash
# Sets up Stripe for card and Apple Pay payments: stores the keys in the
# Supabase project's secrets and deploys the functions that use them:
#   * create-payment   (starts a PaymentIntent for the app's payment sheet)
#   * verify-payment   (the app checks a payment)
#   * send-refunds     (refunds card payments through Stripe)
#   * stripe-webhook   (Stripe reports payments; no Supabase login)
#
# You are asked for the keys, which are not shown or saved anywhere else:
# Stripe dashboard > Developers > API keys (test keys start sk_test_ and
# pk_test_, live ones sk_live_ and pk_live_). The webhook signing secret
# (whsec_...) exists once the webhook is added (see the end); leave it empty
# the first time and run this again with it.
#
# Apple Pay in the payment sheet also needs an Apple Pay merchant ID (for
# example merchant.com.nata.nataApp) whose certificate is set up in Stripe
# (Settings > Payment methods > Apple Pay), and the Apple Pay capability on
# the iOS app. Leave it empty until then: the sheet offers cards only.
#
# Needs the Supabase CLI signed in (supabase login).
#
#   bash scripts/setup_stripe.sh
set -euo pipefail

PROJECT_REF="${PROJECT_REF:-xnzredskhxfgywggetzw}"

if ! command -v supabase >/dev/null; then
  echo "The Supabase CLI is missing. Install it with: brew install supabase/tap/supabase" >&2
  exit 1
fi
if ! supabase secrets list --project-ref "$PROJECT_REF" >/dev/null 2>&1; then
  echo "Sign in to Supabase first: supabase login" >&2
  exit 1
fi

# Deploying needs the project's supabase/ folder.
cd "$(dirname "$0")/.."

read -r -s -p "Stripe secret key (sk_...): " secret_key
echo
case "$secret_key" in
  sk_test_* | sk_live_* | rk_test_* | rk_live_*) ;;
  *)
    echo "That doesn't look like a Stripe secret key." >&2
    exit 1
    ;;
esac
read -r -p "Stripe publishable key (pk_...): " publishable_key
case "$publishable_key" in
  pk_test_* | pk_live_*) ;;
  *)
    echo "That doesn't look like a Stripe publishable key." >&2
    exit 1
    ;;
esac
if [ "${secret_key:3:4}" != "${publishable_key:3:4}" ]; then
  echo "One key is a test key and the other a live key." >&2
  exit 1
fi
read -r -s -p "Webhook signing secret (whsec_..., empty to add it later): " webhook_secret
echo
if [ -n "$webhook_secret" ] && [[ "$webhook_secret" != whsec_* ]]; then
  echo "That doesn't look like a webhook signing secret." >&2
  exit 1
fi
read -r -p "Apple Pay merchant ID (empty for cards only): " apple_merchant_id

echo "1/2 Supabase secrets"
env_file=$(mktemp)
chmod 600 "$env_file"
trap 'rm -f "$env_file"' EXIT
{
  printf 'STRIPE_SECRET_KEY=%s\n' "$secret_key"
  printf 'STRIPE_PUBLISHABLE_KEY=%s\n' "$publishable_key"
  if [ -n "$webhook_secret" ]; then
    printf 'STRIPE_WEBHOOK_SECRET=%s\n' "$webhook_secret"
  fi
  if [ -n "$apple_merchant_id" ]; then
    printf 'STRIPE_APPLE_MERCHANT_ID=%s\n' "$apple_merchant_id"
  fi
} >"$env_file"
has_webhook_secret=$([ -n "$webhook_secret" ] && echo yes || echo no)
unset secret_key webhook_secret
supabase secrets set --project-ref "$PROJECT_REF" --env-file "$env_file" >/dev/null

echo "2/2 Deploying functions"
supabase functions deploy create-payment --project-ref "$PROJECT_REF"
supabase functions deploy verify-payment --project-ref "$PROJECT_REF"
supabase functions deploy send-refunds --project-ref "$PROJECT_REF"
supabase functions deploy stripe-webhook --no-verify-jwt --project-ref "$PROJECT_REF"

echo
echo "Done. In the Stripe dashboard > Developers > Webhooks, add an endpoint:"
echo "  https://$PROJECT_REF.supabase.co/functions/v1/stripe-webhook"
echo "for the events payment_intent.succeeded and payment_intent.canceled,"
if [ "$has_webhook_secret" = no ]; then
  echo "then run this again with its signing secret."
else
  echo "if it isn't there yet."
fi
