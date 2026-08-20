# Apple Retention Messaging API — Process (via RevenueCat)

Quand un abonné tape **Annuler** sur l’écran Abonnements iOS, Apple peut afficher un message Process (texte, image, offre promo ou changement de plan) **avant** la confirmation d’annulation.

RevenueCat héberge l’endpoint temps réel — **aucun backend custom** dans ce repo.

Doc RevenueCat : [Apple Retention Messaging API](https://www.revenuecat.com/docs/platform-resources/apple-platform-resources/apple-retention-messaging-api)

Voir aussi : [`docs/REVENUECAT_SETUP.md`](../docs/REVENUECAT_SETUP.md)

---

## Identifiants Process (prêts à coller)

| Champ | Valeur |
|-------|--------|
| **App Name** (formulaire Apple) | `Process : Debloat ton visage` |
| **Apple ID** (App Store Connect) | `6753808143` |
| **Bundle ID** | `com.useprocess` |
| **Groupe abonnements ASC** | `21837790` (Process Premium) |
| **Entitlement RevenueCat** | `premium` |

### Product IDs (tous les abos live)

| SKU | Product ID |
|-----|------------|
| Hebdo A | `com.useprocess.weekly899` |
| Annuel A | `com.useprocess.annual3499` |
| Mensuel B | `com.useprocess.monthly999` |
| Annuel B | `com.useprocess.annual4999` |
| Legacy mensuel | `com.useprocess.monthly` |
| Legacy annuel | `com.useprocess.annual` |
| Lifetime (hors abo) | `com.useprocess.lifetime` |

**Endpoint URL** : RevenueCat → **Project Settings** → **Apps** → app iOS → section **Apple Retention Messaging** (copier l’URL sandbox puis prod après le perf test).

---

## Ce qui est déjà fait dans le repo

- SDK RevenueCat configuré (`SubscriptionService.swift`, clé `appl_…` dans `RevenueCatConfiguration.swift`)
- Bouton **Paramètres → Mon compte → Gérer mon abonnement** → `AppStore.showManageSubscriptions` (requis pour tester en TestFlight)
- Copy FR/EN de référence : `SubscriptionConfiguration.RetentionMessagingCopy`

---

## Ce qui reste manuel (Apple + RevenueCat dashboard)

Apple n’expose **pas** d’API publique pour demander l’accès au programme. RevenueCat n’expose **pas** d’API REST pour créer les messages retention (dashboard uniquement).

### Étape 1 — Demander l’accès Apple (Account Holder)

1. Ouvrir le [formulaire Apple Retention Messaging](https://developer.apple.com/contact/request/retention-messaging-api/) (lien depuis la doc RevenueCat si celui-ci change).
2. Remplir :
   - **App Name** : `Process : Debloat ton visage`
   - **Apple ID** : `6753808143`
   - **Endpoint URL** : URL copiée depuis RevenueCat (voir tableau ci-dessus)
   - Cocher : *My app currently has a subscription on the App Store*
3. Soumettre et attendre l’e-mail d’approbation Apple.

### Étape 2 — RevenueCat : sandbox URL + perf test

1. [app.revenuecat.com](https://app.revenuecat.com) → projet Process → **Lifecycle** → **Retention**
2. Section **Apple Retention Messaging API** → connecter l’**URL sandbox**
3. Créer une transaction **sandbox** ou **TestFlight** (pas de fichier `.storekit` local)
   - Produit avec la **plus longue durée** disponible (évite expiration pendant le test)
4. Lancer le **performance test** (latence &lt; 700 ms) — peut prendre ~1 h
5. La transaction doit rester active pendant le test

### Étape 3 — Message default (sandbox)

**Lifecycle → Retention** → toggle **SANDBOX DATA** ON → **Add default**

| Champ | Valeur |
|-------|--------|
| Reference | `process_default_all_subs` |
| Products | Tous les abos ci-dessus (sauf lifetime) |

**Locales** (titres ≤ 66 car., sous-titres ≤ 144 car.) :

| Locale | Title | Subtitle |
|--------|-------|----------|
| `fr-FR` | `Garde ton plan debloat actif` | `Scans visage, routine et coach restent débloqués tant que tu restes abonné.` |
| `en-US` | `Keep your debloat plan going` | `Face scans, routine, and coach stay unlocked while you stay subscribed.` |

→ **Auto translate** pour les autres locales, puis **Save** (soumis à Apple ; instantané en sandbox).

### Étape 4 — Message essai gratuit (optionnel)

Après le default, **+ New message** :

| Champ | Valeur |
|-------|--------|
| Reference | `process_trial_cancel` |
| Eligibility | **Is in free trial** (pas « intro offer period ») |
| Type | Texte seul (pas d’offre promo associée) |

| Locale | Title | Subtitle |
|--------|-------|----------|
| `fr-FR` | `Ton essai t’aide déjà à debloat` | `Continue maintenant pour garder tes scans, ta routine et ton coach.` |
| `en-US` | `Your trial is already helping you debloat` | `Continue now to keep your scans, routine, and coach.` |

### Étape 5 — Offre promo winback (optionnel, plus tard)

1. App Store Connect → abonnements → **Offres promotionnelles** (ex. `-50 %` sur renouvellement)
2. RevenueCat → message type **Promotional offer** avec `active_product` + `promotional_offer_id` ASC
3. Toujours garder un **default message** en fallback

Offre lifetime app existante : `lifetime_19` (`SubscriptionConfiguration.winbackOfferID`) — **non éligible** à Retention Messaging (achat unique, pas abonnement).

### Étape 6 — Production

1. Perf test sandbox **réussi**
2. Connecter l’**URL production** dans RevenueCat
3. Toggle **SANDBOX DATA** OFF
4. **Recréer** les mêmes messages en prod (sandbox ≠ prod)
5. Attendre approbation Apple par locale (prod)

---

## Tester dans l’app

1. Build **TestFlight** ou device + compte **sandbox Apple ID**
2. Souscrire à un abo Process
3. **Paramètres → Mon compte → Gérer mon abonnement**
4. Process → **Annuler l’abonnement** → écran **Confirmer l’annulation** avec le message

En TestFlight, le renouvellement accéléré ≈ 1 jour (Apple).

**Ne pas utiliser** `SubscriptionProducts.storekit` pour ce test.

---

## Analytics

Les graphiques **save rate** RevenueCat nécessitent **App Store Server Notifications** configurées sur le projet. Le webhook commissions parrainage (`referralRevenueCatWebhook`) est distinct.

---

## Script checklist

```bash
./firebase/scripts/retention-messaging-checklist.sh
```

Affiche les identifiants et le copy-paste pour le dashboard.
