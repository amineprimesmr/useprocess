# Abonnements Process AI — RevenueCat + App Store Connect

Deux offres :
- **Mensuel** : `com.useprocess.monthly` — **5,99 € / mois**
- **Annuel** : `com.useprocess.annual` — **29,99 € / an**

Entitlement RevenueCat : **`premium`**

---

## 1. App Store Connect

1. [App Store Connect](https://appstoreconnect.apple.com) → **Apps** → **Process AI** (`com.useprocess`)
2. **Abonnements** → créer un groupe **Process AI Premium**
3. Ajouter deux abonnements auto-renouvelables :

| Référence | Product ID | Durée | Prix (France) |
|-----------|------------|-------|---------------|
| Premium Monthly | `com.useprocess.monthly` | 1 mois | 5,99 € |
| Premium Yearly | `com.useprocess.annual` | 1 an | 29,99 € |

4. Renseigner nom, description et capture d’écran de review si demandé
5. Soumettre les produits pour review (statut **Ready to Submit**)

---

## 2. RevenueCat (projet `com.useprocess`)

1. [RevenueCat](https://app.revenuecat.com) → projet **com.useprocess**
2. **Apps** → lier l’app iOS `com.useprocess` (clé App Store Connect / clé API IAP)
3. **Product catalog** → **Products** → importer les 2 Product IDs ci-dessus
4. **Entitlements** → créer **`premium`**
5. Attacher les 2 produits à l’entitlement `premium`
6. **Offerings** → offering **`Premium`** (Current)
   - Package **Monthly** → `com.useprocess.monthly`
   - Package **Annual** → `com.useprocess.annual`
7. **API keys** → copier la clé publique iOS (`appl_…`)

---

## 3. App iOS (déjà intégré dans le code)

1. Copier le fichier exemple :
   ```bash
   cp useprocess/Subscriptions/RevenueCatSecrets.plist.example useprocess/Subscriptions/RevenueCatSecrets.plist
   ```
2. Coller ta clé `appl_…` dans `REVENUECAT_API_KEY`
3. **Ne pas committer** `RevenueCatSecrets.plist` (secrets locaux)

### Tests locaux (StoreKit)

1. Xcode → **Product** → **Scheme** → **Edit Scheme** → **Run** → **Options**
2. **StoreKit Configuration** → `SubscriptionProducts.storekit`
3. Lancer sur simulateur : achats sandbox sans App Store Connect live

---

## 4. Vérification

- Paywall onboarding : toggle **Mensuel / Annuel**
- Prix dynamiques depuis StoreKit / RevenueCat
- **Restaurer les achats** via le menu paywall
- Entitlement actif = accès premium (`SubscriptionService.subscriptionStatus.isActive`)

---

## Identifiants (référence code)

```swift
SubscriptionConfiguration.entitlementID      // "premium"
SubscriptionConfiguration.defaultOfferingID    // "Premium"
SubscriptionConfiguration.monthlyProductID     // com.useprocess.monthly
SubscriptionConfiguration.annualProductID      // com.useprocess.annual
```
