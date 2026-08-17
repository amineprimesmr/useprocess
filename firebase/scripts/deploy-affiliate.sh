#!/usr/bin/env bash
# Deploy affiliate Cloud Functions + Firestore rules for Process clippers.
#
# Required for commission webhook:
#   export REVENUECAT_WEBHOOK_SECRET='…'   # Same Bearer token as RevenueCat webhook
#
# Required for admin endpoints (create clipper, mark paid):
#   export AFFILIATE_ADMIN_SECRET='…'
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

echo "==> Building Cloud Functions"
npm --prefix firebase/functions run build

echo "==> Deploying Firestore rules"
firebase deploy --only firestore:rules

echo "==> Deploying Firestore indexes"
firebase deploy --only firestore:indexes

FUNCTIONS=(
  functions:affiliateResolveCode
  functions:affiliateRegister
  functions:affiliateApply
  functions:affiliateSyncProfile
  functions:affiliateDashboard
  functions:affiliateAdminCreate
  functions:affiliateAdminApprove
  functions:affiliateAdminMarkPaid
  functions:affiliateReleaseHeldCommissions
)

if [[ -n "${REVENUECAT_WEBHOOK_SECRET:-}" ]]; then
  printf '%s' "$REVENUECAT_WEBHOOK_SECRET" | firebase functions:secrets:set REVENUECAT_WEBHOOK_SECRET --data-file=-
  FUNCTIONS+=(functions:affiliateRevenueCatWebhook)
else
  echo ""
  echo "WARN: REVENUECAT_WEBHOOK_SECRET not set — skipping affiliateRevenueCatWebhook."
  echo "      Re-run with REVENUECAT_WEBHOOK_SECRET to deploy the commission webhook."
  echo ""
fi

if [[ -n "${AFFILIATE_ADMIN_SECRET:-}" ]]; then
  printf '%s' "$AFFILIATE_ADMIN_SECRET" | firebase functions:secrets:set AFFILIATE_ADMIN_SECRET --data-file=-
fi

echo "==> Deploying affiliate functions"
firebase deploy --only "$(IFS=,; echo "${FUNCTIONS[*]}")"

echo ""
echo "==> Done"
echo "Affiliate commission webhook URL:"
echo "  https://us-central1-useprocess-d4385.cloudfunctions.net/affiliateRevenueCatWebhook"
echo "Authorization header:"
echo "  Bearer <REVENUECAT_WEBHOOK_SECRET>"
echo ""
echo "Create a clipper code:"
echo "  curl -X POST https://us-central1-useprocess-d4385.cloudfunctions.net/affiliateAdminCreate \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -H 'X-Affiliate-Admin-Secret: <AFFILIATE_ADMIN_SECRET>' \\"
echo "    -d '{\"code\":\"MANNY\",\"displayName\":\"Manny\"}'"
