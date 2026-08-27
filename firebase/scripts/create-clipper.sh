#!/usr/bin/env bash
# Create or provision a clipper code.
#
# Usage:
#   ./firebase/scripts/create-clipper.sh MANNY "Manny"
#   ./firebase/scripts/create-clipper.sh MANNY "Manny" manny@example.com
#   ./firebase/scripts/create-clipper.sh --auth MANNY manny@example.com
#
set -euo pipefail

AUTH_ONLY=0
if [[ "${1:-}" == "--auth" ]]; then
  AUTH_ONLY=1
  shift
fi

CODE="${1:-}"
DISPLAY="${2:-}"
EMAIL="${3:-}"

if [[ "$AUTH_ONLY" -eq 1 ]]; then
  EMAIL="${2:-}"
  if [[ -z "$CODE" || -z "$EMAIL" ]]; then
    echo "Usage: $0 --auth CODE email@example.com"
    exit 1
  fi
elif [[ -z "$CODE" || -z "$DISPLAY" ]]; then
  echo "Usage: $0 CODE \"Display Name\" [email]"
  echo "       $0 --auth CODE email@example.com"
  exit 1
fi

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

PASSWORD="${CLIPPER_PASSWORD:-$(openssl rand -base64 18 | tr -dc 'A-Za-z0-9' | head -c 14)}"

if [[ "$AUTH_ONLY" -eq 1 ]]; then
  payload="{\"affiliateId\":\"$CODE\",\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}"
  endpoint="affiliateAdminProvisionAuth"
else
  payload="{\"code\":\"$CODE\",\"displayName\":\"$DISPLAY\""
  if [[ -n "$EMAIL" ]]; then
    payload+=",\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\""
  fi
  payload+="}"
  endpoint="affiliateAdminCreate"
fi

response="$(curl -sS -X POST \
  "https://us-central1-useprocess-d4385.cloudfunctions.net/${endpoint}" \
  -H "Content-Type: application/json" \
  -H "X-Affiliate-Admin-Secret: ${AFFILIATE_ADMIN_SECRET}" \
  -d "$payload")"

echo "$response" | python3 -m json.tool

if [[ -n "$EMAIL" ]]; then
  echo ""
  echo "Portal: https://useprocess.xyz/clipping"
  echo "Email:  $EMAIL"
  echo "Pass:   $PASSWORD"
fi

echo ""
echo "Link: https://useprocess.xyz/join/$(echo "$CODE" | tr '[:lower:]' '[:upper:]')"
echo "Short (after DNS): https://join.useprocess.xyz/$(echo "$CODE" | tr '[:lower:]' '[:upper:]')"
