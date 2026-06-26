import Foundation

/// Intelligence posture — scripts fondation (#07) + tête en avant orofaciale (#08).
/// Source unique pour protocole plan, face protocol, sommeil et prompts coach.
enum PostureIntelligenceGuide {

    // MARK: - Principes coach (injectés dans EnzoCoachingVoiceGuide)

    static let coachingPrinciplesBlock =
        """
        POSTURE — SCRIPTS #7 + #8 (fondation + tête en avant) :
        - Posture = fondation visage + santé — chaîne pieds → bassin → dos → nuque → tête → maxillaire → respiration
        - Tête en avant = compensation airways étroites (palais récessif) — pas seulement « muscles faibles »
        - Chin tucks seuls insuffisants sans habitudes orofaciales (langue, déglution, respiration nasale)
        - Nuque droite 24/7 (pas chin tuck permanent) — SCM sur-sollicité = boucle tête en avant
        - Exercices : chin tuck avancé (lit/banc 3×8–10), extension nuque dos (3×10), face pulls (2–3×10–12)
        - Corps : APT → RSS (release fascias, stretch hip flexors, strengthen glutes) ; marcher orteils dedans talons dehors
        - Pieds nus ~30 min/j — muscles intrinsiques = fondation squelette
        - Sommeil latéral : coussin tête + entre genoux + à hugger — airways ouvertes
        - Langue tiers postérieur sur palais, dents en contact léger — 2 semaines conscience active
        - Thumb pull 8 semaines + Buteyko 3–4 min pour sutures/fascias
        - Ordre : muscles correctifs → structure (orofacial) → habitudes passives permanentes
        """

    // MARK: - Habitudes continues (complément ProcessContinuousHabits)

    static var tonguePostureDetail: String {
        MewingIntelligenceGuide.suctionMewDetail
    }

    static var neckAlignmentDetail: String {
        "Nuque droite assis/debout/marcher — pas chin tuck permanent, pas tête en avant."
    }

    static var walkingGaitDetail: String {
        "Marcher orteils vers l'intérieur, talons vers l'extérieur, abdos légèrement engagés — pas pieds en duck."
    }

    static var barefootDetail: String {
        "Pieds nus ou chaussures barefoot ~30 min/j — activation muscles intrinsiques des pieds."
    }

    // MARK: - Blocs mobilité / correctifs (circuit quotidien Plan)

    static let defaultMobilityBlocks: [String] = [
        "Chin tuck avancé — tête hors lit/banc, 3×8–10, maintien 2–3 s au fond",
        "Extension nuque (dos) — sur ventre, 3×10 résistance mains ou plaque légère",
        "Face pulls — 2–3×10–12 (câble ou élastique)",
        "Mobilité épaules + hanches — 2 min"
    ]

    static let lightMobilityBlocks: [String] = [
        "Chin tuck classique — 2–3×12, maintien 2–3 s (pas 24h/24)",
        "Face pulls léger — 2×12",
        "Mobilité épaules — 1–2 min"
    ]

    static let aptBodyBlocks: [String] = [
        "RSS bassin — tennis ball fascias pieds/fessiers, étirement fléchisseurs hanche, activation fessiers",
        "Marche consciente — orteils dedans, talons dehors, abdos légers"
    ]

    // MARK: - Orofacial (lié face protocol)

    static let defaultOrofacialRoutine: [String] = [
        "Étirement platysma — langue sur palais, menton poussé avant / gauche / droite 30 s chaque",
        "Déglutition — sourire large + yeux hauts, 5 déglutitions langue seule",
        "Thumb pull — routine 8 semaines (expansion palais temporaire, langue retainer)",
        "Buteyko — 3–4 min (sutures, fascias, reset CNS)"
    ]

    static let lightOrofacialRoutine: [String] = [
        "Langue sur palais + déglutition correcte à chaque repas",
        "Respiration nasale lente 5 min matin et soir"
    ]

    // MARK: - Respiration

    static let buteykoLine = "Buteyko — 3–4 min : exhale complet, apnée, inspire 1 s, apnée 1 s, cycle répété"
    static let nasalBreathingLine = "Respiration nasale lente 5 min matin et soir — posture et cage thoracique"

    // MARK: - Sommeil posture

    static let sideSleepRoutine: [String] = MewingIntelligenceGuide.sleepMewingSteps

    // MARK: - Génération protocole

