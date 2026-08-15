# Referral program — deployment

Rewards are **RevenueCat promotional entitlements** for the **referrer only**. No cash payouts. The invitee gets nothing.

## Reward rules

| Who | Trigger | Reward |
|-----|---------|--------|
| **Invitee** (friend) | — | **None** |
| **Referrer** (weekly / monthly) | Friend's **paid** Apple subscription | **+1 month** (`monthly`) |
| **Referrer** (annual) | Friend's **paid** Apple subscription | **+1 year** (`yearly`) |

A trial, promotional grant, or unpaid signup never credits the referrer.

## One-command deploy

```bash
export REVENUECAT_SECRET_API_KEY='sk_…'   # RevenueCat → Project → API keys → Secret
./firebase/scripts/deploy-referral.sh
```

The script builds functions, deploys Firestore rules, sets Firebase secrets, and deploys all 4 referral Cloud Functions.

## Firebase secrets

```bash
firebase functions:secrets:set REVENUECAT_SECRET_API_KEY
firebase functions:secrets:set REVENUECAT_WEBHOOK_SECRET
```

- **REVENUECAT_SECRET_API_KEY** — RevenueCat → Project → API keys → **Secret** key (`sk_…`)
- **REVENUECAT_WEBHOOK_SECRET** — already generated; value in `firebase/.referral-webhook-secret.local`

## RevenueCat webhook

Already live on project Process (`ab4f477a`): integration **Process Referral** (`whintgrb008218f37`).

- URL: `https://us-central1-useprocess-d4385.cloudfunctions.net/referralRevenueCatWebhook`
- Authorization header: `Bearer <REVENUECAT_WEBHOOK_SECRET>` (same value as Firebase secret / `firebase/.referral-webhook-secret.local`)
- Environment: production + sandbox
- Events: all (the function only grants on paid `INITIAL_PURCHASE`, `NON_RENEWING_PURCHASE`, or trial-conversion `RENEWAL`)
- Verified: deliveries return HTTP 200 (auth OK). Non-referred buyers get `{"ok":true,"skipped":"NOT_REFERRED"}`.

## Cloud Functions

| Function | Role |
|----------|------|
| `referralSyncProgram` | Referrer publishes their code |
| `referralRegister` | Invitee is attributed (pending, no reward) |
| `referralConfirmSubscription` | Client retry after a paid purchase |
| `referralRevenueCatWebhook` | Server-side grant on paid purchase |

## Firestore

- `referralCodes/{code}` — maps code → referrer `userId` (server write only)
- `users/{uid}/referralInvites/{inviteeUid}` — referrer dashboard
- `users/{uid}/referralMeta/referredBy` — invitee attribution
- `users/{uid}/referralMeta/program` — referrer stats

## iOS flow

1. Referrer opens **Parrainage** → `referralSyncProgram`
2. Friend installs via `join.useprocess.xyz/CODE` or `useprocess.xyz/join/CODE`
3. On onboarding complete → `referralRegister` (retries on next sign-in if offline)
4. Friend **pays** → webhook + `referralConfirmSubscription`
5. RevenueCat grants promotional time to the **referrer Firebase UID only**

Ensure `Purchases.shared.logIn(firebaseUID)` stays enabled (already in `SubscriptionService`).
