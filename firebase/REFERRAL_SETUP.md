# Referral program — deployment

Rewards are **100% Apple / RevenueCat** (promotional subscription time). No cash payouts.

## Reward rules

| Who | Trigger | Reward |
|-----|---------|--------|
| **Invitee** (friend) | First Apple subscription after signup with code | **+7 days** (`weekly` promotional entitlement) |
| **Referrer** (weekly/monthly plan) | Friend's first subscription | **+2 weeks** (`two_week`) |
| **Referrer** (annual plan) | Friend's first subscription | **+1 month** (`monthly`) |

## One-command deploy

```bash
export REVENUECAT_SECRET_API_KEY='sk_…'   # RevenueCat → Project → API keys → Secret
./firebase/scripts/deploy-referral.sh
```

The script builds functions, deploys Firestore rules, sets Firebase secrets, and deploys all 4 referral Cloud Functions.

**Already deployed (2026-08-11):**
- Firestore rules (referral collections)
- `referralSyncProgram` + `referralRegister`
- `deleteUserAccount` (cleans up `referralCodes/{code}` on delete)
- `REVENUECAT_WEBHOOK_SECRET` (stored locally in `firebase/.referral-webhook-secret.local`, gitignored)

**Still required:** set `REVENUECAT_SECRET_API_KEY`, then re-run the deploy script to publish reward functions.

## Firebase secrets

```bash
firebase functions:secrets:set REVENUECAT_SECRET_API_KEY
firebase functions:secrets:set REVENUECAT_WEBHOOK_SECRET
```

- **REVENUECAT_SECRET_API_KEY** — RevenueCat → Project → API keys → **Secret** key (`sk_…`)
- **REVENUECAT_WEBHOOK_SECRET** — already generated; value in `firebase/.referral-webhook-secret.local`

## RevenueCat webhook

1. RevenueCat dashboard → Project → **Integrations** → **Webhooks**
2. URL: `https://us-central1-useprocess-d4385.cloudfunctions.net/referralRevenueCatWebhook`
3. Authorization header: `Bearer <value from firebase/.referral-webhook-secret.local>`
4. Events: enable **INITIAL_PURCHASE** and **NON_RENEWING_PURCHASE**

## Cloud Functions

| Function | URL | Status |
|----------|-----|--------|
| `referralSyncProgram` | `https://us-central1-useprocess-d4385.cloudfunctions.net/referralSyncProgram` | Live |
| `referralRegister` | `https://us-central1-useprocess-d4385.cloudfunctions.net/referralRegister` | Live |
| `referralConfirmSubscription` | same pattern | Needs `REVENUECAT_SECRET_API_KEY` deploy |
| `referralRevenueCatWebhook` | same pattern | Needs `REVENUECAT_SECRET_API_KEY` deploy |

## Firestore

- `referralCodes/{code}` — maps code → referrer `userId` (server write only)
- `users/{uid}/referralInvites/{inviteeUid}` — referrer dashboard
- `users/{uid}/referralMeta/referredBy` — invitee attribution
- `users/{uid}/referralMeta/program` — referrer stats

## iOS flow

1. Referrer opens **Parrainage** → `referralSyncProgram`
2. Friend installs via `join.useprocess.xyz/CODE` or `useprocess.xyz/join/CODE`
3. On onboarding complete → `referralRegister` (retries on next sign-in if offline)
4. Friend purchases → `referralConfirmSubscription` + webhook
5. RevenueCat grants promotional time to both Firebase UIDs

Ensure `Purchases.shared.logIn(firebaseUID)` stays enabled (already in `SubscriptionService`).

## Website

- `/join/:code` → `/?ref=:code` (Vercel redirect)
- `join.useprocess.xyz` → SPA with referral banner
- Universal Links: `website/public/.well-known/apple-app-site-association`

Deploy website: push to main or `vercel --prod` from `website/`.
