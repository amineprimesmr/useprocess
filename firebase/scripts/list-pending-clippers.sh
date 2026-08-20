#!/usr/bin/env bash
# List pending clipper applications awaiting manual approval.
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SECRET_FILE="$ROOT/.affiliate-admin-secret.local"

if [[ -z "${AFFILIATE_ADMIN_SECRET:-}" && -f "$SECRET_FILE" ]]; then
  AFFILIATE_ADMIN_SECRET="$(grep AFFILIATE_ADMIN_SECRET= "$SECRET_FILE" | cut -d= -f2-)"
fi

if [[ -z "${AFFILIATE_ADMIN_SECRET:-}" ]]; then
  AFFILIATE_ADMIN_SECRET="$(firebase functions:secrets:access AFFILIATE_ADMIN_SECRET --project useprocess-d4385 2>/dev/null || true)"
fi

if [[ -z "${AFFILIATE_ADMIN_SECRET:-}" ]]; then
  echo "ERROR: AFFILIATE_ADMIN_SECRET not found"
  exit 1
fi

response="$(curl -sS -X POST \
  "https://us-central1-useprocess-d4385.cloudfunctions.net/affiliateAdminListPending" \
  -H "Content-Type: application/json" \
  -H "X-Affiliate-Admin-Secret: ${AFFILIATE_ADMIN_SECRET}" \
  -d '{}')"

echo "$response" | python3 -m json.tool

echo ""
echo "Approve: ./firebase/scripts/approve-clipper.sh <affiliateId>"
