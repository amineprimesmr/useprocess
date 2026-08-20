# A/B Test tarifs paywall

## Variantes

| Variante | PostHog key | Offres |
|----------|-------------|--------|
| **A (control)** | `control` | **8,99 € / semaine** + **34,99 € / an** |
| **B (test)** | `test` | **9,99 € / mois** + **49,99 € / an** |

Flag / experiment : `paywall-pricing-ab`

---

## 1. App Store Connect (obligatoire)

Dans le groupe d’abonnements **Process Premium** (`21837790`), créer :

| Product ID | Type | Prix EUR | Période |
|------------|------|----------|---------|
| `com.useprocess.weekly899` | Auto-renewable | 8,99 € | 1 semaine |
| `com.useprocess.annual3499` | Auto-renewable | 34,99 € | 1 an |
| `com.useprocess.monthly999` | Auto-renewable | 9,99 € | 1 mois |
| `com.useprocess.annual4999` | Auto-renewable | 49,99 € | 1 an |

Localisations FR/EN + soumettre avec la version app (ou “Ready to Submit”).

Les anciens `com.useprocess.monthly` / `com.useprocess.annual` peuvent rester pour les abonnés existants.

---

## 2. RevenueCat

1. **Products** → importer / ajouter les 4 nouveaux product IDs Apple.
2. Créer **2 offerings** :

### Offering `Premium_A` (Current optionnel)
- Package Weekly → `com.useprocess.weekly899` (identifier `$rc_weekly` ou custom)
- Package Annual → `com.useprocess.annual3499`

### Offering `Premium_B`
- Package Monthly → `com.useprocess.monthly999`
- Package Annual → `com.useprocess.annual4999`

3. Entitlement `premium` sur **tous** ces produits.
4. Garder l’offering `Premium` historique si besoin (legacy).

L’app charge `Premium_A` ou `Premium_B` selon le flag, puis résout par **product ID**.

---

## 3. PostHog — créer l’expérience

1. PostHog → **Experiments** → New experiment  
2. Name : `Paywall pricing A/B`  
3. Feature flag key : **`paywall-pricing-ab`** (exact)  
4. Variants :
   - `control` — 50% — “A weekly 8.99 + annual 34.99”
   - `test` — 50% — “B monthly 9.99 + annual 49.99”
5. Rollout : **100%**  
6. Primary metric (exemple) : event `purchase_completed`  
7. Secondary : `paywall_viewed`, `paywall_cta_tapped`, `purchase_started`  
8. Filter / breakdown property : `pricing_variant`  
9. **Launch** l’expérience

L’app persiste la variante (UserDefaults) pour ne pas flip-flopper pendant l’onboarding.

---

## 4. Code (déjà branché)

- `PaywallPricingExperiment.swift` — résolution flag + sticky assignation  
- `SubscriptionConfiguration` / `SubscriptionService` — product IDs par variante  
- `PaywallView` — picker Hebdo|Annuel (A) ou Mensuel|Annuel (B)  
- Events enrichis avec `pricing_variant`

Boot : `ProcessAnalytics.configure()` → `PaywallPricingExperiment.shared.resolve()` → `loadSubscriptions()`.

---

## 5. Test local

1. Scheme Xcode avec `SubscriptionProducts.storekit` (produits A/B inclus).  
2. DEBUG : forcer une variante (puis relancer l’app) :

```swift
UserDefaults.standard.set("test", forKey: "process.paywall_pricing_variant")
// Variante A :
// UserDefaults.standard.set("control", forKey: "process.paywall_pricing_variant")
// Reset sticky :
// UserDefaults.standard.removeObject(forKey: "process.paywall_pricing_variant")
```

3. Ou dans PostHog → Feature flags → override pour ton `distinct_id` (après reset sticky).  
4. Vérifier le picker : **Hebdo | Annuel** (A) vs **Mensuel | Annuel** (B).

---

## 6. Checklist go-live

- [x] 4 SKUs ASC créés (groupe `21837790`) — prix + EN/FR + dispo mondiale  
  Statut ASC : *Finaliser avant soumission* jusqu’à inclusion dans une version app  
- [x] RevenueCat : 4 products **Ready to Submit**, offerings `Premium_A` + `Premium_B`, entitlement `premium`  
- [x] Experiment PostHog `paywall-pricing-ab` **Running** (50/50, metric `purchase_completed`)  
- [ ] Build TestFlight avec ce code (Archive Xcode — pas depuis Cursor)  
- [ ] Sandbox : forcer `control` → Hebdo|Annuel ; `test` → Mensuel|Annuel ; achat OK  
- [ ] Vérifier events PostHog avec `pricing_variant`

### Liens

- ASC groupe : https://appstoreconnect.apple.com/apps/6753808143/distribution/subscription-groups/21837790  
- PostHog experiment : https://eu.posthog.com/project/240558/experiments/89144  
- RC offerings : https://app.revenuecat.com/projects/ab4f477a/product-catalog/offerings

---

## Lifetime winback (`com.useprocess.lifetime`) — US vs FR

### Problème

Le paywall spin/winback affichait **19€ en dur** alors que le tier App Store Connect US facturait ~**$17**. L’UI et le checkout divergeaient.

### Code (fait)

- `SubscriptionService.loadLifetimeCatalog()` charge le prix StoreKit / RevenueCat pour `com.useprocess.lifetime`.
- UI + analytics + quick action utilisent `winbackLifetimeDisplayPrice` / `winbackCompareAtDisplayPrice`.
- Fallback si catalogue absent : **19€** (FR) / **$24.99** (EN).
- Sandbox `SubscriptionProducts.storekit` : `displayPrice` **24.99**.

### App Store Connect — action manuelle requise

Le **montant facturé** ne change que dans ASC :

| Produit | ID | Tier cible US | Tier cible FR |
|---------|-----|---------------|---------------|
| Lifetime winback | `com.useprocess.lifetime` | **$24.99** (ou $29.99 si tu veux plus de marge) | **19,99 €** (inchangé si déjà OK) |

1. ASC → **In-App Purchases** → `com.useprocess.lifetime` → **Pricing** → United States → monter le tier (ex. $24.99).
2. Attendre propagation (~15 min) ; vérifier en sandbox US que `Product.displayPrice` = `$24.99`.
3. Soumettre la IAP avec la prochaine version app si statut *Finaliser avant soumission*.

Sans cette étape ASC, l’app affichera le bon prix fallback ou StoreKit localisé, mais le **checkout US restera ~$17** tant que le tier n’est pas monté.

### Abonnements A/B — US (21 août 2026)

| Product ID | FR | US (avant) | US (depuis 2026-08-21) |
|------------|-----|------------|-------------------------|
| `com.useprocess.weekly899` | 8,99 € / sem | 7,99 $ | **9,99 $** |
| `com.useprocess.monthly999` | 9,99 € / mois | 8,99 $ | **9,99 $** |
| `com.useprocess.annual3499` | 34,99 € / an | 29,99 $ | **29,99 $** (inchangé) |
| `com.useprocess.annual4999` | 49,99 € / an | 44,99 $ | **44,99 $** (inchangé) |
