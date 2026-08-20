# RevenueCat — Process AI (prod)

## Pourquoi le dashboard était à 0

L’archive App Store partait **sans clé** `appl_…` :
seul `RevenueCatSecrets.plist.example` était embarqué.
Sans clé → `Purchases.configure` n’est jamais appelé → achats Apple OK,
mais **RevenueCat ne voit rien**.

## Config app (fait)

La clé publique iOS est embarquée dans :

`useprocess/Subscriptions/RevenueCatConfiguration.swift` → `bundledIOSPublicAPIKey`

(+ copie locale gitignorée `RevenueCatSecrets.plist`).

**À faire après ce fix :** Archive Xcode → upload App Store / TestFlight.
Sans nouveau build, l’app déjà en prod reste sans tracking.

La clé `appl_` est **publique** (prévue pour le client). Ne jamais committer une clé `sk_`.

## Dashboard RevenueCat (projet Process)

| Élément | Valeur |
|---------|--------|
| Bundle ID | `com.useprocess` |
| Entitlement | `premium` |
| Offering (legacy) | `Premium` |
| Offering A (A/B) | `Premium_A` — weekly899 + annual3499 |
| Offering B (A/B) | `Premium_B` — monthly999 + annual4999 |
| ASC group ID | `21837790` (Process Premium) |
| Mensuel (legacy) | `com.useprocess.monthly` |
| Annuel (legacy) | `com.useprocess.annual` |
| Hebdo A | `com.useprocess.weekly899` |
| Annuel A | `com.useprocess.annual3499` |
| Mensuel B | `com.useprocess.monthly999` |
| Annuel B | `com.useprocess.annual4999` |
| Lifetime | `com.useprocess.lifetime` |
| Packages | `$rc_weekly` / `$rc_monthly` / `$rc_annual` |

Voir aussi `docs/PAYWALL_PRICING_AB_TEST.md` pour la checklist A/B complète.

**Retention Messaging (annulation abo iOS)** : [`firebase/RETENTION_MESSAGING.md`](../firebase/RETENTION_MESSAGING.md) — copy FR/EN, Apple ID `6753808143`, bouton « Gérer mon abonnement » dans l’app.

Vérifier aussi : **Apps** → app iOS liée avec credentials App Store Connect.

## Tests

- **Prod réelle** : Overview, Sandbox data **OFF**
- **TestFlight / sandbox Xcode** : Sandbox data **ON**
- Scheme Xcode avec `SubscriptionProducts.storekit` = achats locaux, pas le flux App Store

## Code

```swift
SubscriptionConfiguration.entitlementID      // "premium"
SubscriptionConfiguration.defaultOfferingID  // "Premium"
SubscriptionConfiguration.monthlyProductID   // com.useprocess.monthly
SubscriptionConfiguration.annualProductID    // com.useprocess.annual
SubscriptionConfiguration.lifetimeProductID  // com.useprocess.lifetime
```
