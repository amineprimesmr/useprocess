# Referral program — deployment

Rewards are **40 % cash commission for life** on every paid subscription from referred friends (initial purchase + renewals). No free months. The invitee gets nothing.

## Reward rules

| Who | Trigger | Reward |
|-----|---------|--------|
| **Invitee** (friend) | — | **None** |
| **Referrer** (any user) | Friend's **paid** Apple subscription | **40 % of net** (after ~30 % store fee) |
| **Referrer** | Friend **renews** | **40 % again** — lifetime on active subs |
| **Lifetime SKU** | Friend buys lifetime | **Excluded** (no commission) |

Commissions enter a **30-day hold**, then become **payable**. Payouts are processed manually (same pipeline as affiliate clippers).

## One-command deploy

```bash
export REVENUECAT_SECRET_API_KEY='sk_…'   # optional — webhook-only flow
./firebase/scripts/deploy-referral.sh
```

## Firebase secrets

```bash
firebase functions:secrets:set REVENUECAT_WEBHOOK_SECRET
```

- **REVENUECAT_WEBHOOK_SECRET** — Bearer token for RevenueCat webhook auth

## RevenueCat webhook

URL: `https://us-central1-useprocess-d4385.cloudfunctions.net/referralRevenueCatWebhook`

- Authorization: `Bearer <REVENUECAT_WEBHOOK_SECRET>`
- Events: `INITIAL_PURCHASE`, `RENEWAL` (paid), `REFUND`, `CANCELLATION`, `EXPIRATION`

## Cloud Functions

| Function | Role |
|----------|------|
| `referralSyncProgram` | Referrer publishes their code |
| `referralRegister` | Invitee is attributed (pending) |
| `referralConfirmSubscription` | Legacy client retry — no-op (webhook primary) |
| `referralRevenueCatWebhook` | Accrues 40 % commission on paid events |
| `referralDashboard` | Referrer stats + recent commissions |

## Firestore

- `referralCodes/{code}` — code → referrer `userId`
- `referralCommissions/{id}` — ledger (40 % net, hold, payable)
- `users/{uid}/referralInvites/{inviteeUid}` — referrer dashboard list
- `users/{uid}/referralMeta/referredBy` — invitee attribution
- `users/{uid}/referralMeta/program` — referrer stats (`stats.pendingCents`, etc.)

## iOS flow

1. Referrer opens **Programme créateurs** → `referralSyncProgram`
2. Friend installs via `join.useprocess.xyz/CODE`
3. On onboarding → `referralRegister`
4. Friend **pays** → webhook accrues commission to referrer
5. Referrer opens dashboard → `referralDashboard`

Ensure `Purchases.shared.logIn(firebaseUID)` stays enabled.
