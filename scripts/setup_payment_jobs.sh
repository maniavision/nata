#!/usr/bin/env bash
# Sets up the payment-jobs schedule (20240147_payment_jobs.sql), which sends
# payouts and refunds left waiting every 15 minutes:
#   * makes a new random job secret and stores it as the functions'
#     PAYMENT_JOBS_SECRET and in Vault as payment_jobs_secret;
#   * stores the app's anon key in Vault as payment_jobs_anon_key (the
#     functions gateway needs one);
#   * deploys send-payouts and send-refunds, and runs the job once.
#
# Re-running makes a new secret, which is fine. The secret is not shown.
# Needs the Supabase CLI signed in (supabase login) and 20240147 applied.
#
#   bash scripts/setup_payment_jobs.sh
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

cd "$(dirname "$0")/.."

anon_key=$(sed -nE "s/^ *'(eyJ[^']+)';.*/\1/p" lib/config/supabase_config.dart | head -1)
if [ -z "$anon_key" ]; then
  echo "Couldn't find the anon key in lib/config/supabase_config.dart." >&2
  exit 1
fi
secret=$(openssl rand -hex 32)

tmp=$(mktemp -d)
chmod 700 "$tmp"
trap 'rm -rf "$tmp"' EXIT

echo "1/3 Function secret"
printf 'PAYMENT_JOBS_SECRET=%s\n' "$secret" >"$tmp/env"
supabase secrets set --project-ref "$PROJECT_REF" --env-file "$tmp/env" >/dev/null

echo "2/3 Vault"
cat >"$tmp/vault.sql" <<SQL
do \$\$
declare
  item record;
  existing uuid;
begin
  for item in
    select * from (values
      ('payment_jobs_secret', '$secret'),
      ('payment_jobs_anon_key', '$anon_key')) v(name, value)
  loop
    select id into existing from vault.secrets where name = item.name;
    if existing is null then
      perform vault.create_secret(item.value, item.name);
    else
      perform vault.update_secret(existing, item.value);
    end if;
  end loop;
end
\$\$;
SQL
unset secret anon_key
supabase db query --linked --project-ref "$PROJECT_REF" -f "$tmp/vault.sql" >/dev/null

echo "3/3 Deploying functions"
supabase functions deploy send-payouts --project-ref "$PROJECT_REF" --use-api
supabase functions deploy send-refunds --project-ref "$PROJECT_REF" --use-api

echo
echo "Running the job once:"
supabase db query --linked --project-ref "$PROJECT_REF" \
  "select nata.run_payment_jobs() as result"
