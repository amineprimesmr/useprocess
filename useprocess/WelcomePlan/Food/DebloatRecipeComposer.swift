import Foundation

struct DebloatRecipeRequest: Equatable {
    var slot: MealTimeSlot = .lunch
    var maxMinutes: Int = 20
    var eveningSafeOnly: Bool = false
    var seed: Int = 0
}

@MainActor
enum DebloatRecipeComposer {
    /// Templates déterministes à partir des likes (+ fallbacks hero).
    static func compose(
        request: DebloatRecipeRequest,
        likes: [DebloatFoodItem]? = nil,
        disliked: Set<String>? = nil
    ) -> MealSuggestionContent {
        let resolvedLikes = likes ?? DebloatFoodPreferenceStore.shared.likedFoods
        let resolvedDisliked = disliked ?? DebloatFoodPreferenceStore.shared.state.dislikedIDs
        let usableLikes = resolvedLikes.filter { $0.tier != .avoid && !resolvedDisliked.contains($0.id) }
        let pool = usableLikes.isEmpty ? fallbackPool : usableLikes

        let veg = pick(from: pool, categories: [.legumes, .fruits], tags: ["high-K", "drainant", "soir-safe"], seed: request.seed)
            ?? DebloatFoodCatalog.item(id: "concombre")!
        let protein = pick(from: pool, categories: [.protein], seed: request.seed &+ 3)
            ?? DebloatFoodCatalog.item(id: request.slot == .breakfast ? "oeufs" : "poulet")!
        let carb = pick(from: pool, categories: [.potassium, .magnesium], idsHint: ["patate-douce", "pomme-de-terre", "quinoa", "flocons-avoine"], seed: request.seed &+ 7)
            ?? DebloatFoodCatalog.item(id: request.slot == .breakfast ? "flocons-avoine" : "patate-douce")!
        let boost = pick(from: pool, categories: [.herbs, .fruits], tags: ["tiktok-trend", "drainant"], seed: request.seed &+ 11)
            ?? DebloatFoodCatalog.item(id: "citron")!
        let mg = pick(from: pool, categories: [.magnesium], seed: request.seed &+ 13)
            ?? DebloatFoodCatalog.item(id: "graines-courge")

        if request.eveningSafeOnly || request.slot == .dinner {
            let safeProtein = protein.isEveningSafe ? protein : (DebloatFoodCatalog.item(id: "poisson-blanc") ?? protein)
            let safeVeg = veg.isEveningSafe ? veg : (DebloatFoodCatalog.item(id: "courgette") ?? veg)
            return buildMeal(
                slot: request.slot,
                protein: safeProtein,
                veg: safeVeg,
                carb: carb.isEveningSafe ? carb : (DebloatFoodCatalog.item(id: "patate-douce") ?? carb),
                boost: boost,
                mg: mg,
                minutes: min(request.maxMinutes, 25)
            )
        }

        return buildMeal(
            slot: request.slot,
            protein: protein,
            veg: veg,
            carb: carb,
            boost: boost,
            mg: mg,
            minutes: min(request.maxMinutes, 25)
        )
    }

    static func composeDay(
        slots: [MealTimeSlot],
        likes: [DebloatFoodItem]? = nil
    ) -> [MealTimeSlot: MealSuggestionContent] {
        let resolvedLikes = likes ?? DebloatFoodPreferenceStore.shared.likedFoods
        var result: [MealTimeSlot: MealSuggestionContent] = [:]
        for (index, slot) in slots.enumerated() {
            result[slot] = compose(
                request: DebloatRecipeRequest(
                    slot: slot,
                    maxMinutes: slot == .breakfast ? 12 : 20,
                    eveningSafeOnly: slot == .dinner,
                    seed: index * 17
                ),
                likes: resolvedLikes
            )
        }
        return result
    }

    // MARK: - Private

    private static var fallbackPool: [DebloatFoodItem] {
        DebloatFoodCatalog.preferFoods.filter { $0.tier == .hero || $0.tier == .prefer }
    }

    private static func pick(
        from pool: [DebloatFoodItem],
        categories: [DebloatFoodCategory],
        tags: [String] = [],
        idsHint: [String] = [],
        seed: Int
    ) -> DebloatFoodItem? {
        var candidates = pool.filter { categories.contains($0.category) }
        if !tags.isEmpty {
            let tagged = candidates.filter { food in tags.contains(where: { food.tags.contains($0) }) }
            if !tagged.isEmpty { candidates = tagged }
        }
        if !idsHint.isEmpty {
            let hinted = idsHint.compactMap { id in candidates.first(where: { $0.id == id }) }
            if !hinted.isEmpty {
                return hinted[abs(seed) % hinted.count]
            }
        }
        guard !candidates.isEmpty else { return nil }
        return candidates[abs(seed) % candidates.count]
    }

    private static func buildMeal(
        slot: MealTimeSlot,
        protein: DebloatFoodItem,
        veg: DebloatFoodItem,
        carb: DebloatFoodItem,
        boost: DebloatFoodItem,
        mg: DebloatFoodItem?,
        minutes: Int
    ) -> MealSuggestionContent {
        // Noms / quantités FR persistés — rôles FR (affichage via `ProcessLocalizedMealContent.role`).
        var items: [MealSuggestionItem] = [
            .init(name: protein.name, quantity: protein.portionHint ?? "150 g", role: "Protéine"),
            .init(name: veg.name, quantity: veg.portionHint ?? "1 portion", role: "Légume"),
            .init(name: carb.name, quantity: carb.portionHint ?? "1 portion", role: "Glucide"),
            .init(name: boost.name, quantity: boost.portionHint ?? "1 portion", role: "Autre")
        ]
        if let mg {
            items.append(.init(name: mg.name, quantity: mg.portionHint ?? "20 g", role: "Gras"))
        }

        // Libellés FR persistés — affichage EN via `ProcessLocalizedDebloatFoodContent.recipe*`.
        let name = recipeNameFR(slot: slot, protein: protein, veg: veg, carb: carb)
        let prep = """
        1. Prépare \(protein.name) sans sel (herbes + citron).
        2. Ajoute \(veg.name) et \(carb.name) cuits vapeur ou four.
        3. Finis avec \(boost.name)\(mg.map { " et \($0.name)" } ?? "").
        4. Zéro sauce industrielle — l’objectif est le visage dégonflé.
        """
        let tip = "Priorité potassium : \(veg.name) + \(carb.name). Évite le sel ce repas."

        return MealSuggestionContent.asProcessDefault(
            name: name,
            mealType: slot.rawValue,
            items: items,
            prepMinutes: minutes,
            prepSummary: prep,
            coachTip: tip,
            tags: ["debloat", "from-likes", "high-K"],
            imageAssetName: nil
        )
    }

    private static func recipeNameFR(
        slot: MealTimeSlot,
        protein: DebloatFoodItem,
        veg: DebloatFoodItem,
        carb: DebloatFoodItem
    ) -> String {
        switch slot {
        case .breakfast: return "Matin dégonflé · \(protein.name) & \(carb.name)"
        case .lunch: return "Bowl K · \(protein.name), \(veg.name)"
        case .dinner: return "Dîner anti-rétention · \(protein.name)"
        case .snack: return "Collation drainante · \(veg.name)"
        }
    }
}
