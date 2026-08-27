# Telegram clippers — playbook complet

Tout le copy est prêt à coller. Références produit :

| Élément | Valeur |
|---|---|
| Portail clipper | `https://useprocess.xyz/clipping` (`/affiliate` redirige dessus) |
| Connexion | lien magique envoyé par email depuis `contact@useprocess.xyz` |
| WhatsApp support (leks) | `https://wa.me/33782637720` — 07 82 63 77 20 |
| Email support | `support@useprocess.xyz` |
| App Store Process | `https://apps.apple.com/app/id6753808143` |
| Commission | 40 % du net, à vie, hold 30 j |
| Primes vues | 100k → 50 € · 500k → 100 € · 1M → 150 € + coaching · 10M → iPhone 17 |

Ancres directes dans le portail (routing par hash) :

```
https://useprocess.xyz/clipping#methode          → Démarrage (la formation)
https://useprocess.xyz/clipping#slideshowlab     → SlideshowLab (structures officielles)
https://useprocess.xyz/clipping#assets           → Process Assets (screens, logos, b-roll)
https://useprocess.xyz/clipping#format           → Format (bibliothèque de formats qui marchent)
https://useprocess.xyz/clipping#clippers         → Clippers (leaderboard)
https://useprocess.xyz/clipping#automatisation   → Automatiser (planif TikTok)
https://useprocess.xyz/clipping#us               → Poster US
https://useprocess.xyz/clipping#utiles?t=shadowban → Shadowban
https://useprocess.xyz/clipping#utiles?t=questions → Questions
https://useprocess.xyz/clipping#payouts          → Paiements (Stripe)
```

---

## 1. Le message automatique d'accueil

### Contrainte technique à connaître

Un bot Telegram **ne peut pas envoyer un DM à quelqu'un qui ne lui a jamais parlé**. Deux façons de contourner :

- **Option A (5 min, sans code)** — message de bienvenue **dans le groupe**, qui tag le nouveau, avec des boutons. Bot : `@GroupHelpBot` (ou `@MissRose_bot`). Le bouton « Recevoir mon pack » ouvre un DM avec le bot → à partir de là tu peux lui écrire.
- **Option B (bot custom, ~1 h de dev)** — tu passes le groupe en **demandes d'adhésion** (« Approuver les nouveaux membres ») avec un lien d'invitation **créé par ton bot**. Telegram autorise alors le bot à DM la personne dès qu'elle envoie sa demande, avant même qu'elle soit acceptée. C'est le setup propre : séquence d'onboarding privée, J+1 / J+3 / J+7 automatiques, et tu peux relier ça au portail (savoir qui s'est connecté, qui n'a pas posté). Hébergeable dans `firebase/functions` à côté de l'affiliate.

Commence par A aujourd'hui. B quand le flux de nouveaux justifie l'automatisation.

### Setup Option A — pas à pas

1. Ajoute `@GroupHelpBot` au groupe, **admin** (droits : supprimer messages, épingler, bannir).
2. En DM avec le bot : `/settings` → choisis le groupe → **Welcome** → **Set welcome message**.
3. Colle le message ci-dessous. Active **« Delete previous welcome »** (évite le spam) et **« Delete after 10 minutes »**.
4. Onglet **Buttons** → ajoute les 3 boutons listés plus bas.
5. Active **Antiflood** + **Antispam links** (les groupes clippers attirent les vendeurs de formation).
6. Épingle le message « START HERE » (section 2).

### Le message de bienvenue — FR

```
Bienvenue {name} 👋

Ici c'est le groupe des clippers Process. On paye 40 % du net à vie sur chaque abonné que tu ramènes, plus des primes cash sur les vues. Tout ce dont tu as besoin est déjà prêt dans ton portail.

▸ ÉTAPE 1 — Ouvre ton portail
useprocess.xyz/clipping
Connexion = tu mets ton email, tu reçois un lien magique (expéditeur contact@useprocess.xyz, regarde les spams). Ton code et ton lien de tracking sont dedans.

▸ ÉTAPE 2 — Fais la formation « Démarrage »
useprocess.xyz/clipping#methode
45 min. Tu y trouves : le produit, comment on vend, créer + chauffer tes comptes TikTok, éviter le shadowban, les 3 formats officiels, et ce que tu peux attendre comme résultats. Ne poste rien avant de l'avoir finie — tu perdrais tes comptes pour rien.

▸ ÉTAPE 3 — Télécharge Process et utilise-le
Tu ne peux pas vendre ce que tu ne connais pas. Fais ton scan visage, regarde ton score, suis le protocole. 20 minutes dans l'app, sérieusement.

▸ ÉTAPE 4 — Poste ton premier carrousel sous 72 h
Formats prêts à copier : useprocess.xyz/clipping#format
Assets (screens, logos, b-roll) : useprocess.xyz/clipping#assets

Une question, un blocage, un compte shadowban, un doute sur un format ?
WhatsApp direct : wa.me/33782637720 (leks)
Je réponds vite. Il n'y a pas de question bête, il y a des gens qui restent bloqués 3 jours pour rien.

Présente-toi ici en une ligne : ton prénom, ton niveau, combien de posts par jour tu vises. 👇
```

