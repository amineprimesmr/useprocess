#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PROJECT="${FIREBASE_PROJECT:-useprocess-d4385}"
REGION="${GCP_REGION:-us-central1}"
SERVICE="affiliatesendloginemail"

echo "=== Process clipper login email (contact@useprocess.xyz) ==="
echo ""

if [[ -z "${PROCESS_SMTP_PASSWORD:-}" ]]; then
  echo "Définis le mot de passe SMTP de contact@useprocess.xyz :"
  echo "  export PROCESS_SMTP_PASSWORD='…'"
  echo ""
  echo "Hostinger → Emails → contact@useprocess.xyz → Configuration email"
  exit 1
fi

echo "→ Store PROCESS_SMTP_PASSWORD in Secret Manager"
if gcloud secrets describe PROCESS_SMTP_PASSWORD --project "$PROJECT" >/dev/null 2>&1; then
  printf '%s' "$PROCESS_SMTP_PASSWORD" | gcloud secrets versions add PROCESS_SMTP_PASSWORD \
    --project "$PROJECT" --data-file=-
else
  printf '%s' "$PROCESS_SMTP_PASSWORD" | gcloud secrets create PROCESS_SMTP_PASSWORD \
    --project "$PROJECT" --replication-policy=automatic --data-file=-
fi

echo "→ Deploy affiliateSendLoginEmail (binds secret)"
cd "$ROOT/firebase/functions"
npm run build
firebase deploy --only functions:affiliateSendLoginEmail --project "$PROJECT"

echo ""
echo "✓ SMTP configuré. Test:"
echo "  https://useprocess.xyz/clipping → Connexion → Recevoir le lien"
echo "  From attendu: Process <contact@useprocess.xyz>"
