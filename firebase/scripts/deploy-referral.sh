#!/usr/bin/env bash
# Deploy referral Cloud Functions + Firestore rules for Process.
#
# Required for reward functions:
#   export REVENUECAT_SECRET_API_KEY='sk_…'   # RevenueCat → Project → API keys → Secret
#
# Optional (generated if unset):
#   export REVENUECAT_WEBHOOK_SECRET='…'        # Same value in RevenueCat webhook Authorization
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

echo "==> Building Cloud Functions"
npm --prefix firebase/functions run build

echo "==> Deploying Firestore rules"
firebase deploy --only firestore:rules

if [[ -z "${REVENUECAT_SECRET_API_KEY:-}" ]]; then
  echo ""
  echo "WARN: REVENUECAT_SECRET_API_KEY is not set."
  echo "      Deploying registration functions only (no RevenueCat rewards yet)."
  echo ""
  firebase deploy --only functions:referralSyncProgram,functions:referralRegister
  echo ""
  echo "Next: export REVENUECAT_SECRET_API_KEY='sk_…' and re-run this script to deploy reward functions."
  exit 0
fi

if [[ -z "${REVENUECAT_WEBHOOK_SECRET:-}" ]]; then
  REVENUECAT_WEBHOOK_SECRET="$(openssl rand -hex 32)"
  echo "Generated REVENUECAT_WEBHOOK_SECRET (save for RevenueCat dashboard):"
  echo "  $REVENUECAT_WEBHOOK_SECRET"
fi

echo "==> Setting Firebase secrets"
printf '%s' "$REVENUECAT_SECRET_API_KEY" | firebase functions:secrets:set REVENUECAT_SECRET_API_KEY --data-file=-
printf '%s' "$REVENUECAT_WEBHOOK_SECRET" | firebase functions:secrets:set REVENUECAT_WEBHOOK_SECRET --data-file=-

echo "==> Deploying all referral functions"
firebase deploy --only functions:referralSyncProgram,functions:referralRegister,functions:referralConfirmSubscription,functions:referralRevenueCatWebhook

echo ""
echo "==> Done"
echo "RevenueCat webhook URL:"
echo "  https://us-central1-useprocess-d4385.cloudfunctions.net/referralRevenueCatWebhook"
echo "Authorization header:"
echo "  Bearer $REVENUECAT_WEBHOOK_SECRET"
echo ""
echo "Enable events: INITIAL_PURCHASE, NON_RENEWING_PURCHASE, RENEWAL"
