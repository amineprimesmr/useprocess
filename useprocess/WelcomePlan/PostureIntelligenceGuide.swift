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
        - Exercices maison : chin tuck (mur/lit), neck curls (tête dans le vide), extension nuque au sol, rétraction scapulaire au mur
        - Corps : APT → étirement fléchisseurs hanche, pont fessier, marche consciente (orteils dedans)
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

    // MARK: - Circuit maison (sans salle — faisable partout)

    static let maleHomeMobilityBlocks: [String] = [
        "Chin tuck — dos au mur ou tête hors lit, 3×10, maintien 2–3 s",
        "Neck curls — buste sur lit ou canapé, tête dans le vide, menton vers poitrine, 3×10–12",
        "Extension nuque (face au sol) — mains au front, 3×10 sans charge",
        "Rétraction scapulaire au mur — bras en Y, omoplates serrées, 2×12",
        "Pont fessier + étirement fléchisseurs hanche — 2×15 + 45 s/jambe"
    ]

    static let femaleHomeMobilityBlocks: [String] = [
        "Chin tuck — assis ou debout, menton rentré, 3×10, maintien 2–3 s",
        "Neck curls — buste sur lit ou canapé, tête dans le vide, menton vers poitrine, 3×10–12",
        "Wall angels — dos au mur, bras en W→Y, 2×10",
        "Pont fessier + clamshell — 2×15 + 12/côté (bassin stable)",
        "Ouverture thoracique au sol — serviette roulée sous omoplates, 2 min"
    ]

    static let neutralHomeMobilityBlocks: [String] = [
        "Chin tuck — debout ou allongé, 3×10, maintien 2–3 s",
        "Neck curls — buste sur lit/canapé, tête dans le vide, 3×10–12",
        "Rétraction scapulaire + wall angels — 2×12",
        "Pont fessier + mobilité hanches — 2×15"
    ]

    static let lightMaleHomeBlocks: [String] = [
        "Chin tuck classique — 2×12, maintien 2–3 s",
        "Neck curls légers — tête hors lit ou canapé, 2×12",
        "Mobilité épaules debout — cercles + rétraction, 2 min"
    ]

    static let lightFemaleHomeBlocks: [String] = [
        "Chin tuck classique — 2×12",
        "Neck curls légers — tête hors lit ou canapé, 2×12",
        "Chat-vache + respiration nasale — 2 min"
    ]

    static let lightNeutralHomeBlocks: [String] = [
        "Chin tuck classique — 2×12",
        "Neck curls légers — tête hors lit ou canapé, 2×12",
        "Mobilité nuque + épaules — 2 min"
    ]

    /// Fallback affichage quand le plan n’a pas encore de blocs persistés.
    static let defaultMobilityBlocks: [String] = maleHomeMobilityBlocks

    static let lightMobilityBlocks: [String] = lightMaleHomeBlocks

    static let aptBodyHomeBlocks: [String] = [
        "Étirement fléchisseurs hanche — fente basse genou au sol, 45 s/jambe",
        "Pont fessier — 2×15, serrer fessiers 2 s en haut",
        "Marche consciente — orteils dedans, talons dehors, abdos légers"
    ]

    static let aptBodyBlocks: [String] = aptBodyHomeBlocks

    // MARK: - Orofacial (lié face protocol)

    static let defaultOrofacialRoutine: [String] = [
        "Étirement platysma — langue sur palais, menton poussé avant / gauche / droite 30 s chaque",
        "Déglutition — sourire large + yeux hauts, 5 déglutitions langue seule",
        "Thumb pull — routine 8 semaines (expansion palais temporaire, langue retainer)",
        "Buteyko — 3–4 min (sutures, fascias, reset CNS)"
    ]

    static let lightOrofacialRoutine: [String] = [
        "Langue sur palais + déglutition correcte à chaque repas"
    ]

    // MARK: - Respiration

    static let buteykoLine = "Buteyko — 3–4 min : exhale complet, apnée, inspire 1 s, apnée 1 s, cycle répété"

    // MARK: - Sommeil posture

    static let sideSleepRoutine: [String] = MewingIntelligenceGuide.sleepMewingSteps

    // MARK: - Génération protocole

    static func mobilityBlocks(for answers: [String: WelcomePlanAnswer], gender: Gender = .male) -> [String] {
        let forwardHead = choice("forward_head", in: answers) == "yes"
        let desk = choice("desk_job", in: answers) == "yes"
        let mouth = choice("mouth_breathing", in: answers) == "yes"
        let useFull = forwardHead || desk

        var blocks = homeMobilityBlocks(gender: gender, full: useFull)

        if forwardHead || desk {
            if useFull {
                if !blocks.contains(where: { $0.localizedCaseInsensitiveContains("fascia") || $0.localizedCaseInsensitiveContains("tennis") }) {
                    blocks.append("Release fascia pieds — balle ou tennis, 1 min/pied")
                }
            } else {
                blocks.append(contentsOf: aptBodyHomeBlocks.filter { line in
                    !blocks.contains(where: { existing in
                        existing.localizedCaseInsensitiveContains("Pont fessier") && line.localizedCaseInsensitiveContains("Pont fessier")
                    })
                })
            }
        }

        if mouth, !blocks.contains(where: { $0.localizedCaseInsensitiveContains("Buteyko") }) {
            blocks.append(buteykoLine)
        }

        return blocks
    }

    private static func homeMobilityBlocks(gender: Gender, full: Bool) -> [String] {
        switch gender {
        case .female:
            return full ? femaleHomeMobilityBlocks : lightFemaleHomeBlocks
        case .male:
            return full ? maleHomeMobilityBlocks : lightMaleHomeBlocks
        case .other, .preferNotToSay:
            return full ? neutralHomeMobilityBlocks : lightNeutralHomeBlocks
        }
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
        _ = answers
        return []
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
            notes.append("Chaque séance : mobilité nuque + rétraction scapulaire avant les charges")
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
