import Foundation

/// Intelligence mewing / myofonction — script #09 (Oscar Patel).
/// Langue = moteur croissance faciale ; suction mew, sommeil, tongue tie, tongue chewing.
enum MewingIntelligenceGuide {

    // MARK: - Coach (injecté EnzoCoachingVoiceGuide)

    static let coachingPrinciplesBlock = """
    MEWING — SCRIPT #9 (suction mew, croissance faciale) :
    - Langue = moteur principal maxillaire — tiers postérieur sur palais 24/7 (santé + looks)
    - Suction mew (vide) — NE PAS pousser la langue 24h ; pousser = pas tenable
    - Technique : « T » → spot T → sourire + yeux ouverts + déglutition → répéter jusqu'à salive épuisée
    - Semaine 1 : toutes les heures, tenir la suction — rééducation neurologique
    - Sommeil : même routine avant coucher + **côté** (dos = langue tombe) + coussin genoux
    - Tape zygomatique + mentalis → lip seal → mewing passif nocturne
    - Tongue tie : T spot + résistance doigt 70 %, 30 s × 2/j — libère frenulum / epicranial fascia
    - Tongue chewing : gomme mastic/naturelle, pointe langue sur palais ~10 min/j
    - Thumb pull + myofonction catalysent (surtout si >20 ans) — temps cumulé sur palais compte
    - Ostéoblastes + fascias/sutures loosen → adaptation osseuse possible à tout âge
    """

    // MARK: - Habitudes 24/7

    static var suctionMewDetail: String {
        AppCopy.tSync(
            """
            Suction mew — langue en vide sur le palais (pas poussée) : « T », sourire + yeux ouverts, \
            déglutitions jusqu'à salive épuisée. Semaine 1 : rappel toutes les heures.
            """,
            en: """
            Suction mew — tongue suctioned to the palate (not pushed): "T", smile + eyes open, \
            swallow until saliva is gone. Week 1: hourly reminders.
            """
        )
    }

    static var lipSealDetail: String {
        AppCopy.tSync(
            "Lèvres closes, dents en contact léger — tape zyg + mentalis la nuit si besoin.",
            en: "Lips closed, teeth lightly touching — zyg + mentalis tape at night if needed."
        )
    }

    // MARK: - Routine orofaciale (face protocol)

    static var coreMewingRoutine: [String] {
        [
            AppCopy.tSync(
                "Suction mew — T spot, sourire + yeux hauts, déglutitions jusqu'à vide (matin + soir)",
                en: "Suction mew — T spot, smile + eyes up, swallow until empty (morning + evening)"
            ),
            AppCopy.tSync(
                "Rééducation semaine 1 — toutes les heures : tenir la suction le plus longtemps possible",
                en: "Week 1 re-education — every hour: hold suction as long as possible"
            ),
            AppCopy.tSync(
                "Étirement tongue tie — T spot, doigt résistance 70 %, 30 s × 2 séries",
                en: "Tongue-tie stretch — T spot, finger resistance 70%, 30 s × 2 sets"
            ),
            AppCopy.tSync(
                "Tongue chewing — gomme mastic, pointe langue sur palais ~10 min/j",
                en: "Tongue chewing — mastic gum, tongue tip on palate ~10 min/day"
            ),
            AppCopy.tSync(
                "Thumb pull — 8 semaines (expansion palais, langue comme retainer)",
                en: "Thumb pull — 8 weeks (palate expansion, tongue as retainer)"
            )
        ]
    }

    static var lightMewingRoutine: [String] {
        [
            AppCopy.tSync(
                "Suction mew 2×/jour — T spot + déglutitions conscientes",
                en: "Suction mew 2×/day — T spot + mindful swallows"
            ),
            AppCopy.tSync(
                "Langue sur palais à chaque déglutition — lèvres closes",
                en: "Tongue on palate at every swallow — lips closed"
            )
        ]
    }

    static var sleepMewingSteps: [String] {
        [
            AppCopy.tSync(
                "Avant coucher : suction mew complète (T + swallows jusqu'à salive épuisée)",
                en: "Before bed: full suction mew (T + swallows until saliva is gone)"
            ),
            AppCopy.tSync(
                "Dormir sur le côté — pas sur le dos (langue tombe avec gravité)",
                en: "Sleep on your side — not on your back (tongue drops with gravity)"
            ),
            AppCopy.tSync(
                "Coussin entre genoux + tape zygomatique + mentalis pour lip seal",
                en: "Pillow between knees + zygomatic + mentalis tape for lip seal"
            )
        ]
    }

    // MARK: - Génération protocole

    static func jawAndTongueWork(
        answers: [String: WelcomePlanAnswer],
        includeFullRoutine: Bool = true
    ) -> [String] {
        let faceIds = answers["face_concerns"]?.choiceIds ?? []
        let jawFocus = faceIds.contains(where: {
            $0 == "weak_jaw" || $0 == "double_chin" || $0 == "asymmetry"
        })

        let needsFull = includeFullRoutine
            || choice("mouth_breathing", in: answers) == "yes"
            || choice("forward_head", in: answers) == "yes"
            || jawFocus

        return needsFull ? coreMewingRoutine : lightMewingRoutine
    }

    static func dailyMewingChecks(for answers: [String: WelcomePlanAnswer]) -> [String] {
        var checks: [String] = [
            AppCopy.tSync(
                "Suction mew — \(suctionMewDetail)",
                en: "Suction mew — \(suctionMewDetail)"
            ),
            lipSealDetail
        ]
        if choice("mouth_breathing", in: answers) == "yes" {
            checks.append(AppCopy.tSync(
                "Respiration nasale uniquement — bouche fermée au repos",
                en: "Nasal breathing only — mouth closed at rest"
            ))
        }
        checks.append(AppCopy.tSync(
            "Tongue chewing ~10 min/j — genioglossus / styloglossus",
            en: "Tongue chewing ~10 min/day — genioglossus / styloglossus"
        ))
        return checks
    }

    static func pillarHints(
        mouthBreathing: Bool,
        forwardHead: Bool,
        faceScore: Int?
    ) -> [String] {
        var hints: [String] = []
        hints.append(AppCopy.tSync(
            "Script #9 : langue sur palais 24/7 en suction — pas pousser ; compounding temps",
            en: "Script #9: tongue on palate 24/7 in suction — don't push; time compounds"
        ))
        hints.append(AppCopy.tSync(
            "Suction mew : T → sourire + yeux + swallows jusqu'à vide ; semaine 1 rappel horaire",
            en: "Suction mew: T → smile + eyes + swallows until empty; week 1 hourly reminders"
        ))
        if mouthBreathing || forwardHead {
            hints.append(AppCopy.tSync(
                "Sommeil côté + tapes zyg/mentalis — mewing passif nocturne",
                en: "Side sleep + zyg/mentalis tape — passive nighttime mewing"
            ))
            hints.append(AppCopy.tSync(
                "Tongue tie stretch + tongue chewing avant suction tenable",
                en: "Tongue-tie stretch + tongue chewing before durable suction"
            ))
        }
        if let score = faceScore, score < 65 {
            hints.append(AppCopy.tSync(
                "Maxillaire récessif réversible — thumb pull + ostéoblastes si muscles activés",
                en: "Recessed maxilla is reversible — thumb pull + osteoblasts if muscles are active"
            ))
        }
        return hints
    }

    private static func choice(_ id: String, in answers: [String: WelcomePlanAnswer]) -> String? {
        answers[id]?.choiceIds.first
    }
}
