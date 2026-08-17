#!/usr/bin/env bash
# Create the Process Affiliate webhook in RevenueCat via API v2.
#
# Requires a RevenueCat **API v2** secret key (NOT the legacy sk_ v1 key):
#   export REVENUECAT_V2_SECRET_API_KEY='rcapi_…'
#
# Dashboard: RevenueCat → Process → API keys → + New → V2
#
set -euo pipefail

PROJECT_ID="${REVENUECAT_PROJECT_ID:-ab4f477a}"
WEBHOOK_URL="${AFFILIATE_WEBHOOK_URL:-https://us-central1-useprocess-d4385.cloudfunctions.net/affiliateRevenueCatWebhook}"

if [[ -z "${REVENUECAT_V2_SECRET_API_KEY:-}" ]]; then
  echo "ERROR: set REVENUECAT_V2_SECRET_API_KEY (v2 key, not legacy sk_)."
  exit 1
fi

if [[ -z "${REVENUECAT_WEBHOOK_SECRET:-}" ]]; then
  if [[ -f "$(dirname "$0")/../.referral-webhook-secret.local" ]]; then
    REVENUECAT_WEBHOOK_SECRET="$(grep WEBHOOK_SECRET= "$(dirname "$0")/../.referral-webhook-secret.local" | cut -d= -f2-)"
  fi
fi

if [[ -z "${REVENUECAT_WEBHOOK_SECRET:-}" ]]; then
  echo "ERROR: set REVENUECAT_WEBHOOK_SECRET or keep firebase/.referral-webhook-secret.local"
  exit 1
fi

payload=$(cat <<EOF
{
  "name": "Process Affiliate",
  "url": "$WEBHOOK_URL",
  "authorization_header": "Bearer $REVENUECAT_WEBHOOK_SECRET",
  "environment": null,
  "event_types": null,
  "app_id": null
}
EOF
)

echo "==> Creating RevenueCat webhook: Process Affiliate"
curl -sS -X POST \
  "https://api.revenuecat.com/v2/projects/${PROJECT_ID}/integrations/webhooks" \
  -H "Authorization: Bearer ${REVENUECAT_V2_SECRET_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$payload" | python3 -m json.tool

echo ""
echo "Done. Verify in RC → Integrations → Webhooks."
