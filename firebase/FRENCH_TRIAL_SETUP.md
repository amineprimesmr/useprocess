# Essai gratuit 3 jours — marché France (App Store Connect)

L’app active l’essai **uniquement** quand le **storefront App Store** est `FRA` (compte iTunes France).  
La langue de l’app (FR/EN) ne change pas la facturation — seul le pays du compte App Store compte.

## Produits concernés

Configurer l’intro offer sur **chaque produit annuel** actif :

| Product ID | Offering RevenueCat |
|---|---|
| `com.useprocess.annual3499` | Premium_A |
| `com.useprocess.annual4999` | Premium_B |
| `com.useprocess.annual` | Premium (legacy) |

**Ne pas** ajouter d’intro sur hebdo / mensuel — l’app n’expose l’essai que sur le plan **Annuel**.

## App Store Connect — étapes

1. **App Store Connect** → Apps → Process → **Subscriptions** → groupe `21837790`
2. Ouvrir le produit annuel (ex. `com.useprocess.annual3499`)
3. **Subscription Prices** → vérifier que la France est bien tarifée
4. **Introductory Offers** → **+** → type **Free Trial**
5. Durée : **3 days**
6. **Territories** : cocher **France** uniquement (décocher US, Canada, UK, Australie, etc.)
7. Répéter pour les autres product IDs annuels ci-dessus
8. **Save** puis attendre le statut **Ready to Submit** / sync StoreKit (souvent 15–60 min)

## Territoires stricts (sans essai)

Ne **pas** créer d’intro offer sur :

- United States
- United Kingdom
- Canada
- Australia
- New Zealand
- Ireland

L’app force aussi un paywall strict sur ces storefronts (`SubscriptionMarketPolicy.strictNoTrialStorefrontCountryCodes`).

## RevenueCat

**Aucune config dashboard requise** — RevenueCat expose les intro offers StoreKit par storefront.  
Offerings `Premium`, `Premium_A`, `Premium_B` + entitlement `premium` restent inchangés.

Attributs client enrichis automatiquement par l’app :

- `storefront_country`
- `trial_market_allowed`

### Vérification auto

```bash
python3 scripts/setup_french_trial_prod.py
```

Le script vérifie l’API RevenueCat (secret Firebase) et tente de créer les intro offers ASC via `asc` si une clé API ASC est configurée :

```bash
asc auth login --name Process --key-id KEY --issuer-id ISSUER --private-key /path/AuthKey.p8
python3 scripts/setup_french_trial_prod.py
```

Clé API ASC : [Integrations → App Store Connect API](https://appstoreconnect.apple.com/access/integrations/api)

## Tests sandbox

| Compte sandbox | Storefront | Attendu |
|---|---|---|
| Compte **France** | FRA | Paywall « Démarrer mon essai gratuit » + sous-titre « Aucun paiement aujourd’hui… » |
| Compte **US** | USA | Paywall strict — « Continuer, aucun engagement » — paiement immédiat |

1. Créer 2 testeurs sandbox (FR + US) dans App Store Connect → Users and Access → Sandbox
2. Sur l’iPhone : Réglages → App Store → Compte sandbox → se connecter avec le bon compte
3. Désinstaller / réinstaller l’app si l’éligibilité intro semble figée (1 essai max par groupe d’abo / Apple ID)
4. Vérifier dans PostHog : `paywall_viewed` avec `storefront_country` + `offer: trial` au tap CTA FR

## Comportement app (résumé)

```
essai affiché = storefront FRA
              ET produit annuel sélectionné
              ET éligibilité intro StoreKit (pas déjà consommé)
              ET intro offer ASC présente sur ce produit
```

US / anglophone : pas de copy essai, pas de logique trial — même si ASC était mal configuré.

## Checklist go-live

- [ ] Intro 3 jours sur les 3 product IDs annuels, **France only**
- [ ] Aucune intro sur weekly / monthly
- [ ] Build app avec ce commit déployé
- [ ] Test sandbox FR → essai OK
- [ ] Test sandbox US → strict OK
- [ ] RevenueCat dashboard : achat trial visible en `period_type: trial`
