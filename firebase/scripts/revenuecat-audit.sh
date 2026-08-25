#!/usr/bin/env bash
# Audit RevenueCat + valeurs copy-paste pour Process.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PROJECT_ID="ab4f477a"
APP_RC_ID="app1dab14dae3"
ASC_APP_ID="6753808143"
BUNDLE="com.useprocess"
PUBLIC_KEY="appl_vDFQcBzxZNabxkSAwSqFNYHptbw"
WEBHOOK_URL="https://us-central1-useprocess-d4385.cloudfunctions.net/referralRevenueCatWebhook"

echo "=== Process — RevenueCat audit ==="
echo ""
echo "Liens directs (connecté au dashboard RC)"
echo "  App iOS (endpoint Retention) : https://app.revenuecat.com/projects/${PROJECT_ID}/apps/${APP_RC_ID}"
echo "  Lifecycle → Retention        : https://app.revenuecat.com/projects/${PROJECT_ID}/lifecycle/retention"
echo "  Product catalog              : https://app.revenuecat.com/projects/${PROJECT_ID}/product-catalog"
echo "  Integrations → Webhooks      : https://app.revenuecat.com/projects/${PROJECT_ID}/integrations/webhooks"
echo "  Overview                     : https://app.revenuecat.com/projects/${PROJECT_ID}"
echo ""

echo "Identifiants"
echo "  Bundle ID     : ${BUNDLE}"
echo "  Apple ID ASC  : ${ASC_APP_ID}"
echo "  RC project    : proj${PROJECT_ID}"
echo "  RC app id     : ${APP_RC_ID}"
echo "  Public key    : ${PUBLIC_KEY}"
echo ""

echo "Formulaire Apple Retention Messaging"
echo "  App Name      : Process : Debloat ton visage"
echo "  Apple ID      : ${ASC_APP_ID}"
echo "  Endpoint URL  : copier depuis la page App iOS ci-dessus (section Retention Messaging Endpoint)"
echo "  ☑ My app currently has a subscription on the App Store"
echo ""

echo "Webhook parrainage (Integrations → Webhooks → Add)"
echo "  URL           : ${WEBHOOK_URL}"
if [[ -f "$ROOT/firebase/.referral-webhook-secret.local" ]]; then
  SECRET="$(grep '^WEBHOOK_SECRET=' "$ROOT/firebase/.referral-webhook-secret.local" | cut -d= -f2-)"
  echo "  Authorization : Bearer ${SECRET:0:12}…"
else
  echo "  Authorization : Bearer <voir firebase/.referral-webhook-secret.local>"
fi
echo "  Events        : INITIAL_PURCHASE, RENEWAL, CANCELLATION, EXPIRATION, REFUND"
echo ""

echo "App (code)"
if grep -q "bundledIOSPublicAPIKey = \"${PUBLIC_KEY}\"" "$ROOT/useprocess/Subscriptions/RevenueCatConfiguration.swift"; then
  echo "  [OK] Clé publique iOS embarquée dans RevenueCatConfiguration.swift"
else
  echo "  [!!] Clé publique iOS manquante ou différente dans le repo"
fi
echo ""

echo "API secret (Firebase)"
if command -v firebase >/dev/null 2>&1; then
  SK="$(firebase functions:secrets:access REVENUECAT_SECRET_API_KEY --project useprocess-d4385 2>/dev/null || true)"
  if [[ "$SK" == sk_* ]]; then
    echo "  [OK] REVENUECAT_SECRET_API_KEY présent (v1 legacy sk_…)"
    python3 - <<PY
import json, urllib.request
token = """$SK"""
req = urllib.request.Request(
    "https://api.revenuecat.com/v1/subscribers/process_audit_probe",
    headers={"Authorization": f"Bearer {token}"},
)
with urllib.request.urlopen(req, timeout=20) as r:
    print(f"  [OK] API v1 reachable HTTP {r.status}")
PY
  else
    echo "  [!!] Secret RC introuvable dans Firebase"
  fi
else
  echo "  [--] firebase CLI absent"
fi
echo ""

echo "Pourquoi « Paywalls » est vide"
echo "  Process utilise un paywall Swift natif, pas le builder RevenueCat Paywalls."
echo "  Stats paywall → PostHog (paywall_viewed, purchase_completed), pas RC Paywalls."
echo ""

echo "Pourquoi Overview RC peut être à 0"
echo "  1. Apps → Process (App Store) → lier App Store Connect (In-App Purchase Key .p8)"
echo "  2. Integrations → Webhooks → ajouter le webhook parrainage ci-dessus"
echo "  3. Nouveau build TestFlight/App Store après toute modif clé SDK"
echo "  4. Overview : Sandbox data ON pour TestFlight, OFF pour prod App Store"
echo ""

echo "Retention Messaging — où est l’URL ?"
echo "  PAS dans Project settings général."
echo "  Ouvrir l’app iOS (lien App iOS ci-dessus) → scroller → Retention Messaging Endpoint."
echo "  Ou Lifecycle → Retention → panneau Apple Retention Messaging API."
echo ""

echo "Docs: $ROOT/firebase/RETENTION_MESSAGING.md"
echo "      $ROOT/docs/REVENUECAT_SETUP.md"
