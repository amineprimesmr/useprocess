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

## RevenueCat webhook

**Un seul webhook RC suffit** — `referralRevenueCatWebhook` traite aussi les commissions clipper (affiliate).

Add in RevenueCat → Integrations (if not already present):

- Name: `Process Referral + Affiliate` (or keep existing referral webhook)
- URL: `https://us-central1-useprocess-d4385.cloudfunctions.net/referralRevenueCatWebhook`
- Authorization: `Bearer <REVENUECAT_WEBHOOK_SECRET>`
- Environment: production + sandbox
- Events: all (function filters to purchase / renewal / refund / churn)

Optional duplicate endpoint (same secret, same handler logic split): `affiliateRevenueCatWebhook` — **not required** if referral webhook is configured.

## Cloud Functions

| Function | Role |
|----------|------|
| `affiliateResolveCode` | Resolve affiliate vs user referral code |
| `affiliateRegister` | Attribute invitee to clipper |
| `affiliateApply` | Clipper self-serve application (pending approval) |
| `affiliateSyncProfile` | Clipper profile (display name) |
| `affiliateDashboard` | Clipper stats + commissions |
| `affiliateStripeConnectStart` | Stripe Express onboarding link |
| `affiliateStripeConnectSync` | Refresh Stripe account status |
| `affiliateStripeConnectDashboard` | Stripe Express dashboard login link |
| `affiliateStripeWebhook` | Stripe Connect `account.updated` webhook |
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

## Self-serve apply (iOS + web)

Users apply in-app (**Paramètres → Programme créateur**) or on **https://useprocess.xyz/affiliate** (email/password login).

- `affiliateApply` creates `affiliates/{uid}` with `status: pending`
- Codes stay **inactive** until you approve
- User should message support (Crisp in-app or `support@useprocess.xyz`) with TikTok profile

### Admin workflow (manual validation)

```bash
# 1. See pending applications
./firebase/scripts/list-pending-clippers.sh

# 2. Approve (activates codes — clipper can earn 40%)
./firebase/scripts/approve-clipper.sh <affiliateId>

# 3. Clipper connects Stripe on https://useprocess.xyz/affiliate → Payouts
# 4. After hold period, mark paid in ledger (or automate later via Stripe Transfer)
./firebase/scripts/mark-paid-clipper.sh <affiliateId> 42.50 "March payout"
```

`affiliateId` for self-serve apply = the user's **Firebase UID** (not the vanity code).

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

## Stripe Connect payouts

Clippers connect a **bank account via Stripe Express** on the web portal (`Payouts` → **Connect payout method**). Process never collects PayPal.

### One-time setup (admin)

1. Enable **Connect** in [Stripe Dashboard](https://dashboard.stripe.com/settings/connect) (Express accounts).
2. Set Firebase secrets and deploy:

```bash
export STRIPE_SECRET_KEY='sk_live_…'          # or sk_test_ for sandbox
export STRIPE_CONNECT_WEBHOOK_SECRET='whsec_…' # from Stripe webhook endpoint
export REVENUECAT_WEBHOOK_SECRET='…'
export AFFILIATE_ADMIN_SECRET='…'
./firebase/scripts/deploy-affiliate.sh
```

3. In Stripe → Developers → Webhooks, add endpoint:
   - URL: `https://us-central1-useprocess-d4385.cloudfunctions.net/affiliateStripeWebhook`
   - Events: `account.updated`

### Clipper flow

1. Log in at **https://useprocess.xyz/affiliate**
2. Sidebar **Payouts** widget or **Payouts** page → **Connect payout method**
3. Confirm bank requirements → redirect to Stripe onboarding
4. Return URL: `https://useprocess.xyz/affiliate#/payouts?stripe=return`
5. **Manage Stripe** opens the Stripe Express dashboard for balance / tax forms

Commission ledger (`affiliateCommissions`) is unchanged. Recording a payout in Firestore (`affiliateAdminMarkPaid`) uses `method: "stripe"` by default.

## Mark payout (ledger record)

```bash
curl -X POST https://us-central1-useprocess-d4385.cloudfunctions.net/affiliateAdminMarkPaid \
  -H 'Content-Type: application/json' \
  -H "X-Affiliate-Admin-Secret: $AFFILIATE_ADMIN_SECRET" \
  -d '{"affiliateId":"MANNY","amountCents":4200,"currency":"EUR","method":"stripe","note":"March payout"}'
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

1. Onboarding step **« Avez-vous un code ? »** before paywall (`showsReferralCodeStepInOnboarding = true`)
2. Settings → **Programme créateur** — apply form, pending state, dashboard, Stripe payouts, share link
3. `affiliateRegister` if affiliate, else `referralRegister`
4. RevenueCat attribute `affiliate_code` synced via `ProcessAcquisitionAttribution`

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
