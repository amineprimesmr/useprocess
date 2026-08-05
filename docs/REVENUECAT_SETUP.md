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
| Offering (Current) | `Premium` |
| Mensuel | `com.useprocess.monthly` |
| Annuel | `com.useprocess.annual` |
| Lifetime | `com.useprocess.lifetime` |
| Packages | `$rc_monthly` / `$rc_annual` |

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
