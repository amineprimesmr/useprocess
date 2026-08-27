# Paywall — A/B essai annuel 3 jours

## En cours : `paywall-annual-trial-ab`

Experiment : [Paywall annual 3-day trial](https://eu.posthog.com/project/240558/experiments/92662) (id **92662**).

Flag : `paywall-annual-trial-ab` — **ne pas** réutiliser `paywall-pricing-ab`.

| Bras | SKU annuel | Essai | Prix |
|------|------------|-------|------|
| **control** | `com.useprocess.annual3499` | aucun | 9,99 € / mois + 34,99 € / an |
| **test** | `com.useprocess.annual3499trial` | **3 jours** (intro Apple) | mêmes prix |

Un code parrainage / créateur validé débloque l’essai **dans les deux bras** (override).

Fallback si le flag est down : **control** (comportement actuel). Variante sticky dans `process.paywall_annual_trial_variant`.

### Métriques

- Primaire : funnel exposure → `purchase_completed` (l’essai gonfle les conversions — juger aussi les cancels).
- Secondaire : funnel exposure → `purchase_cancelled` (goal decrease).

Pas de propriété `revenue` sur `purchase_completed` aujourd’hui. Ne pas conclure au revenu Apple depuis ce funnel seul.

### App

- `PaywallPricingExperiment` lit `PostHogSDK.shared.getFeatureFlag("paywall-annual-trial-ab")`.
- Catalogue RC **`Premium`** inchangé : `$rc_annual` → `annual3499`, `annual_trial` → `annual3499trial`.
- StoreKit : intro 3 jours uniquement sur `annual3499trial`.

### Test local

Scheme Xcode + `SubscriptionProducts.storekit`.

1. Control, sans code → annuel 34,99, CTA sans essai, achat `annual3499`.
2. Test, sans code → bandeau « 3 jours offerts », CTA essai, achat `annual3499trial`.
3. Control **avec** code valide → même essai que le bras test (override parrainage).
4. Rebuild Xcode / TestFlight — l’experiment est **running** depuis le 24 août 2026. L’app **1.10** (build 36) évalue `paywall-annual-trial-ab`. Le 1.08 en store ne le lit pas.

---

## Historique : `paywall-pricing-ab` (terminé)

Experiment [89144](https://eu.posthog.com/project/240558/experiments/89144) — **stopped** (`stopped_early`). Flag inactif.

Offre figée ensuite : 9,99 € / mois + 34,99 € / an. Essai 3 jours d’abord limité au parrainage, puis testé pour tout le monde via `paywall-annual-trial-ab`.

SKU `com.useprocess.annual3499trial` (ASC `6803672506`) — vérifier qu’il est **Ready to Submit / Approved** avant prod. Créé le 20 août 2026, intro 3 jours, 175 territoires.

SKUs A/B anciens (`weekly899`, `annual4999`) : abonnés déjà dessus seulement.
