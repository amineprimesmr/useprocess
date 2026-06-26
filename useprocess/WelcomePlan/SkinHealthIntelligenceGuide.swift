import Foundation

/// Intelligence peau claire — script #11 (acné, rosacea, eczéma = santé interne).
enum SkinHealthIntelligenceGuide {

    static let coachingPrinciplesBlock = """
    PEAU — SCRIPT #11 (acné/rosacea/eczéma = scam skincare) :
    - Pas de « type de peau » — peau reflète santé intestin, hormones, toxines
    - Pas 80/20 — engagement alimentaire total ; cravings = intestin déséquilibré
    - Viande + œufs + gras saturés (stéroïdogenèse) ; lait A2 cru (mouton idéal)
    - Fruits glucides principaux si actif ; suif pour cuisson — pas huiles graines/olive en poêle
    - Huîtres/abats — micronutriments ; reset intestin 8+ sem, peau stable 3–4 mois constant
    - Filtre douche obligatoire — eau robinet toxique peau + hormones
    - Pas crèmes skincare commerciales — organe comme foie, soigner de l'intérieur
    - Topiques ok : suif, coco, crème coco crue ; hydratation via fruits/lait pas litres d'eau plate
    - Électrolytes naturels (sel, aliments) — pas sachets ; pas suppléments isolés
    - Ponctuel : crème soufre sur bouton ; spray sel celtique après douche filtrée
    """

    static let lymphAndSkinRoutine: [String] = [
        "Filtre douche — eau sans chlore/fluor sur peau et cheveux",
        "Pas crèmes skincare commerciales — racine = alimentation + intestin",
        "Topique si besoin : suif ou crème coco crue (non comédogène)",
        "Eau froide visage au réveil — drainage lymphatique",
        "Spray sel celtique + eau après douche (exfoliation naturelle)",
        "Soleil modéré — peau reflète santé interne"
    ]

    static let skinTimelineNote = "Peau claire : 8+ semaines minimum constant — 3–4 mois pour stabiliser (pas cheat meals)"

    static let dietPrinciplesForSkin: [String] = [
        "Viande + œufs quotidiens — gras saturés pour hormones",
        "Lait A2 cru — pas lait A1 industriel",
        "Cuisson en suif — pas huiles de graines",
        "Fruits + hydratation alimentaire — pas excès eau plate sans électrolytes"
    ]

    // MARK: - Génération protocole

    static func enrichFaceProtocol(
        _ face: inout OriginFaceProtocol,
        answers: [String: WelcomePlanAnswer],
        coldRinseSeconds: Int,
        lymphMinutes: Int,
        dailySteps: Int,
        hydrationLabel: String
    ) {
        let skinFocus = hasSkinConcern(answers)

        for line in lymphAndSkinRoutine {
            if !face.lymphAndFascia.contains(line) {
                face.lymphAndFascia.append(line)
            }
        }

        if skinFocus {
            if !face.lymphAndFascia.contains(where: { $0.contains("Eau froide") }) {
                face.lymphAndFascia.insert(
                    "Eau froide sur le visage \(coldRinseSeconds) sec au réveil",
                    at: 0
                )
            }
            if !face.lymphAndFascia.contains(where: { $0.contains("Massage") }) {
                face.lymphAndFascia.append("Massage doux sous-orbital — \(lymphMinutes) min")
            }
            if !face.lymphAndFascia.contains(where: { $0.contains("Marche") }) {
                face.lymphAndFascia.append(
                    "Marche \(dailySteps) pas + \(hydrationLabel) alimentaire = drainage + peau"
                )
            }
            if !face.jawAndTongueWork.contains(skinTimelineNote) {
                face.jawAndTongueWork.append(skinTimelineNote)
            }
            for principle in dietPrinciplesForSkin {
                if !face.jawAndTongueWork.contains(principle) {
                    face.jawAndTongueWork.append(principle)
                }
            }
        }
    }

    static func enrichNutritionForSkin(
        _ nutrition: inout OriginNutritionProtocol,
        answers: [String: WelcomePlanAnswer]
    ) {
        guard hasSkinConcern(answers) else { return }

        for principle in dietPrinciplesForSkin {
            if !nutrition.principles.contains(principle) {
                nutrition.principles.insert(principle, at: 0)
            }
        }

        let skinFoods = ["Viande rouge et œufs", "Lait A2 cru / mouton", "Fruits frais", "Suif (cuisson)"]
        for food in skinFoods {
            if !nutrition.foodsToPrioritize.contains(food) {
                nutrition.foodsToPrioritize.append(food)
            }
        }

        let avoid = ["Skincare commercial (soigner de l'intérieur)", "Huiles de graines et canola"]
        for item in avoid {
            if !nutrition.foodsToReduce.contains(item) {
                nutrition.foodsToReduce.append(item)
            }
        }

        if !nutrition.principles.contains(skinTimelineNote) {
            nutrition.principles.append(skinTimelineNote)
        }
    }

    static func pillarHints(
        skinClarityScore: Int?,
        acneOrDull: Bool
    ) -> [String] {
        var hints: [String] = []
        hints.append("Script #11 : acné/rosacea = santé interne — pas type de peau ni crèmes")
        if acneOrDull || (skinClarityScore ?? 100) < 65 {
            hints.append("Filtre douche + alimentation animale dense + reset intestin 8+ sem")
            hints.append("Pas retinol/skincare — suif/coco crue si topique ; crème soufre ponctuelle boutons")
        }
        hints.append("Hydratation via fruits/lait — pas litres d'eau + sachets électrolytes")
        return hints
    }

    static func hasSkinConcern(answers: [String: WelcomePlanAnswer]) -> Bool {
        let ids = answers["face_concerns"]?.choiceIds ?? []
        return ids.contains(where: {
            $0 == "acne" || $0 == "dull_skin" || $0 == "puffiness" || $0 == "dark_circles"
        })
    }

    private static func choice(_ id: String, in answers: [String: WelcomePlanAnswer]) -> String? {
        answers[id]?.choiceIds.first
    }
}
