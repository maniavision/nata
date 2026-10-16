#!/usr/bin/env bash
# Sets up AWS Rekognition for the face checks and deploys the functions that
# use it:
#   * verify-identity    (selfie vs ID photo: rekognition:CompareFaces)
#   * traveler-id-photo  (face crop shown at checkout: rekognition:DetectFaces)
#
# Creates an IAM user allowed only those two actions, creates its access key
# and stores it straight in the Supabase project's secrets. The key is never
# printed or saved anywhere else.
#
# Needs: the AWS CLI signed in as an account admin (aws configure, or
# aws sso login) and the Supabase CLI signed in (supabase login).
#
#   bash scripts/setup_face_match.sh
#
# Optional: AWS_REGION (default us-east-1), PROJECT_REF,
# FACE_MATCH_THRESHOLD (default 90), FACE_MATCH_MAX_ATTEMPTS (default 3).
set -euo pipefail

PROJECT_REF="${PROJECT_REF:-xnzredskhxfgywggetzw}"
REGION="${AWS_REGION:-us-east-1}"
USER_NAME="nata-face-match"
POLICY_NAME="nata-rekognition-faces"

for cli in aws supabase; do
  if ! command -v "$cli" >/dev/null; then
    echo "The $cli CLI is missing. Install it with: brew install $([ "$cli" = aws ] && echo awscli || echo supabase/tap/supabase)" >&2
    exit 1
  fi
done
if ! aws sts get-caller-identity >/dev/null 2>&1; then
  echo "Sign in to AWS first: aws configure (or aws sso login)." >&2
  exit 1
fi
# Checked before any key is created, so a key is never made and then lost.
if ! supabase secrets list --project-ref "$PROJECT_REF" >/dev/null 2>&1; then
  echo "Sign in to Supabase first: supabase login" >&2
  exit 1
fi

# Deploying needs the project's supabase/ folder.
cd "$(dirname "$0")/.."

echo "1/4 IAM user $USER_NAME"
if ! aws iam get-user --user-name "$USER_NAME" >/dev/null 2>&1; then
  aws iam create-user --user-name "$USER_NAME" >/dev/null
fi
aws iam put-user-policy \
  --user-name "$USER_NAME" \
  --policy-name "$POLICY_NAME" \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": ["rekognition:CompareFaces", "rekognition:DetectFaces"],
      "Resource": "*"
    }]
  }'

echo "2/4 Access key"
keys=$(aws iam list-access-keys --user-name "$USER_NAME" \
  --query 'length(AccessKeyMetadata)' --output text)
if [ "$keys" -ge 2 ]; then
  echo "$USER_NAME already has 2 access keys (the AWS limit). Delete an unused one in IAM, then run this again." >&2
  exit 1
fi

# The new key goes to a private temp file, then straight to Supabase.
env_file=$(mktemp)
chmod 600 "$env_file"
trap 'rm -f "$env_file"' EXIT
aws iam create-access-key --user-name "$USER_NAME" \
  --query 'AccessKey.[AccessKeyId,SecretAccessKey]' --output text |
  awk -v region="$REGION" \
    -v threshold="${FACE_MATCH_THRESHOLD:-90}" \
    -v attempts="${FACE_MATCH_MAX_ATTEMPTS:-3}" \
    '{ print "AWS_ACCESS_KEY_ID=" $1
       print "AWS_SECRET_ACCESS_KEY=" $2
       print "AWS_REGION=" region
       print "FACE_MATCH_THRESHOLD=" threshold
       print "FACE_MATCH_MAX_ATTEMPTS=" attempts }' >"$env_file"

echo "3/4 Supabase secrets"
supabase secrets set --project-ref "$PROJECT_REF" --env-file "$env_file" >/dev/null

echo "4/4 Deploying functions"
supabase functions deploy verify-identity --project-ref "$PROJECT_REF"
supabase functions deploy traveler-id-photo --project-ref "$PROJECT_REF"

echo "Done. Face match and the traveler ID photo are set up."
