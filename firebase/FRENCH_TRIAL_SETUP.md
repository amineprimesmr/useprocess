# Essai 3 jours — uniquement avec code parrainage / créateur

L’essai n’est **plus** un droit marché France. Il se débloque seulement après un code validé (onboarding, paywall, ou lien `ref`/`code`).

Sans code : **aucun** essai, paiement immédiat (9,99 €/mois ou 34,99 €/an).

## Produits

| Product ID | Rôle | Intro 3 jours |
|---|---|---|
| `com.useprocess.monthly999` | Mensuel 9,99 € | **non** |
| `com.useprocess.annual3499` | Annuel 34,99 € sans code | **non** (intro retirée) |
| `com.useprocess.annual3499trial` | Annuel 34,99 € **avec code** | **oui**, 3 jours, 175 territoires (ASC `6803672506`, waiting for review) |

## App Store Connect

Fait : intro 3 jours retirée de `annual3499` / `annual4999` / `annual`. SKU `annual3499trial` créé, tarifé, localisé FR/EN, soumis.

## RevenueCat

Fait : `annual3499trial` importé, entitlement `premium`, offering `Premium` = monthly999 + annual3499 + package `annual_trial`.

## Tests

| Parcours | Attendu |
|---|---|
| Onboarding **sans** code | CTA « Continuer, aucun engagement. » — pas de 3 jours |
| Code créateur / ami validé | Bandeau + « Démarrer mon essai gratuit » — achat `annual3499trial` |
| Paywall → Code de parrainage | Même déblocage après résolution du code |
| Compte qui a déjà consommé l’intro du groupe | Pas d’essai (éligibilité Apple) |
