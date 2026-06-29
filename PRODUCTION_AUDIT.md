# Audit production — 29 juin 2026

## Verdict

**Prêt pour la validation finale sur iPhone et l'archive App Store.**

Les défauts critiques visibles dans la console ont été corrigés. Les règles et
les Cloud Functions sont déployées. La publication reste conditionnée par un
test sur iPhone réel et une archive Release effectués par le propriétaire.

Contrainte respectée pendant cet audit : aucun build Xcode et aucun simulateur
n'ont été lancés.

## Correctifs réalisés

- Firebase est initialisé avant les services qui peuvent l'utiliser.
- Un `UIApplicationDelegate` conforme est fourni aux SDK Google.
- Le cache persistant Firestore est borné à 100 Mo.
- Le doublon de `navigationDestination(ProfileSettingsCategory)` a été retiré.
- Le provisionnement des pseudos est limité à une tentative par minute et par
  utilisateur en cas d'échec réseau ou de permissions.
- Les règles `usernames` interdisent l'énumération globale, valident le schéma
  et conservent la recherche exacte d'un pseudo.
- Le scan AR ne lit plus les propriétés UIKit depuis la file SceneKit.
- L'enregistreur ne conserve plus les objets `ARFrame`; au maximum un pixel
  buffer est en attente de traitement.
- Les captures et meshes AR sont échantillonnés au lieu d'être recréés à chaque
  frame.
- Les vidéos vides ou manifestement tronquées ne sont plus présentées au player.
- Le démontage du player évite l'appel XPC inutile observé dans la console.
- Les dimensions de progression sont bornées et restent toujours finies.
- Les retours haptiques répétés passent de ~45 Hz à 25 Hz.
- Les endpoints IA valident tâche, modèle, historique, prompt et image.
- Une limite serveur protège les endpoints IA : 500 requêtes/jour/utilisateur et
  au minimum 750 ms entre deux requêtes.
- La suppression de compte efface récursivement toutes les données Firestore et
  les pseudos avant de supprimer l'identité Firebase.
- Une étape `predeploy` compile désormais les Cloud Functions avant déploiement.
- Deux assets PNG strictement identiques ont été mutualisés, soit environ 4 Mo
  retirés sans changement visuel.
- Les fichiers `.DS_Store` ont été supprimés et sont désormais ignorés.
- Firebase App Check avec App Attest est intégré et enregistré pour
  `com.useprocess` avec le Team ID Apple correct.
- Les Cloud Functions vérifient les jetons App Check en mode observation. Le
  refus strict pourra être activé après validation des métriques du nouveau
  client, sans bloquer les versions déjà installées.
- Les dépendances backend ont été mises à niveau et l'exécution Cloud utilise
  Node.js 22.
- Une CI GitHub valide le backend, l'audit npm, les plists, les secrets et le
  parsing Swift.
- MetricKit collecte localement les métriques et diagnostics système agrégés,
  sans contenu utilisateur.

## Lecture de la console

| Message | Diagnostic | État |
|---|---|---|
| Firebase app not configured | ordre d'initialisation | corrigé |
| App Delegate does not conform | delegate SwiftUI absent | corrigé |
| Firestore permission denied sur `usernames` | règles déployées probablement différentes du dépôt | règles locales corrigées et validées, déploiement requis |
| `navigationDestination` déclaré plusieurs fois | destination dupliquée dans la même pile | corrigé |
| `Invalid frame dimension` | progression non bornée/non finie | corrigé |
| UIKit API on background thread | lecture de `ARSCNView.bounds` depuis SceneKit | corrigé |
| ARSession retains 11/12 ARFrames | `ARFrame` capturé par une file asynchrone | corrigé |
| Reporter rate limit 32 Hz | haptique répétée à ~45 Hz | corrigé |
| PlayerRemoteXPC clearVideoLayer | ordre de démontage du player | corrigé |
| CMVideoFormatDescription invalid | vidéo incomplète/corrompue | enregistreur durci + fichiers trop courts filtrés |
| AttributeGraph cycle | très probablement amplifié par la navigation dupliquée | cause principale corrigée, à confirmer sur appareil |
| PointerUI, FigApplicationStateMonitor, CoreMotion plist | bruit système iOS/Xcode | aucune action applicative justifiée |
| ARSCNView focus caching | avertissement système non bloquant | aucune action requise |
| zoom transition from nil view | repli SwiftUI automatique quand la source disparaît | non bloquant, design conservé |

## Contrôles passés

- Parsing statique de tous les fichiers Swift : **0 échec**.
- `git diff --check` : **OK**.
- Plists application, entitlements, confidentialité et Firebase : **OK**.
- JavaScript généré des Cloud Functions : **syntaxe OK**.
- Règles Firestore : **compilées et déployées** sur `useprocess-d4385`.
- Cloud Functions `coachComplete`, `coachStream` et `deleteUserAccount` :
  **actives en Node.js 22**.
- Tests backend : **5/5 réussis**.
- Audit npm de production : **0 vulnérabilité connue**.
- Tests HTTP sans authentification : **401 sur les trois endpoints**, comme
  attendu.
- Aucun secret Anthropic/OpenAI n'est versionné dans le dépôt.
- Aucun transport HTTP arbitraire n'est autorisé.

## Validations finales avant publication

1. Tester sur iPhone réel : lancement à froid, connexion Apple, pseudo,
    accueil/scroll, scan visage complet, lecture vidéo, coach streaming,
    achat/restauration et suppression de compte.
2. Effectuer ensuite une archive Release et traiter tout warning de compilation
    ou d'upload App Store. Cette étape est volontairement laissée au propriétaire.
3. Reporter dans App Store Connect les catégories du manifeste :
   profil/identifiants, santé, fitness, photos/vidéos, contenu utilisateur et IA.
4. Après diffusion du client App Check et observation de ses métriques, passer
   `ENFORCE_APP_CHECK=true` pour les fonctions et activer l'enforcement Firestore.
5. RevenueCat reste optionnel : sans clé publique `appl_…`, le service utilise
   le chemin StoreKit 2 natif déjà implémenté.

## Taille et assets

- Projet après nettoyage : environ **238 Mo**.
- Assets source : environ **84 Mo**.
- Les autres images lourdes n'ont pas été recompressées : une compression sans
  validation visuelle pourrait modifier le rendu ou augmenter la mémoire de
  décodage.
