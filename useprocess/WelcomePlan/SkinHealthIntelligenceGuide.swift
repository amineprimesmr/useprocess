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

    static var lymphAndSkinRoutine: [String] {
        [
            AppCopy.tSync(
                "Filtre douche — eau sans chlore/fluor sur peau et cheveux",
                en: "Shower filter — chlorine/fluoride-free water on skin and hair"
            ),
            AppCopy.tSync(
                "Pas crèmes skincare commerciales — racine = alimentation + intestin",
                en: "No commercial skincare creams — root cause = food + gut"
            ),
            AppCopy.tSync(
                "Topique si besoin : suif ou crème coco crue (non comédogène)",
                en: "Topical if needed: tallow or raw coconut cream (non-comedogenic)"
            ),
            AppCopy.tSync(
                "Eau froide visage au réveil — drainage lymphatique",
                en: "Cold water on face at wake — lymphatic drainage"
            ),
            AppCopy.tSync(
                "Spray sel celtique + eau après douche (exfoliation naturelle)",
                en: "Celtic salt + water spray after shower (natural exfoliation)"
            ),
            AppCopy.tSync(
                "Soleil modéré — peau reflète santé interne",
                en: "Moderate sun — skin reflects internal health"
            )
        ]
    }

    static var skinTimelineNote: String {
        AppCopy.tSync(
            "Peau claire : 8+ semaines minimum constant — 3–4 mois pour stabiliser (pas cheat meals)",
            en: "Clear skin: 8+ weeks minimum consistency — 3–4 months to stabilize (no cheat meals)"
        )
    }

    static var dietPrinciplesForSkin: [String] {
        [
            AppCopy.tSync(
                "Viande + œufs quotidiens — gras saturés pour hormones",
                en: "Daily meat + eggs — saturated fats for hormones"
            ),
            AppCopy.tSync(
                "Lait A2 cru — pas lait A1 industriel",
                en: "Raw A2 milk — no industrial A1 milk"
            ),
            AppCopy.tSync(
                "Cuisson en suif — pas huiles de graines",
                en: "Cook in tallow — no seed oils"
            ),
            AppCopy.tSync(
                "Fruits + hydratation alimentaire — pas excès eau plate sans électrolytes",
                en: "Fruit + food hydration — no excess plain water without electrolytes"
            )
        ]
    }

    // MARK: - Génération protocole

    static func enrichFaceProtocol(
        _ face: inout OriginFaceProtocol,
        answers: [String: WelcomePlanAnswer],
        coldRinseSeconds: Int,
        lymphMinutes: Int,
        dailySteps: Int,
        hydrationLabel: String
    ) {
        _ = face
        _ = answers
        _ = coldRinseSeconds
        _ = lymphMinutes
        _ = dailySteps
        _ = hydrationLabel
        // Routine matinale = FaceMorningRoutineCatalog uniquement (pas de pollution lymphAndFascia).
    }

    static func enrichNutritionForSkin(
        _ nutrition: inout OriginNutritionProtocol,
        answers: [String: WelcomePlanAnswer]
    ) {
        guard hasSkinConcern(answers: answers) else { return }

        for principle in dietPrinciplesForSkin {
            if !nutrition.principles.contains(principle) {
                nutrition.principles.insert(principle, at: 0)
            }
        }

        let skinFoods = [
            AppCopy.tSync("Viande rouge et œufs", en: "Red meat and eggs"),
            AppCopy.tSync("Lait A2 cru / mouton", en: "Raw A2 milk / sheep"),
            AppCopy.tSync("Fruits frais", en: "Fresh fruit"),
            AppCopy.tSync("Suif (cuisson)", en: "Tallow (cooking)")
        ]
        for food in skinFoods {
            if !nutrition.foodsToPrioritize.contains(food) {
                nutrition.foodsToPrioritize.append(food)
            }
        }

        let avoid = [
            AppCopy.tSync("Skincare commercial (soigner de l'intérieur)", en: "Commercial skincare (heal from inside)"),
            AppCopy.tSync("Huiles de graines et canola", en: "Seed oils and canola")
        ]
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
        hints.append(AppCopy.tSync(
            "Script #11 : acné/rosacea = santé interne — pas type de peau ni crèmes",
            en: "Script #11: acne/rosacea = internal health — not skin type or creams"
        ))
        if acneOrDull || (skinClarityScore ?? 100) < 65 {
            hints.append(AppCopy.tSync(
                "Filtre douche + alimentation animale dense + reset intestin 8+ sem",
                en: "Shower filter + dense animal nutrition + gut reset 8+ wk"
            ))
            hints.append(AppCopy.tSync(
                "Pas retinol/skincare — suif/coco crue si topique ; crème soufre ponctuelle boutons",
                en: "No retinol/skincare — tallow/raw coco if topical; spot sulfur cream on blemishes"
            ))
        }
        hints.append(AppCopy.tSync(
            "Hydratation via fruits/lait — pas litres d'eau + sachets électrolytes",
            en: "Hydration via fruit/milk — not liters of water + electrolyte packets"
        ))
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
