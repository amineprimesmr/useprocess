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

    static let suctionMewDetail = """
    Suction mew — langue en vide sur le palais (pas poussée) : « T », sourire + yeux ouverts, \
    déglutitions jusqu'à salive épuisée. Semaine 1 : rappel toutes les heures.
    """

    static let lipSealDetail = "Lèvres closes, dents en contact léger — tape zyg + mentalis la nuit si besoin."

    // MARK: - Routine orofaciale (face protocol)

    static let coreMewingRoutine: [String] = [
        "Suction mew — T spot, sourire + yeux hauts, déglutitions jusqu'à vide (matin + soir)",
        "Rééducation semaine 1 — toutes les heures : tenir la suction le plus longtemps possible",
        "Étirement tongue tie — T spot, doigt résistance 70 %, 30 s × 2 séries",
        "Tongue chewing — gomme mastic, pointe langue sur palais ~10 min/j",
        "Thumb pull — 8 semaines (expansion palais, langue comme retainer)"
    ]

    static let lightMewingRoutine: [String] = [
        "Suction mew 2×/jour — T spot + déglutitions conscientes",
        "Langue sur palais à chaque déglutition — lèvres closes"
    ]

    static let sleepMewingSteps: [String] = [
        "Avant coucher : suction mew complète (T + swallows jusqu'à salive épuisée)",
        "Dormir sur le côté — pas sur le dos (langue tombe avec gravité)",
        "Coussin entre genoux + tape zygomatique + mentalis pour lip seal"
    ]

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
            "Suction mew — \(suctionMewDetail)",
            lipSealDetail
        ]
        if choice("mouth_breathing", in: answers) == "yes" {
            checks.append("Respiration nasale uniquement — bouche fermée au repos")
        }
        checks.append("Tongue chewing ~10 min/j — genioglossus / styloglossus")
        return checks
    }

    static func pillarHints(
        mouthBreathing: Bool,
        forwardHead: Bool,
        faceScore: Int?
    ) -> [String] {
        var hints: [String] = []
        hints.append("Script #9 : langue sur palais 24/7 en suction — pas pousser ; compounding temps")
        hints.append("Suction mew : T → sourire + yeux + swallows jusqu'à vide ; semaine 1 rappel horaire")
        if mouthBreathing || forwardHead {
            hints.append("Sommeil côté + tapes zyg/mentalis — mewing passif nocturne")
            hints.append("Tongue tie stretch + tongue chewing avant suction tenable")
        }
        if let score = faceScore, score < 65 {
            hints.append("Maxillaire récessif réversible — thumb pull + ostéoblastes si muscles activés")
        }
        return hints
    }

    private static func choice(_ id: String, in answers: [String: WelcomePlanAnswer]) -> String? {
        answers[id]?.choiceIds.first
    }
}
