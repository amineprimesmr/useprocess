# Affiliate program — deployment

Cash commissions for **approved clippers** (TikTok / UGC). Separate from the user referral program (RevenueCat promo time only).

## Commission rules

| Rule | Value |
|------|-------|
| Rate | **40%** of net revenue Process receives |
| Net estimate | `price × 0.70` (after ~30% Apple cut) — tune with `AFFILIATE_NET_FACTOR` |
| Trigger | Paid `INITIAL_PURCHASE` + paid `RENEWAL` |
| Hold | **30 days** before payable (refund window) |
| Stop | `CANCELLATION` / `EXPIRATION` → no future renewals |
| Clawback | `REFUND` → pending/payable commissions reversed |
| Lifetime SKU | **Excluded** (`com.useprocess.lifetime`) |

## One-command deploy

```bash
export REVENUECAT_WEBHOOK_SECRET='…'   # same Bearer token as referral webhook
export AFFILIATE_ADMIN_SECRET='…'      # admin create / approve / mark paid
./firebase/scripts/deploy-affiliate.sh
```

## RevenueCat webhook (second integration)

Add a **second** webhook in RevenueCat → Integrations:

- Name: `Process Affiliate`
- URL: `https://us-central1-useprocess-d4385.cloudfunctions.net/affiliateRevenueCatWebhook`
- Authorization: `Bearer <REVENUECAT_WEBHOOK_SECRET>`
- Environment: production + sandbox
- Events: all (function filters to purchase / renewal / refund / churn)

## Cloud Functions

| Function | Role |
|----------|------|
| `affiliateResolveCode` | Resolve affiliate vs user referral code |
| `affiliateRegister` | Attribute invitee to clipper |
| `affiliateApply` | Clipper self-serve application (pending approval) |
| `affiliateSyncProfile` | Clipper payout info (PayPal) |
| `affiliateDashboard` | Clipper stats + commissions |
| `affiliateAdminCreate` | Admin: create vanity code (+ optional email/password auth) |
| `affiliateAdminProvisionAuth` | Admin: link Firebase login to existing clipper |
| `affiliateAdminApprove` | Admin: activate pending clipper |
| `affiliateAdminMarkPaid` | Admin: record manual payout |
| `affiliateRevenueCatWebhook` | Accrue / clawback commissions |
| `affiliateReleaseHeldCommissions` | Cron/manual: move hold → payable |

Admin endpoints require header `X-Affiliate-Admin-Secret: <AFFILIATE_ADMIN_SECRET>`.

## Firestore

- `affiliateCodes/{code}` — vanity code → affiliateId
- `affiliates/{affiliateId}` — clipper profile + stats
- `affiliates/{id}/attributions/{uid}` — referred users
- `users/{uid}/affiliateMeta/referredBy` — invitee attribution
- `affiliateCommissions/{id}` — ledger (pending_hold → payable → paid)
- `affiliatePayouts/{id}` — manual payout records

## Create a clipper

```bash
# New clipper + Firebase login (password printed in terminal)
./firebase/scripts/create-clipper.sh TOJI "Toji" toji@example.com

# Web login for an existing code
./firebase/scripts/create-clipper.sh --auth MANNY manny@example.com
```

Portal: **https://useprocess.xyz/affiliate**

Manual curl:

```bash
curl -X POST https://us-central1-useprocess-d4385.cloudfunctions.net/affiliateAdminCreate \
  -H 'Content-Type: application/json' \
  -H "X-Affiliate-Admin-Secret: $AFFILIATE_ADMIN_SECRET" \
  -d '{"code":"MANNY","displayName":"Manny","email":"manny@example.com","password":"choose-a-strong-password"}'
```

Optional: link an existing Firebase UID instead of email/password:

```bash
curl -X POST …/affiliateAdminCreate \
  -d '{"code":"MANNY","displayName":"Manny","uid":"<firebase_uid>"}'
```

## Mark payout (manual PayPal / virement)

```bash
curl -X POST https://us-central1-useprocess-d4385.cloudfunctions.net/affiliateAdminMarkPaid \
  -H 'Content-Type: application/json' \
  -H "X-Affiliate-Admin-Secret: $AFFILIATE_ADMIN_SECRET" \
  -d '{"affiliateId":"MANNY","amountCents":4200,"currency":"EUR","method":"paypal","note":"March payout"}'
```

## Links

Short links need a DNS record on your domain provider (Hostinger):

| Type | Name | Value |
|------|------|-------|
| **A** | `join` | `76.76.21.21` |

Until that propagates, use the path link (works today):

- `https://useprocess.xyz/join/MANNY`
- `https://join.useprocess.xyz/MANNY` (after DNS above)

Resolution order: **affiliate code first**, then user referral code.

## iOS

1. Optional onboarding step — creator / referral code
2. `affiliateRegister` if affiliate, else `referralRegister`
3. RevenueCat attribute `affiliate_code` synced via `ProcessAcquisitionAttribution`

## Website portal

Route: `https://useprocess.xyz/affiliate`

Set Vercel env vars from Firebase console → Project settings → Your apps → Web app:

- `VITE_FIREBASE_API_KEY`
- `VITE_FIREBASE_APP_ID`
- `VITE_FIREBASE_AUTH_DOMAIN` (optional, defaults to `useprocess-d4385.firebaseapp.com`)
- `VITE_FUNCTIONS_BASE_URL` (optional, defaults to Cloud Functions URL)

Clippers sign in with Firebase Auth (email/password accounts you create or they register via app).

## Firestore indexes

Deploy composite indexes required by dashboard queries:

```bash
firebase deploy --only firestore:indexes
```

Included in `./firebase/scripts/deploy-affiliate.sh`.

## Environment variables (optional)

| Variable | Default | Purpose |
|----------|---------|---------|
| `AFFILIATE_COMMISSION_RATE` | `0.40` | Commission rate |
| `AFFILIATE_HOLD_DAYS` | `30` | Hold before payable |
| `AFFILIATE_NET_FACTOR` | `0.70` | Store net estimate |
| `AFFILIATE_ADMIN_SECRET` | — | Admin API auth |
