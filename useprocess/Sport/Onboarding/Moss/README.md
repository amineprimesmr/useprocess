# Moss Onboarding Chat (intégration Process)

Composants extraits de [mossonboardingchat](https://github.com/imranhsni/mossonboardingchat) pour la discussion onboarding (`OnboardingStep.weightMotivation`).

## Fichiers Moss (verbatim ou adaptés)

| Fichier | Rôle |
|---------|------|
| `MossConversationEngine.swift` | Typewriter, haptiques CoreHaptics, pile de messages |
| `MossChat.swift` | Bulles, chips, boutons, arc respirant, layout |
| `MossAnalytics.swift` | Logs funnel locaux (Console) |
| `ProcessMossTheme.swift` | Pont `Theme` → couleurs Process / `OnboardingTheme` |
| `MossWordmark.swift` | Stub (Process n’affiche pas le wordmark Moss) |
| `OnboardingMossChatHelpers.swift` | Conversion banque de questions → `MossLine` |

## Parcours

```
OnboardingProfileChatView
  └─ MossConversationEngine (typewriter + profondeur)
  └─ OnboardingProfileChatViewModel (questions, persistance, face scan)
  └─ OnboardingProfileChatQuestionBank (contenu FR Process)
```

## Test

- **Haptiques** : ne fonctionnent pas dans le simulateur — tester sur appareil réel.
- **Tap pendant le typewriter** : complète la ligne en cours (comportement Moss).
- **Reduce Motion** : séquence conservée, animation glyphe désactivée.

## Retheme

Ajuster `ProcessMossTheme.swift` et l’intensité de `MossBreathingArc` dans `OnboardingProfileChatView`.