**Boutons à mettre sous le message :**

| Texte | URL |
|---|---|
| 🔑 Mon portail clipper | `https://useprocess.xyz/clipping` |
| 🎓 La formation | `https://useprocess.xyz/clipping#methode` |
| 💬 WhatsApp leks | `https://wa.me/33782637720` |

### Le même message — EN (pour les clippers US)

```
Welcome {name} 👋

This is the Process clippers group. We pay 40% of net revenue for life on every subscriber you bring, plus cash bonuses on views. Everything you need is already in your portal.

▸ STEP 1 — Open your portal
useprocess.xyz/clipping
Sign in with your email, you'll get a magic link (from contact@useprocess.xyz — check spam). Your code and tracking link are inside.

▸ STEP 2 — Do the "Getting started" training
useprocess.xyz/clipping#methode
45 min: the product, how we sell, creating + warming your TikTok accounts, avoiding shadowbans, the 3 official formats, realistic results. Don't post before you finish it — you'd burn accounts for nothing.

▸ STEP 3 — Download Process and actually use it
You can't sell what you don't know. Run your face scan, check your score, follow the protocol. 20 real minutes in the app.

▸ STEP 4 — Post your first carousel within 72h
Copy-ready formats: useprocess.xyz/clipping#format
Assets: useprocess.xyz/clipping#assets

Stuck on anything — a shadowbanned account, a format, a payout?
WhatsApp: wa.me/33782637720 (leks)

Introduce yourself below in one line: name, level, posts/day you're aiming for. 👇
```

---

## 2. Le message épinglé « START HERE »

Un seul message épinglé, jamais plus. Tout le reste vit dans le portail.

```
📌 START HERE — Process Clippers

CE QU'ON FAIT
On vend Process (scan du visage → score → protocole debloat/glow-up). Toi tu postes des carrousels TikTok. Chaque abonné qui vient de ton lien te rapporte 40 % du net, à vie, tant qu'il reste abonné.

TES 4 LIENS
1. Portail (lien, stats, paiements) → useprocess.xyz/clipping
2. Formation → useprocess.xyz/clipping#methode
3. Formats à copier → useprocess.xyz/clipping#format
4. Assets → useprocess.xyz/clipping#assets

COMMENT TU ES PAYÉ
• 40 % du net sur chaque abonnement, à vie
• Hold de 30 jours (fenêtre de remboursement Apple), puis dispo
• Virement via Stripe → à connecter dans #payouts du portail
• Primes vues EN PLUS : 100k = 50 € · 500k = 100 € · 1M = 150 € + coaching 1-to-1 · 10M = iPhone 17
  (les primes cash se débloquent à 200 € de commission déjà générée, l'iPhone à 1000 €)
• Pour claim une prime : DM leks avec le lien du compte TikTok

LES RÈGLES DU GROUPE
1. Pas de pub, pas de dropshipping, pas de recrutement. Ban direct.
2. On ne partage pas les formats hors du groupe.
3. Tu postes tes wins (vues, ventes) → ça aide tout le monde à calibrer.
4. Tu es bloqué → tu demandes ici ou en WhatsApp. Tu ne restes pas bloqué en silence.
5. Ce qui se dit ici reste ici.

BLOQUÉ ?
WhatsApp leks : wa.me/33782637720
Email : support@useprocess.xyz
```

---

## 3. Structure du groupe (Topics)

Active les **Topics** (Sujets) dans les réglages du groupe. 6 sujets, pas plus :

| Topic | Rôle | Qui poste |
|---|---|---|
| 📢 Annonces | drops de formats, changements de commission, concours | toi seul (verrouillé) |
| 🏆 Wins | captures de vues + de ventes | tout le monde |
| ❓ Aide | shadowban, compte bloqué, question format | tout le monde |
| 🎬 Review de posts | on colle son post, on reçoit un retour | tout le monde |
| 📊 Leaderboard | classement hebdo | toi seul (verrouillé) |
| 💬 Général | le reste | tout le monde |

Pourquoi ça marche : un clipper bloqué qui doit chercher dans 400 messages abandonne. Un clipper qui voit 3 wins par jour poste plus.

---

## 4. Le parcours d'un nouveau clipper — J0 → J14

C'est ça, « les rendre vraiment performants ». Poste cette checklist en DM (ou dans Aide) à chaque nouveau.

