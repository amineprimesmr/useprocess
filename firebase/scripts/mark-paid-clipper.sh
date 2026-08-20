#!/usr/bin/env bash
# Record a Stripe Connect payout for a clipper (transfer + ledger).
#
# Usage:
#   ./firebase/scripts/mark-paid-clipper.sh AFFILIATE_ID AMOUNT_EUR [note]
#
# Example:
#   ./firebase/scripts/mark-paid-clipper.sh abc123uid 42.50 "March payout"
#
set -euo pipefail

AFFILIATE_ID="${1:-}"
AMOUNT_EUR="${2:-}"
NOTE="${3:-Manual payout}"

if [[ -z "$AFFILIATE_ID" || -z "$AMOUNT_EUR" ]]; then
  echo "Usage: $0 <affiliateId> <amountEUR> [note]"
  exit 1
fi

AMOUNT_CENTS="$(python3 - <<PY
from decimal import Decimal, ROUND_HALF_UP
amount = Decimal("${AMOUNT_EUR}".replace(",", "."))
print(int((amount * 100).quantize(Decimal("1"), rounding=ROUND_HALF_UP)))
PY
)"

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

payload="{\"affiliateId\":\"$AFFILIATE_ID\",\"amountCents\":$AMOUNT_CENTS,\"currency\":\"EUR\",\"method\":\"stripe\",\"note\":\"$NOTE\"}"

response="$(curl -sS -X POST \
  "https://us-central1-useprocess-d4385.cloudfunctions.net/affiliateAdminMarkPaid" \
  -H "Content-Type: application/json" \
  -H "X-Affiliate-Admin-Secret: ${AFFILIATE_ADMIN_SECRET}" \
  -d "$payload")"

echo "$response" | python3 -m json.tool
