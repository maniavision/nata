#!/usr/bin/env bash
# Sets up Flutterwave payments: stores the keys in the Supabase project's
# secrets and deploys the payment functions:
#   * create-payment       (the app asks for a payment link)
#   * verify-payment       (the app checks a payment)
#   * flutterwave-webhook  (Flutterwave reports payments; no Supabase login)
#   * payment-return       (the page shown after paying; no Supabase login)
#
# You are asked for two values, which are not shown or saved anywhere else:
#   * Secret key: Flutterwave dashboard > Settings > API keys
#     (FLWSECK_TEST-... in test mode, FLWSECK-... when live).
#   * Secret hash: any long random text you choose. Enter the same text in
#     Flutterwave dashboard > Settings > Webhooks, with the webhook URL this
#     script prints at the end.
#
# Needs the Supabase CLI signed in (supabase login).
#
#   bash scripts/setup_flutterwave.sh
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

read -r -s -p "Flutterwave secret key: " secret_key
echo
read -r -s -p "Webhook secret hash (the same text as in the Flutterwave dashboard): " secret_hash
echo
if [[ ! "$secret_key" =~ ^FLWSECK ]]; then
  echo "That doesn't look like a Flutterwave secret key (it starts with FLWSECK)." >&2
  exit 1
fi
if [ "${#secret_hash}" -lt 16 ]; then
  echo "Use a secret hash of at least 16 characters." >&2
  exit 1
fi

echo "1/2 Supabase secrets"
env_file=$(mktemp)
chmod 600 "$env_file"
trap 'rm -f "$env_file"' EXIT
printf 'FLW_SECRET_KEY=%s\nFLW_SECRET_HASH=%s\n' "$secret_key" "$secret_hash" >"$env_file"
unset secret_key secret_hash
supabase secrets set --project-ref "$PROJECT_REF" --env-file "$env_file" >/dev/null

echo "2/2 Deploying functions"
supabase functions deploy create-payment --project-ref "$PROJECT_REF"
supabase functions deploy verify-payment --project-ref "$PROJECT_REF"
supabase functions deploy flutterwave-webhook --no-verify-jwt --project-ref "$PROJECT_REF"
supabase functions deploy payment-return --no-verify-jwt --project-ref "$PROJECT_REF"

echo
echo "Done. In the Flutterwave dashboard > Settings > Webhooks, set:"
echo "  URL:         https://$PROJECT_REF.supabase.co/functions/v1/flutterwave-webhook"
echo "  Secret hash: the same text you just entered"
