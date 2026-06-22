import Foundation

/// Règles extraites des scripts Enzo (Protocole Origine, Masterclass beauté).
enum OriginScriptRulesEngine {

    static func nutritionPrinciples(
        snapshot: OriginPlanAssessmentSnapshot,
        answers: [String: WelcomePlanAnswer]
    ) -> [String] {
        var rules: [String] = []

        if snapshot.bodyFatGap >= 8 {
            rules.append("Calories denses 2500–3000 kcal — pas de régime 1500 kcal (détruit le visage)")
        } else if snapshot.bodyFatGap < 3 {
            rules.append("Maintien calorique via aliments entiers — pas de restriction inutile")
        }

        if choice("processed_food", in: answers) == "daily" || choice("processed_food", in: answers) == "most_meals" {
            rules.append("Éradiquer huiles de graines et ultra-transformés en priorité absolue")
        }

        if snapshot.primaryBlocker == .stress || snapshot.primaryBlocker == .sleep {
            rules.append("Baisser cortisol avant tout — respiration nasale, sommeil, pas de cardio intensif tardif")
        }

        if snapshot.archetype == .recomposition {
            rules.append("Déficit uniquement via densité — protéines animales + tubercules à chaque repas principal")
        }

        if snapshot.archetype == .habitReset {
            rules.append("Reset debloat : sel modéré le soir + hydratation répartie = résultat visible en jours")
        }

        return rules
    }

    static func trainingConstraints(
        snapshot: OriginPlanAssessmentSnapshot,
        answers: [String: WelcomePlanAnswer]
    ) -> [String] {
        var rules: [String] = []

        if snapshot.archetype == .stressRecovery {
            rules.append("Pas de failure musculaire — RPE 6–7 max tant que le sommeil n'est pas stabilisé")
        }

        if snapshot.bodyFatGap >= 10 {
            rules.append("Marche quotidienne prioritaire — cardio intensif secondaire")
        }

        if choice("forward_head", in: answers) == "yes" {
            rules.append("Chaque séance : face pulls + travail chaîne postérieure avant charges lourdes")
        }

        return rules
    }

    private static func choice(_ id: String, in answers: [String: WelcomePlanAnswer]) -> String? {
        answers[id]?.choiceIds.first
    }
}
