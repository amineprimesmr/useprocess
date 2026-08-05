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
        AppCopy.tSync(
            "Nuque droite assis/debout/marcher — pas chin tuck permanent, pas tête en avant.",
            en: "Upright neck sitting/standing/walking — no permanent chin tuck, no forward head."
        )
    }

    static var walkingGaitDetail: String {
        AppCopy.tSync(
            "Marcher orteils vers l'intérieur, talons vers l'extérieur, abdos légèrement engagés — pas pieds en duck.",
            en: "Walk toes inward, heels outward, abs lightly engaged — no duck feet."
        )
    }

    static var barefootDetail: String {
        AppCopy.tSync(
            "Pieds nus ou chaussures barefoot ~30 min/j — activation muscles intrinsiques des pieds.",
            en: "Barefoot or barefoot shoes ~30 min/day — activate intrinsic foot muscles."
        )
    }

    // MARK: - Circuit maison (sans salle — faisable partout)

    static var maleHomeMobilityBlocks: [String] {
        [
            AppCopy.tSync(
                "Chin tuck — dos au mur ou tête hors lit, 3×10, maintien 2–3 s",
                en: "Chin tuck — back to wall or head off bed, 3×10, hold 2–3 s"
            ),
            AppCopy.tSync(
                "Extension nuque — mains au front, 3×10 sans charge",
                en: "Neck extension — hands on forehead, 3×10 unloaded"
            ),
            AppCopy.tSync(
                "Rétraction scapulaire au mur — bras en Y, omoplates serrées, 2×12",
                en: "Scapular retraction at wall — arms in Y, squeeze shoulder blades, 2×12"
            ),
            AppCopy.tSync(
                "Pont fessier + étirement fléchisseurs hanche — 2×15 + 45 s/jambe",
                en: "Glute bridge + hip-flexor stretch — 2×15 + 45 s/leg"
            )
        ]
    }

    static var femaleHomeMobilityBlocks: [String] {
        [
            AppCopy.tSync(
                "Chin tuck — assis ou debout, menton rentré, 3×10, maintien 2–3 s",
                en: "Chin tuck — seated or standing, chin tucked, 3×10, hold 2–3 s"
            ),
            AppCopy.tSync(
                "Wall angels — dos au mur, bras en W→Y, 2×10",
                en: "Wall angels — back to wall, arms W→Y, 2×10"
            ),
            AppCopy.tSync(
                "Pont fessier + clamshell — 2×15 + 12/côté (bassin stable)",
                en: "Glute bridge + clamshell — 2×15 + 12/side (stable pelvis)"
            ),
            AppCopy.tSync(
                "Ouverture thoracique au sol — serviette roulée sous omoplates, 2 min",
                en: "Thoracic opener on floor — rolled towel under shoulder blades, 2 min"
            )
        ]
    }

    static var neutralHomeMobilityBlocks: [String] {
        [
            AppCopy.tSync(
                "Chin tuck — debout ou allongé, 3×10, maintien 2–3 s",
                en: "Chin tuck — standing or lying, 3×10, hold 2–3 s"
            ),
            AppCopy.tSync(
                "Extension nuque — mains au front, 3×10 sans charge",
                en: "Neck extension — hands on forehead, 3×10 unloaded"
            ),
            AppCopy.tSync(
                "Rétraction scapulaire + wall angels — 2×12",
                en: "Scapular retraction + wall angels — 2×12"
            ),
            AppCopy.tSync(
                "Pont fessier + mobilité hanches — 2×15",
                en: "Glute bridge + hip mobility — 2×15"
            )
        ]
    }

    static var lightMaleHomeBlocks: [String] {
        [
            AppCopy.tSync(
                "Chin tuck classique — 2×12, maintien 2–3 s",
                en: "Classic chin tuck — 2×12, hold 2–3 s"
            ),
            AppCopy.tSync(
                "Mobilité épaules debout — cercles + rétraction, 2 min",
                en: "Standing shoulder mobility — circles + retraction, 2 min"
            )
        ]
    }

    static var lightFemaleHomeBlocks: [String] {
        [
            AppCopy.tSync("Chin tuck classique — 2×12", en: "Classic chin tuck — 2×12"),
            AppCopy.tSync(
                "Chat-vache + respiration nasale — 2 min",
                en: "Cat-cow + nasal breathing — 2 min"
            )
        ]
    }

    static var lightNeutralHomeBlocks: [String] {
        [
            AppCopy.tSync("Chin tuck classique — 2×12", en: "Classic chin tuck — 2×12"),
            AppCopy.tSync(
                "Mobilité nuque + épaules — 2 min",
                en: "Neck + shoulder mobility — 2 min"
            )
        ]
    }

    /// Fallback affichage quand le plan n’a pas encore de blocs persistés.
    static var defaultMobilityBlocks: [String] { maleHomeMobilityBlocks }

    static var lightMobilityBlocks: [String] { lightMaleHomeBlocks }

    static var aptBodyHomeBlocks: [String] {
        [
            AppCopy.tSync(
                "Étirement fléchisseurs hanche — fente basse genou au sol, 45 s/jambe",
                en: "Hip-flexor stretch — low lunge knee down, 45 s/leg"
            ),
            AppCopy.tSync(
                "Pont fessier — 2×15, serrer fessiers 2 s en haut",
                en: "Glute bridge — 2×15, squeeze glutes 2 s at top"
            ),
            AppCopy.tSync(
                "Marche consciente — orteils dedans, talons dehors, abdos légers",
                en: "Mindful walk — toes in, heels out, light abs"
            )
        ]
    }

    static var aptBodyBlocks: [String] { aptBodyHomeBlocks }

    // MARK: - Orofacial (lié face protocol)

    static var defaultOrofacialRoutine: [String] {
        [
            AppCopy.tSync(
                "Étirement platysma — langue sur palais, menton poussé avant / gauche / droite 30 s chaque",
                en: "Platysma stretch — tongue on palate, chin pushed forward / left / right 30 s each"
            ),
            AppCopy.tSync(
                "Déglutition — sourire large + yeux hauts, 5 déglutitions langue seule",
                en: "Swallow — wide smile + eyes up, 5 tongue-only swallows"
            ),
            AppCopy.tSync(
                "Thumb pull — routine 8 semaines (expansion palais temporaire, langue retainer)",
                en: "Thumb pull — 8-week routine (temporary palate expansion, tongue retainer)"
            ),
            AppCopy.tSync(
                "Buteyko — 3–4 min (sutures, fascias, reset CNS)",
                en: "Buteyko — 3–4 min (sutures, fascia, CNS reset)"
            )
        ]
    }

    static var lightOrofacialRoutine: [String] {
        [
            AppCopy.tSync(
                "Langue sur palais + déglutition correcte à chaque repas",
                en: "Tongue on palate + correct swallow at every meal"
            )
        ]
    }

    // MARK: - Respiration

    static var buteykoLine: String {
        AppCopy.tSync(
            "Buteyko — 3–4 min : exhale complet, apnée, inspire 1 s, apnée 1 s, cycle répété",
            en: "Buteyko — 3–4 min: full exhale, hold, inhale 1 s, hold 1 s, repeat cycle"
        )
    }

    // MARK: - Sommeil posture

    static var sideSleepRoutine: [String] { MewingIntelligenceGuide.sleepMewingSteps }

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
                    blocks.append(AppCopy.tSync(
                        "Release fascia pieds — balle ou tennis, 1 min/pied",
                        en: "Foot fascia release — ball or tennis, 1 min/foot"
                    ))
                }
            } else {
                blocks.append(contentsOf: aptBodyHomeBlocks.filter { line in
                    !blocks.contains(where: { existing in
                        (existing.localizedCaseInsensitiveContains("Pont fessier") || existing.localizedCaseInsensitiveContains("Glute bridge"))
                            && (line.localizedCaseInsensitiveContains("Pont fessier") || line.localizedCaseInsensitiveContains("Glute bridge"))
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
        checks.append(AppCopy.tSync(
            "Nuque droite — \(neckAlignmentDetail)",
            en: "Upright neck — \(neckAlignmentDetail)"
        ))
        checks.append(AppCopy.tSync(
            "Posture langue — \(tonguePostureDetail)",
            en: "Tongue posture — \(tonguePostureDetail)"
        ))

        if choice("forward_head", in: answers) == "yes" {
            checks.append(AppCopy.tSync(
                "Tête en avant : cause orofaciale — langue + thumb pull 8 sem, pas seulement chin tuck",
                en: "Forward head: orofacial cause — tongue + thumb pull 8 wk, not chin tuck alone"
            ))
        }
        if choice("desk_job", in: answers) == "yes" {
            checks.append(AppCopy.tSync(
                "Pause posture toutes les 45 min — se redresser, respiration nasale",
                en: "Posture break every 45 min — stand tall, nasal breathing"
            ))
            checks.append(walkingGaitDetail)
        }
        if choice("mouth_breathing", in: answers) == "yes" {
            checks.append(AppCopy.tSync(
                "Respiration nasale en permanence — réduit gonflement et cortisol",
                en: "Nasal breathing at all times — reduces puffiness and cortisol"
            ))
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
                work.append(AppCopy.tSync(
                    "Étirement platysma — langue palais, menton F/L/R 30 s",
                    en: "Platysma stretch — tongue palate, chin F/L/R 30 s"
                ))
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
            notes.append(AppCopy.tSync(
                "Chaque séance : mobilité nuque + rétraction scapulaire avant les charges",
                en: "Every session: neck mobility + scapular retraction before loads"
            ))
        }
        notes.append(AppCopy.tSync(
            "Sprints fonctionnels — 8×15 s, repos 1m30 (option matin pour GH)",
            en: "Functional sprints — 8×15 s, rest 1:30 (morning option for GH)"
        ))
        return notes
    }

    static func pillarHintsForwardHead(
        forwardHeadLikely: Bool,
        mouthBreathing: Bool,
        postureScore: Int?
    ) -> [String] {
        var hints: [String] = []
        if forwardHeadLikely || (postureScore ?? 100) < 65 {
            hints.append(AppCopy.tSync(
                "Script #8 : tête en avant = compensation airways — traiter orofacial + structure, pas seulement chin tuck",
                en: "Script #8: forward head = airway compensation — treat orofacial + structure, not chin tuck alone"
            ))
            hints.append(AppCopy.tSync(
                "Chin tuck avancé + nuque arrière + thumb pull 8 sem + langue sur palais",
                en: "Advanced chin tuck + rear neck + thumb pull 8 wk + tongue on palate"
            ))
        }
        if mouthBreathing {
            hints.append(AppCopy.tSync(
                "Respiration buccale : orbicularis oris sous-actif — CPS/balloon hold + Buteyko",
                en: "Mouth breathing: underactive orbicularis oris — CPS/balloon hold + Buteyko"
            ))
        }
        if forwardHeadLikely {
            hints.append(AppCopy.tSync(
                "APT souvent associé — RSS fessiers + marche consciente",
                en: "APT often linked — glute RSS + mindful walking"
            ))
        }
        return hints
    }

    private static func choice(_ id: String, in answers: [String: WelcomePlanAnswer]) -> String? {
        answers[id]?.choiceIds.first
    }
}