```
TA CHECKLIST — coche au fur et à mesure

J0 (aujourd'hui, 1 h)
☐ Portail ouvert, lien de tracking copié → useprocess.xyz/clipping
☐ Formation « Démarrage » finie → #methode
☐ Process téléchargé + scan visage fait + 20 min dans l'app
☐ Stripe connecté dans #payouts (sinon on ne peut pas te payer)
☐ Présentation postée dans le groupe

J1–J2 (chauffe)
☐ Compte TikTok créé selon la méthode (#methode → « Créer ses comptes TikTok »)
☐ 2 jours de warm-up SANS poster : tu scrolles, tu likes, tu commentes dans la niche
☐ Bio + PP conformes à ce qui est dans la formation
☐ Tu as lu la fiche Shadowban → #utiles?t=shadowban

J3 (premier post)
☐ Format 01 — Guide 72h copié depuis #format
☐ Carrousel monté avec les assets officiels (#assets)
☐ Posté. Collé dans 🎬 Review de posts pour retour.

J4–J14 (volume)
☐ 1 à 3 posts / jour selon ton temps — la régularité bat la perfection
☐ Tu alternes les formats (01 Guide 72h / 02 Glow-up célébrité / 03 Foods) pour ne pas lasser le FYP
☐ Tu postes ton meilleur et ton pire résultat dans 🏆 Wins chaque semaine
☐ Objectif J14 : 20 posts en ligne, 1 vidéo à +10k vues, 1ère vente

Si tu n'as pas ta 1ère vente à J14 → WhatsApp leks. On regarde tes posts ensemble. C'est presque toujours le hook ou le CTA, jamais l'algo.
```

### Les 5 erreurs à répéter en boucle

À poster en Annonces, et à ressortir dès qu'un clipper cale :

```
LES 5 TRUCS QUI TUENT UN CLIPPER

1. Poster avant d'avoir chauffé le compte → shadowban à vie sur ce compte. 2 jours de warm-up, non négociable.
2. Coller la carte App Store en overlay sur le carrousel → TikTok déteste, ça plombe la portée. Le screen Process est UNE SLIDE de la grille, pas un sticker.
3. Changer de format toutes les 2 vidéos → tu n'apprends rien. 10 posts sur le MÊME format avant de juger.
4. Un hook flou. « Voici comment glow up » = 0. « visage gonflé ? fais ça 72h » = ça scrolle. Une promesse, une seconde.
5. Abandonner à 15 posts. La moyenne : la vidéo qui perce arrive entre le 15e et le 40e post. Ceux qui gagnent sont ceux qui étaient encore là.
```

---

## 5. Les rituels hebdo (c'est ce qui fait rester les gens)

| Quand | Quoi | Message type |
|---|---|---|
| Lundi 10 h | **Leaderboard** | « Classement de la semaine 🏆 1. @x — 340k vues / 6 ventes · 2. … · Le top 3 récupère un review perso de ses posts. » |
| Mercredi | **Drop de format** | « Nouveau format ajouté dans le portail → #format. Il tourne à 80k vues de moyenne en ce moment. Testez-le sur 5 posts. » |
| Vendredi 18 h | **Review live** | « Postez vos 3 meilleurs posts de la semaine dans 🎬. Je review tout ce soir. » |
| Dimanche | **Récap + objectif** | « Cette semaine : 1,2M vues cumulées, 34 ventes, 780 € versés au groupe. Objectif semaine prochaine : 2M. » |
| Ponctuel | **Win amplifié** | Quand quelqu'un fait une grosse vue : le republier en Annonces avec le breakdown (hook, format, heure de post). |

Deux principes :
- **Publie les chiffres réels du groupe.** Rien ne motive plus qu'un montant versé visible.
- **Récompense le volume, pas seulement les vues.** Un « clipper le plus régulier de la semaine » garde les débutants en vie.

---

## 6. Le flux « télécharger + laisser un avis »

Objectif réel : plus de notes et d'avis récents sur la fiche App Store → meilleur taux de conversion pour tout le monde, donc plus de commissions.

**⚠️ Une nuance importante avant de coller ça.** Demander à des partenaires rémunérés de mettre tous 5 étoiles, c'est de la manipulation d'avis au sens des règles App Store — Apple peut retirer l'app, et c'est exactement le pattern qu'ils détectent (un pic d'avis 5★ depuis des comptes liés). Le fond de ton idée est bon et il est parfaitement faisable : le clipper **doit** utiliser l'app pour savoir la vendre, et un utilisateur qui vient de voir son score et son protocole met naturellement une bonne note. La version ci-dessous demande un **avis honnête après usage réel**, sans note imposée et sans contrepartie — même effet sur la fiche, zéro risque pour l'app.

