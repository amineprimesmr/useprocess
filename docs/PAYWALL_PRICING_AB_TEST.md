# Paywall — catalogue unique + essai parrainage

L’A/B `paywall-pricing-ab` est **terminé** (PostHog experiment 89144, flag désactivé).

## Offre actuelle

| Plan | Product ID | Prix EUR | Essai |
|------|------------|----------|-------|
| Mensuel | `com.useprocess.monthly999` | **9,99 € / mois** | aucun |
| Annuel | `com.useprocess.annual3499` | **34,99 € / an** | aucun |
| Annuel + parrainage | `com.useprocess.annual3499trial` | **34,99 € / an** | **3 jours gratuits** (intro Apple) |

Sans code validé (créateur **ou** ami) : le paywall n’affiche **aucun** essai, et l’achat annuel part sur `annual3499`.

Avec code validé : bandeau + CTA « Démarrer mon essai gratuit », achat sur `annual3499trial`.

Les SKUs A/B (`weekly899`, `annual4999`) restent pour les abonnés déjà dessus.

---

## App Store Connect (fait 20 août 2026)

Groupe **Process Premium** (`21837790`) :

- Intro 3 jours **retirée** de `annual3499`, `annual4999` et `annual` (legacy).
- SKU créé : `com.useprocess.annual3499trial` (ASC `6803672506`), **WAITING_FOR_REVIEW**.
- Prix : **34,99 €** (FRA) / **29,99 $** (USA), égalisé sur 175 territoires.
- Intro : **3 jours gratuits**, 175 territoires.
- Localisations `en-US` + `fr-FR`, screenshot de review copié depuis `annual3499`.

---

## RevenueCat (fait 20 août 2026)

- Produit importé : `com.useprocess.annual3499trial` (attaché à l’entitlement `premium`).
- Offering **`Premium`** (current) :
  - `$rc_monthly` → `com.useprocess.monthly999`
  - `$rc_annual` → `com.useprocess.annual3499`
  - `annual_trial` → `com.useprocess.annual3499trial`
- `Premium_A` / `Premium_B` inchangés (historique A/B).

---

## PostHog

- Experiment : [Paywall pricing A/B](https://eu.posthog.com/project/240558/experiments/89144) — **stopped** (`stopped_early`).
- Flag `paywall-pricing-ab` : **inactif**.
- Events utiles : `referral_annual_trial_unlocked`, `purchase_completed` (`offer=trial|standard`).

---

## Test local

Scheme Xcode + `SubscriptionProducts.storekit` (intro 3 jours sur `annual3499trial`).

1. Onboarding **sans** code → paywall mensuel 9,99 / annuel 34,99, CTA sans essai.
2. Code 5 caractères valide (créateur ou ami) → bandeau « 3 jours offerts », CTA essai, achat `annual3499trial`.
3. Menu paywall **Code de parrainage** : même déblocage.
4. Lien `?ref=` / `?code=` : revalidation au paywall.

---

## Lifetime winback (`com.useprocess.lifetime`)

Inchangé : prix StoreKit, fallback 19 € FR / $24.99 EN. Pas d’essai gratuit.
