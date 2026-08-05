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

    static var foodsToAvoid: [String] {
        [
            AppCopy.tSync("Ultra-transformés et huiles de graines", en: "Ultra-processed foods and seed oils"),
            AppCopy.tSync("Grains (lectines, gluten, phytates)", en: "Grains (lectins, gluten, phytates)"),
            AppCopy.tSync("Légumes verts feuillus (oxalates élevés)", en: "Leafy greens (high oxalates)"),
            AppCopy.tSync("Noix et soja (antinutriments)", en: "Nuts and soy (antinutrients)"),
            AppCopy.tSync("Lait A1 (lait industriel standard — BCM-7)", en: "A1 milk (standard industrial milk — BCM-7)"),
            AppCopy.tSync("Alcool — priorité absolue à couper", en: "Alcohol — absolute priority to cut")
        ]
    }

    static var foodsToPrioritize: [String] {
        [
            AppCopy.tSync("Bouillon d'os bio grass-fed (matin, semaine reset)", en: "Grass-fed organic bone broth (morning, reset week)"),
            AppCopy.tSync("Lait cru A2 / laitiers anciennes races", en: "Raw A2 milk / heritage dairy"),
            AppCopy.tSync("Viande rouge et abats (foie cru si source fiable)", en: "Red meat and organ meats (raw liver if trusted source)"),
            AppCopy.tSync("Choucroute et aliments fermentés", en: "Sauerkraut and fermented foods"),
            AppCopy.tSync("Fruits — glucides digestes principaux", en: "Fruit — main digestible carbs"),
            AppCopy.tSync("Carottes crues (endotoxines)", en: "Raw carrots (endotoxins)"),
            AppCopy.tSync("Vinaigre de cidre (probiotique)", en: "Apple cider vinegar (probiotic)")
        ]
    }

    static var resetDailyStructure: [String] {
        [
            AppCopy.tSync(
                "Matin : bouillon d'os + sel celtique avant premier repas (phase reset)",
                en: "Morning: bone broth + Celtic salt before first meal (reset phase)"
            ),
            AppCopy.tSync(
                "Repas : protéines animales + fruits + carottes crues",
                en: "Meals: animal protein + fruit + raw carrots"
            ),
            AppCopy.tSync(
                "Limiter féculents (riz, patate) pendant le reset — pas élimination totale long terme",
                en: "Limit starches (rice, potato) during reset — not a long-term total ban"
            ),
            AppCopy.tSync(
                "Eau + électrolytes (sel minéral) — pas dry fast",
                en: "Water + electrolytes (mineral salt) — no dry fast"
            )
        ]
    }

    static var optionalFastNote: String {
        AppCopy.tSync(
            "Option reset : fast eau 24–36 h (autophagy) — pas quotidien, sel celtique sous la langue",
            en: "Reset option: 24–36 h water fast (autophagy) — not daily, Celtic salt under the tongue"
        )
    }

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
            AppCopy.tSync(
                "Intestin = centre de commande — peau et énergie suivent la muqueuse",
                en: "Gut = command center — skin and energy follow the mucosa"
            )
        ]

        if choice("processed_food", in: answers) == "daily" || choice("processed_food", in: answers) == "most_meals" {
            rules.append(AppCopy.tSync(
                "Éviter antinutriments (grains, légumes verts, noix, soja) + huiles de graines",
                en: "Avoid antinutrients (grains, leafy greens, nuts, soy) + seed oils"
            ))
            rules.append(AppCopy.tSync(
                "Lait A2 cru uniquement — pas lait A1 industriel",
                en: "Raw A2 milk only — no industrial A1 milk"
            ))
        }

        if choice("alcohol_frequency", in: answers) == "often" || choice("alcohol_frequency", in: answers) == "weekly" {
            rules.append(AppCopy.tSync(
                "Alcool annule le reset intestin — couper complètement en phase protocole",
                en: "Alcohol cancels gut reset — cut completely during protocol phase"
            ))
        }

        if snapshot.primaryBlocker == .nutrition || snapshot.archetype == .habitReset {
            rules.append(AppCopy.tSync(
                "Reset gut : bouillon d'os matin + carottes crues + probiotiques",
                en: "Gut reset: morning bone broth + raw carrots + probiotics"
            ))
        }

        let faceIds = answers["face_concerns"]?.choiceIds ?? []
        if faceIds.contains("acne") || faceIds.contains("dull_skin") || faceIds.contains("puffiness") {
            rules.append(AppCopy.tSync(
                "Peau = reflet intestin — probiotiques + muqueuse avant skincare",
                en: "Skin = gut reflection — probiotics + mucosa before skincare"
            ))
        }

        return rules
    }

    static func sleepNotesForGutReset() -> [String] {
        [
            AppCopy.tSync(
                "7–9 h de sommeil — mélatonine répare muqueuse (tight junctions)",
                en: "7–9 h sleep — melatonin repairs mucosa (tight junctions)"
            ),
            AppCopy.tSync(
                "Coucher avant 23 h + lunettes anti-lumière bleue le soir",
                en: "Bed before 11 pm + blue-light glasses in the evening"
            )
        ]
    }

    static func pillarHints(
        skinClarityLow: Bool,
        puffinessHigh: Bool,
        processedFoodHeavy: Bool
    ) -> [String] {
        var hints: [String] = []
        hints.append(AppCopy.tSync(
            "Script #10 : intestin → peau, humeur, inflammation — pas de suppléments sans reset alimentaire",
            en: "Script #10: gut → skin, mood, inflammation — no supplements without food reset"
        ))
        if processedFoodHeavy {
            hints.append(AppCopy.tSync(
                "Couper grains/légumes verts/noix/soja + huiles de graines + lait A1",
                en: "Cut grains/leafy greens/nuts/soy + seed oils + A1 milk"
            ))
        }
        if skinClarityLow || puffinessHigh {
            hints.append(AppCopy.tSync(
                "Acné/gonflement : bouillon d'os + probiotiques + carottes crues + zéro alcool",
                en: "Acne/puffiness: bone broth + probiotics + raw carrots + zero alcohol"
            ))
        }
        hints.append(AppCopy.tSync(
            "Fast eau 24–36 h optionnel → autophagy ; puis bouillon d'os chaque matin 1 semaine",
            en: "Optional 24–36 h water fast → autophagy; then bone broth each morning for 1 week"
        ))
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
