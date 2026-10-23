#!/usr/bin/env bash
# Sets up pawaPay for mobile money: stores the API token in the Supabase
# project's secrets and deploys the functions that use it:
#   * create-payment    (starts a deposit: the prompt on the payer's phone)
#   * verify-payment    (the app checks a payment)
#   * send-refunds      (refunds mobile money payments through pawaPay)
#   * pawapay-callback  (pawaPay reports deposits and refunds; no Supabase login)
#
# You are asked for the API token, which is not shown or saved anywhere else:
# pawaPay dashboard > System > API token (sandbox and production tokens are
# different). Run it with PAWAPAY_ENV=production to use the production API.
#
# Needs the Supabase CLI signed in (supabase login) and migration
# 20240165_pawapay_mobile_money.sql applied.
#
#   bash scripts/setup_pawapay.sh
set -euo pipefail

PROJECT_REF="${PROJECT_REF:-xnzredskhxfgywggetzw}"
PAWAPAY_ENV="${PAWAPAY_ENV:-sandbox}"

case "$PAWAPAY_ENV" in
  sandbox) api_url="https://api.sandbox.pawapay.io" ;;
  production) api_url="https://api.pawapay.io" ;;
  *)
    echo "PAWAPAY_ENV is sandbox or production." >&2
    exit 1
    ;;
esac

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

read -r -s -p "pawaPay API token ($PAWAPAY_ENV): " api_token
echo
if [ "${#api_token}" -lt 20 ]; then
  echo "That doesn't look like a pawaPay API token." >&2
  exit 1
fi

echo "1/2 Supabase secrets"
env_file=$(mktemp)
chmod 600 "$env_file"
trap 'rm -f "$env_file"' EXIT
printf 'PAWAPAY_API_TOKEN=%s\nPAWAPAY_API_URL=%s\n' "$api_token" "$api_url" >"$env_file"
unset api_token
supabase secrets set --project-ref "$PROJECT_REF" --env-file "$env_file" >/dev/null

echo "2/2 Deploying functions"
supabase functions deploy create-payment --project-ref "$PROJECT_REF"
supabase functions deploy verify-payment --project-ref "$PROJECT_REF"
supabase functions deploy send-refunds --project-ref "$PROJECT_REF"
supabase functions deploy pawapay-callback --no-verify-jwt --project-ref "$PROJECT_REF"

echo
echo "Done. In the pawaPay dashboard > System > API token > Callback URLs, set"
echo "the Deposits and Refunds callback URLs to:"
echo "  https://$PROJECT_REF.supabase.co/functions/v1/pawapay-callback"
