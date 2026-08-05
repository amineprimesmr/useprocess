import Foundation

/// Règles extraites des scripts Enzo (Plan personnalisé, Masterclass beauté).
enum OriginScriptRulesEngine {

    static func nutritionPrinciples(
        snapshot: OriginPlanAssessmentSnapshot,
        answers: [String: WelcomePlanAnswer]
    ) -> [String] {
        var rules: [String] = []

        if snapshot.bodyFatGap >= 8 {
            rules.append(AppCopy.tSync(
                "Calories denses 2500–3000 kcal — pas de régime 1500 kcal (détruit le visage)",
                en: "Dense calories 2500–3000 kcal — no 1500 kcal diet (destroys the face)"
            ))
        } else if snapshot.bodyFatGap < 3 {
            rules.append(AppCopy.tSync(
                "Maintien calorique via aliments entiers — pas de restriction inutile",
                en: "Calorie maintenance via whole foods — no pointless restriction"
            ))
        }

        if choice("processed_food", in: answers) == "daily" || choice("processed_food", in: answers) == "most_meals" {
            rules.append(AppCopy.tSync(
                "Éradiquer huiles de graines et ultra-transformés en priorité absolue",
                en: "Eliminate seed oils and ultra-processed food as absolute priority"
            ))
        }

        if snapshot.primaryBlocker == .stress || snapshot.primaryBlocker == .sleep {
            rules.append(AppCopy.tSync(
                "Baisser cortisol avant tout — respiration nasale, sommeil, pas de cardio intensif tardif",
                en: "Lower cortisol first — nasal breathing, sleep, no late intense cardio"
            ))
        }

        if snapshot.archetype == .recomposition {
            rules.append(AppCopy.tSync(
                "Déficit uniquement via densité — protéines animales + tubercules à chaque repas principal",
                en: "Deficit only via density — animal protein + tubers at every main meal"
            ))
        }

        if snapshot.archetype == .habitReset {
            rules.append(AppCopy.tSync(
                "Reset debloat : sel modéré le soir + hydratation répartie = résultat visible en jours",
                en: "Debloat reset: moderate evening salt + spread hydration = visible results in days"
            ))
        }

        for rule in GutHealthIntelligenceGuide.nutritionPrinciples(for: answers, snapshot: snapshot) {
            if !rules.contains(rule) {
                rules.insert(rule, at: 0)
            }
        }

        return rules
    }

    static func trainingConstraints(
        snapshot: OriginPlanAssessmentSnapshot,
        answers: [String: WelcomePlanAnswer]
    ) -> [String] {
        var rules: [String] = []

        if snapshot.archetype == .stressRecovery {
            rules.append(AppCopy.tSync(
                "Pas de failure musculaire — RPE 6–7 max tant que le sommeil n'est pas stabilisé",
                en: "No muscular failure — RPE 6–7 max until sleep is stable"
            ))
        }

        if snapshot.bodyFatGap >= 10 {
            rules.append(AppCopy.tSync(
                "Marche quotidienne prioritaire — cardio intensif secondaire",
                en: "Daily walking first — intense cardio secondary"
            ))
        }

        if choice("forward_head", in: answers) == "yes" {
            rules.append(AppCopy.tSync(
                "Chaque séance : face pulls + travail chaîne postérieure avant charges lourdes",
                en: "Every session: face pulls + posterior-chain work before heavy loads"
            ))
            rules.append(AppCopy.tSync(
                "Tête en avant : chin tuck avancé + nuque arrière + orofacial (script #8)",
                en: "Forward head: advanced chin tuck + rear neck + orofacial (script #8)"
            ))
        }

        if choice("mouth_breathing", in: answers) == "yes" {
            rules.append(AppCopy.tSync(
                "Buteyko 3–4 min + respiration nasale avant intensité",
                en: "Buteyko 3–4 min + nasal breathing before intensity"
            ))
        }

        return rules
    }

    static func posturePrinciples(
        snapshot: OriginPlanAssessmentSnapshot,
        answers: [String: WelcomePlanAnswer]
    ) -> [String] {
        var rules: [String] = []

        if snapshot.archetype == .stressRecovery || snapshot.primaryBlocker == .posture {
            rules.append(AppCopy.tSync(
                "Posture fondation — habitudes 24/7 avant exercices avancés (script #7)",
                en: "Posture foundation — 24/7 habits before advanced drills (script #7)"
            ))
        }

        if choice("forward_head", in: answers) == "yes" {
            rules.append(AppCopy.tSync(
                "Thumb pull 8 semaines + langue tiers postérieur — pas seulement chin tuck",
                en: "Thumb pull 8 weeks + posterior-third tongue — not chin tuck alone"
            ))
        }

        if choice("desk_job", in: answers) == "yes" {
            rules.append(AppCopy.tSync(
                "Pause 45 min + marche consciente orteils dedans talons dehors",
                en: "Break every 45 min + mindful walk toes in heels out"
            ))
        }

        return rules
    }

    private static func choice(_ id: String, in answers: [String: WelcomePlanAnswer]) -> String? {
        answers[id]?.choiceIds.first
    }
}