### Message à poster (Annonces) et à mettre dans l'onboarding

```
📲 AVANT DE POSTER : UTILISE L'APP

Ce n'est pas une formalité. Tu ne peux pas écrire un hook qui convertit sur un produit que tu n'as jamais ouvert. Les clippers qui vendent le plus sont ceux qui utilisent Process eux-mêmes — ils parlent de leur propre scan, pas d'une pub.

1. Télécharge Process → apps.apple.com/app/id6753808143
2. Fais ton scan visage. Note ton score.
3. Lance le protocole et reste 20 minutes dans l'app : regarde le plan, les étapes, le suivi. Repère les 3 écrans qui font le meilleur effet en slide — c'est ceux-là que tu mettras dans tes carrousels.
4. Le lendemain, refais un scan. Compare.
5. Puis, si l'app t'a servi, laisse un avis honnête sur l'App Store en disant ce que TU as constaté.
   Lien direct : apps.apple.com/app/id6753808143?action=write-review

Un avis sincère et détaillé fait vendre bien plus qu'une note sèche. Écris comme un vrai utilisateur, parce que tu en es un :
• ce que tu cherchais (« visage gonflé le matin »)
• ce que tu as fait (« scan + protocole 3 jours »)
• ce que tu as vu changer
• à qui tu le conseilles

Ce n'est ni obligatoire, ni payé, ni conditionné à quoi que ce soit. Mais chaque avis récent sur la fiche augmente le taux de conversion de TOUS tes posts — donc tes commissions à toi.
```

### Ce qu'il ne faut surtout pas faire

- Demander une capture de l'avis pour débloquer un paiement ou un bonus.
- Imposer la note, ou faire poster 20 avis le même jour.
- Faire poster des avis depuis des comptes créés pour l'occasion.

Chacun de ces trois points transforme un levier légitime en motif de retrait de l'app.

---

## 7. Réponses toutes prêtes (à garder sous la main)

**« Je ne reçois pas le mail de connexion »**
> Regarde les spams, l'expéditeur c'est contact@useprocess.xyz. Le lien est à usage unique et expire — redemandes-en un si besoin. Toujours rien : envoie-moi ton email en WhatsApp, je te vérifie ça.

**« Mon compte est shadowban »**
> Fiche complète ici → useprocess.xyz/clipping#utiles?t=shadowban. En 30 s : arrête de poster 48 h, ne supprime pas tes vidéos, ne change pas ta bio. Si après 48 h c'est toujours <200 vues, on repart sur un compte neuf en suivant la méthode de warm-up à la lettre.

**« Combien je peux gagner ? »**
> 40 % du net sur chaque abonné, à vie. Tant qu'il reste abonné, tu es payé chaque mois. Plus les primes vues (50 € à 100k, 100 € à 500k, 150 € + coaching à 1M, iPhone à 10M). Le simulateur est sur la page useprocess.xyz/clipping.

**« Quand je suis payé ? »**
> Hold de 30 jours après la vente (fenêtre de remboursement Apple), ensuite ça passe en « Disponible » et c'est viré via Stripe. Connecte ton Stripe dans le portail → Paiements, sinon rien ne peut partir.

**« Je poste depuis la France, ça marche pour les US ? »**
> Guide complet → useprocess.xyz/clipping#us. Résumé : téléphone dédié en anglais US, aucune SIM, VPN Outline sur serveur US, Apple ID US. À faire dans l'ordre, sinon TikTok te recale en FR.

**« Quel format je commence ? »**
> Le 01 — Guide 72h. Tous les jours. C'est le format n°1 en conversion. Tu fais 10 posts dessus avant de tester autre chose.

**« Je peux utiliser mon compte TikTok existant ? »**
> Oui si c'est dans la niche et qu'il est sain. Les comptes déjà créés comptent. Mais ne crame pas un compte à 50k abonnés sur un format que tu n'as pas encore calibré.

---

## 8. Ce qu'on peut automatiser ensuite (Option B)

Si tu veux, on code un bot Telegram dans `firebase/functions` qui :

- accepte les demandes d'adhésion et **DM la séquence d'onboarding** automatiquement ;
- relance à J+1 (« portail ouvert ? ») / J+3 (« 1er post ? ») / J+7 (« besoin d'un review ? ») ;
- publie le **leaderboard du lundi** en lisant `affiliates/{id}` dans Firestore ;
- poste une **notif de vente** dans 🏆 Wins (« @x vient de faire une vente 💸 ») en branchant le webhook RevenueCat existant ;
- lie l'ID Telegram au `affiliateId` pour savoir qui est actif et qui a décroché.

Toute l'infra existe déjà (`affiliateDashboard`, `affiliateLeaderboard`, webhook RevenueCat). Dis-le-moi et je le fais.
