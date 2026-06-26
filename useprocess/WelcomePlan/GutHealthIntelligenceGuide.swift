import Foundation

/// Intelligence santé intestinale — script #10 (reset gut, anti-nutriments, A2, autophagy).
enum GutHealthIntelligenceGuide {

    static let coachingPrinciplesBlock = """
    INTESTIN — SCRIPT #10 (command center corps) :
    - Intestin lié peau, cerveau, humeur, énergie, inflammation systémique — pas de suppléments miracles
    - Pas de règle 80/20 — alimentation propre constante ; couper ultra-transformés
    - Antinutriments à éviter : lectines, oxalates, phytates, gluten → grains, légumes verts feuillus, noix, soja
    - Huiles de graines = inflammation + pyrins → muqueuse intestinale
    - Lait A1 (BCM-7) vs A2 cru bio — mutation génétique vaches A1, pas digestion optimale
    - Reset : fast eau 24–48 h + sel celtique → autophagy ; puis bouillon d'os matin 1 semaine
    - Probiotiques : choucroute, lait cru A2, foie cru (source grass-fed), viande rouge, vinaigre cidre
    - Glucides reset : fruits principaux — limiter riz/patate court terme (pas keto extrême)
    - Carottes crues journée — lient endotoxines, accélèrent reset muqueuse
    - Sommeil 7–9 h avant 23 h + mélatonine (tight junctions) ; alcool = progrès annulés
    """

    static let foodsToAvoid: [String] = [
        "Ultra-transformés et huiles de graines",
        "Grains (lectines, gluten, phytates)",
        "Légumes verts feuillus (oxalates élevés)",
        "Noix et soja (antinutriments)",
        "Lait A1 (lait industriel standard — BCM-7)",
        "Alcool — priorité absolue à couper"
    ]

    static let foodsToPrioritize: [String] = [
        "Bouillon d'os bio grass-fed (matin, semaine reset)",
        "Lait cru A2 / laitiers anciennes races",
        "Viande rouge et abats (foie cru si source fiable)",
        "Choucroute et aliments fermentés",
        "Fruits — glucides digestes principaux",
        "Carottes crues (endotoxines)",
        "Vinaigre de cidre (probiotique)"
    ]

    static let resetDailyStructure: [String] = [
        "Matin : bouillon d'os + sel celtique avant premier repas (phase reset)",
        "Repas : protéines animales + fruits + carottes crues",
        "Limiter féculents (riz, patate) pendant le reset — pas élimination totale long terme",
        "Eau + électrolytes (sel minéral) — pas dry fast"
    ]

    static let optionalFastNote = "Option reset : fast eau 24–36 h (autophagy) — pas quotidien, sel celtique sous la langue"

    // MARK: - Génération protocole

    static func enrichNutritionProtocol(
        _ nutrition: inout OriginNutritionProtocol,
        answers: [String: WelcomePlanAnswer],
        snapshot: OriginPlanAssessmentSnapshot
    ) {
        for item in foodsToAvoid {
            if !nutrition.foodsToReduce.contains(item) {
                nutrition.foodsToReduce.append(item)
            }
        }

        for item in foodsToPrioritize {
            if !nutrition.foodsToPrioritize.contains(item) {
                nutrition.foodsToPrioritize.append(item)
            }
        }

        for principle in nutritionPrinciples(for: answers, snapshot: snapshot) {
            if !nutrition.principles.contains(principle) {
                nutrition.principles.insert(principle, at: 0)
            }
        }

        if needsGutReset(answers: answers, snapshot: snapshot) {
            for line in resetDailyStructure {
                if !nutrition.dailyStructure.contains(line) {
                    nutrition.dailyStructure.insert(line, at: 0)
                }
            }
            if !nutrition.principles.contains(optionalFastNote) {
                nutrition.principles.append(optionalFastNote)
            }
        }
    }

    static func nutritionPrinciples(
        for answers: [String: WelcomePlanAnswer],
        snapshot: OriginPlanAssessmentSnapshot
    ) -> [String] {
        var rules: [String] = [
            "Intestin = centre de commande — peau et énergie suivent la muqueuse"
        ]

        if choice("processed_food", in: answers) == "daily" || choice("processed_food", in: answers) == "most_meals" {
            rules.append("Éviter antinutriments (grains, légumes verts, noix, soja) + huiles de graines")
            rules.append("Lait A2 cru uniquement — pas lait A1 industriel")
        }

        if choice("alcohol_frequency", in: answers) == "often" || choice("alcohol_frequency", in: answers) == "weekly" {
            rules.append("Alcool annule le reset intestin — couper complètement en phase protocole")
        }

        if snapshot.primaryBlocker == .nutrition || snapshot.archetype == .habitReset {
            rules.append("Reset gut : bouillon d'os matin + carottes crues + probiotiques")
        }

        let faceIds = answers["face_concerns"]?.choiceIds ?? []
        if faceIds.contains("acne") || faceIds.contains("dull_skin") || faceIds.contains("puffiness") {
            rules.append("Peau = reflet intestin — probiotiques + muqueuse avant skincare")
        }

        return rules
    }

    static func sleepNotesForGutReset() -> [String] {
        [
            "7–9 h de sommeil — mélatonine répare muqueuse (tight junctions)",
            "Coucher avant 23 h + lunettes anti-lumière bleue le soir"
        ]
    }

    static func pillarHints(
        skinClarityLow: Bool,
        puffinessHigh: Bool,
        processedFoodHeavy: Bool
    ) -> [String] {
        var hints: [String] = []
        hints.append("Script #10 : intestin → peau, humeur, inflammation — pas de suppléments sans reset alimentaire")
        if processedFoodHeavy {
            hints.append("Couper grains/légumes verts/noix/soja + huiles de graines + lait A1")
        }
        if skinClarityLow || puffinessHigh {
            hints.append("Acné/gonflement : bouillon d'os + probiotiques + carottes crues + zéro alcool")
        }
        hints.append("Fast eau 24–36 h optionnel → autophagy ; puis bouillon d'os chaque matin 1 semaine")
        return hints
    }

    static func needsGutReset(
        answers: [String: WelcomePlanAnswer],
        snapshot: OriginPlanAssessmentSnapshot
    ) -> Bool {
        snapshot.archetype == .habitReset
            || snapshot.primaryBlocker == .nutrition
            || choice("processed_food", in: answers) == "daily"
            || choice("processed_food", in: answers) == "most_meals"
            || choice("alcohol_frequency", in: answers) == "often"
    }

    private static func choice(_ id: String, in answers: [String: WelcomePlanAnswer]) -> String? {
        answers[id]?.choiceIds.first
    }
}
