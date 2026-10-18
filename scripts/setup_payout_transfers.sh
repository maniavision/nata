#!/usr/bin/env bash
# Lets the database send payout transfers (20240151_payouts_from_database.sql):
#   * asks for the Flutterwave secret key (the same one as FLW_SECRET_KEY) and
#     stores it in Vault as flw_secret_key;
#   * prints the database's outgoing IP address, to whitelist in Flutterwave
#     dashboard > Settings > Whitelisted IP addresses.
#
# Run it again after changing the Flutterwave key, and check the IP after
# Supabase maintenance. The key is not shown or saved anywhere else.
# Needs the Supabase CLI signed in (supabase login) and 20240151 applied.
#
#   bash scripts/setup_payout_transfers.sh
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

read -r -s -p "Flutterwave secret key: " secret_key
echo
if [[ ! "$secret_key" =~ ^FLWSECK[A-Za-z0-9_-]+$ ]]; then
  echo "That doesn't look like a Flutterwave secret key (it starts with FLWSECK)." >&2
  exit 1
fi

tmp=$(mktemp -d)
chmod 700 "$tmp"
trap 'rm -rf "$tmp"' EXIT

cat >"$tmp/vault.sql" <<SQL
do \$\$
declare
  existing uuid;
begin
  select id into existing from vault.secrets where name = 'flw_secret_key';
  if existing is null then
    perform vault.create_secret('$secret_key', 'flw_secret_key');
  else
    perform vault.update_secret(existing, '$secret_key');
  end if;
end
\$\$;
SQL
unset secret_key

echo "1/2 Storing the key in Vault"
supabase db query --linked --project-ref "$PROJECT_REF" -f "$tmp/vault.sql" >/dev/null

echo "2/2 The database's outgoing IP address:"
supabase db query --linked --project-ref "$PROJECT_REF" \
  "select content as ip from extensions.http_get('https://api.ipify.org')" \
  | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1
echo
echo "Whitelist it in Flutterwave dashboard > Settings > Whitelisted IP addresses."