    static func mobilityBlocks(for answers: [String: WelcomePlanAnswer]) -> [String] {
        let forwardHead = choice("forward_head", in: answers) == "yes"
        let desk = choice("desk_job", in: answers) == "yes"
        let mouth = choice("mouth_breathing", in: answers) == "yes"

        var blocks = forwardHead || desk ? defaultMobilityBlocks : lightMobilityBlocks
        if forwardHead || desk {
            blocks.append(contentsOf: aptBodyBlocks)
        }
        if mouth {
            if !blocks.contains(where: { $0.localizedCaseInsensitiveContains("Buteyko") }) {
                blocks.append(buteykoLine)
            }
        }
        return blocks
    }

    static func dailyChecks(
        answers: [String: WelcomePlanAnswer],
        existingContinuous: [String]
    ) -> [String] {
        var checks = existingContinuous
        checks.append("Nuque droite — \(neckAlignmentDetail)")
        checks.append("Posture langue — \(tonguePostureDetail)")

        if choice("forward_head", in: answers) == "yes" {
            checks.append("Tête en avant : cause orofaciale — langue + thumb pull 8 sem, pas seulement chin tuck")
        }
        if choice("desk_job", in: answers) == "yes" {
            checks.append("Pause posture toutes les 45 min — se redresser, respiration nasale")
            checks.append(walkingGaitDetail)
        }
        if choice("mouth_breathing", in: answers) == "yes" {
            checks.append("Respiration nasale en permanence — réduit gonflement et cortisol")
        }
        checks.append(barefootDetail)

        if choice("forward_head", in: answers) == "yes" || choice("mouth_breathing", in: answers) == "yes" {
            for item in MewingIntelligenceGuide.dailyMewingChecks(for: answers) {
                if !checks.contains(item) {
                    checks.append(item)
                }
            }
        }
        return checks
    }

    static func breathingWork(for answers: [String: WelcomePlanAnswer]) -> [String] {
        var work: [String] = []
        if choice("mouth_breathing", in: answers) == "yes" {
            work.append(nasalBreathingLine)
            work.append(buteykoLine)
        } else if choice("forward_head", in: answers) == "yes" {
            work.append(nasalBreathingLine)
        }
        return work
    }

    static func orofacialWork(for answers: [String: WelcomePlanAnswer]) -> [String] {
        let forwardHead = choice("forward_head", in: answers) == "yes"
        let mouth = choice("mouth_breathing", in: answers) == "yes"
        var work = MewingIntelligenceGuide.jawAndTongueWork(
            answers: answers,
            includeFullRoutine: forwardHead || mouth
        )
        if forwardHead || mouth {
            if !work.contains(where: { $0.localizedCaseInsensitiveContains("platysma") }) {
                work.append("Étirement platysma — langue palais, menton F/L/R 30 s")
            }
            if !work.contains(where: { $0.localizedCaseInsensitiveContains("Buteyko") }) {
                work.append(buteykoLine)
            }
        }
        return work
    }

    static func eveningSleepPostureNotes() -> [String] {
        []
    }

    static func trainingPostureNotes(for answers: [String: WelcomePlanAnswer]) -> [String] {
        var notes: [String] = []
        if choice("forward_head", in: answers) == "yes" {
            notes.append("Chaque séance : face pulls + chaîne postérieure avant charges lourdes")
        }
        notes.append("Sprints fonctionnels — 8×15 s, repos 1m30 (option matin pour GH)")
        return notes
    }

    static func pillarHintsForwardHead(
        forwardHeadLikely: Bool,
        mouthBreathing: Bool,
        postureScore: Int?
    ) -> [String] {
        var hints: [String] = []
        if forwardHeadLikely || (postureScore ?? 100) < 65 {
            hints.append("Script #8 : tête en avant = compensation airways — traiter orofacial + structure, pas seulement chin tuck")
            hints.append("Chin tuck avancé + nuque arrière + thumb pull 8 sem + langue sur palais")
        }
        if mouthBreathing {
            hints.append("Respiration buccale : orbicularis oris sous-actif — CPS/balloon hold + Buteyko")
        }
        if forwardHeadLikely {
            hints.append("APT souvent associé — RSS fessiers + marche consciente")
        }
        return hints
    }

    private static func choice(_ id: String, in answers: [String: WelcomePlanAnswer]) -> String? {
        answers[id]?.choiceIds.first
    }
}
