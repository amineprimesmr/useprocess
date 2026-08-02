import Foundation

struct DebloatGroceryRequest: Equatable {
    var budget: DebloatGroceryBudget = .standard
    var dayCount: Int = 7
    var includeDrinks: Bool = true
    var includeHerbs: Bool = true
}

struct DebloatGroceryLine: Identifiable, Equatable {
    let id: String
    let foodID: String
    let name: String
    let quantity: String
    let aisle: DebloatGroceryAisle
    let isAvoidWarning: Bool
    let suggestedSwapName: String?
}

struct DebloatGroceryPlan: Equatable {
    let lines: [DebloatGroceryLine]
    let budget: DebloatGroceryBudget
    let dayCount: Int

    var groupedByAisle: [(aisle: DebloatGroceryAisle, lines: [DebloatGroceryLine])] {
        DebloatGroceryAisle.allCases
            .sorted { $0.sortOrder < $1.sortOrder }
            .compactMap { aisle in
                let items = lines.filter { $0.aisle == aisle }
                guard !items.isEmpty else { return nil }
                return (aisle, items)
            }
    }
}

@MainActor
enum DebloatGroceryGenerator {
    static func generate(
        request: DebloatGroceryRequest,
        likes: [DebloatFoodItem]? = nil,
        haveAtHome: Set<String>? = nil,
        disliked: Set<String>? = nil
    ) -> DebloatGroceryPlan {
        let resolvedLikes = likes ?? DebloatFoodPreferenceStore.shared.likedFoods
        let resolvedHaveAtHome = haveAtHome ?? DebloatFoodPreferenceStore.shared.state.haveAtHomeIDs
        let resolvedDisliked = disliked ?? DebloatFoodPreferenceStore.shared.state.dislikedIDs

        var selected: [DebloatFoodItem] = []
        let pool = candidatePool(budget: request.budget, likes: resolvedLikes)
            .filter { !resolvedDisliked.contains($0.id) && !resolvedHaveAtHome.contains($0.id) }

        // Always include face-debloat anchors.
        let anchors = ["concombre", "epinards", "citron", "eau-plate", "poulet", "yaourt-nature"]
            .compactMap { DebloatFoodCatalog.item(id: $0) }
        for food in anchors where !resolvedHaveAtHome.contains(food.id) && !resolvedDisliked.contains(food.id) {
            appendUnique(food, into: &selected)
        }

        // Liked hero/prefer first.
        for food in resolvedLikes where food.tier == .hero || food.tier == .prefer {
            appendUnique(food, into: &selected)
        }

        let maxItems = quantityCaps(budget: request.budget, dayCount: request.dayCount)
        for food in pool {
            guard selected.count < maxItems else { break }
            if food.category == .drinks, !request.includeDrinks { continue }
            if food.category == .herbs, !request.includeHerbs { continue }
            appendUnique(food, into: &selected)
        }

        let lines = selected.map { food -> DebloatGroceryLine in
            let swap = DebloatFoodCatalog.swapItems(for: food).first
            return DebloatGroceryLine(
                id: food.id,
                foodID: food.id,
                name: food.name,
                quantity: quantity(for: food, dayCount: request.dayCount, budget: request.budget),
                aisle: food.category.aisle,
                isAvoidWarning: food.tier == .avoid || food.exceedsSaltLabelThreshold,
                suggestedSwapName: swap?.name
            )
        }
        .sorted {
            if $0.aisle.sortOrder != $1.aisle.sortOrder {
                return $0.aisle.sortOrder < $1.aisle.sortOrder
            }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        return DebloatGroceryPlan(lines: lines, budget: request.budget, dayCount: request.dayCount)
    }

    static func shoppingItems(from plan: DebloatGroceryPlan) -> [MealShoppingItem] {
        plan.lines.map {
            MealShoppingItem(
                name: $0.name,
                quantity: $0.quantity,
                dayId: nil
            )
        }
    }

    static func warning(for itemName: String) -> (message: String, swap: String?)? {
        guard let food = DebloatFoodCatalog.item(matchingName: itemName) else { return nil }
        guard food.tier == .avoid || food.exceedsSaltLabelThreshold else { return nil }
        let swap = DebloatFoodCatalog.swapItems(for: food).first?.name
        let saltNote = food.exceedsSaltLabelThreshold
            ? " (> 1,5 g de sel / 100 g)"
            : ""
        return (
            "« \(food.name) » freine le visage dégonflé\(saltNote).",
            swap
        )
    }

    // MARK: - Private

    private static func candidatePool(
        budget: DebloatGroceryBudget,
        likes: [DebloatFoodItem]
    ) -> [DebloatFoodItem] {
        let base = DebloatFoodCatalog.preferFoods
            .filter { $0.tier == .hero || $0.tier == .prefer }
            .sorted { lhs, rhs in
                let lBoost = likes.contains(where: { $0.id == lhs.id }) ? 20 : 0
                let rBoost = likes.contains(where: { $0.id == rhs.id }) ? 20 : 0
                return (lhs.debloatScore + lBoost) > (rhs.debloatScore + rBoost)
            }

        switch budget {
        case .economy:
            return base.filter { food in
                ["legumes", "fruits", "potassium", "protein", "drinks", "herbs"].contains(food.category.rawValue)
                    && !["rozana", "courmayeur", "pistaches", "noix-bresil", "tempeh"].contains(food.id)
            }
        case .standard:
            return base
        case .comfort:
            return base + DebloatFoodCatalog.preferFoods.filter { $0.category == .drinks || $0.category == .magnesium }
        }
    }

    private static func quantityCaps(budget: DebloatGroceryBudget, dayCount: Int) -> Int {
        let base: Int
        switch budget {
        case .economy: base = 14
        case .standard: base = 20
        case .comfort: base = 26
        }
        return min(36, base + max(0, dayCount - 3))
    }

    private static func quantity(
        for food: DebloatFoodItem,
        dayCount: Int,
        budget: DebloatGroceryBudget
    ) -> String {
        if let hint = food.portionHint, dayCount <= 3 {
            return hint
        }
        let factor = dayCount >= 7 ? 2 : 1
        let comfortBoost = budget == .comfort ? 1 : 0
        switch food.category {
        case .legumes, .fruits:
            return factor + comfortBoost >= 2 ? "×\(factor + comfortBoost) portions" : (food.portionHint ?? "1 portion")
        case .protein:
            return dayCount >= 7 ? "3–4 portions" : "2 portions"
        case .drinks:
            return food.id == "eau-plate" ? "6×1,5 L" : (dayCount >= 7 ? "4–6 unités" : "2–3 unités")
        case .herbs:
            return food.portionHint ?? "1 botte / pot"
        case .magnesium, .potassium:
            return food.portionHint ?? "1 paquet"
        case .avoidSodium, .avoidOther:
            return "à éviter"
        }
    }

    private static func appendUnique(_ food: DebloatFoodItem, into list: inout [DebloatFoodItem]) {
        guard !list.contains(where: { $0.id == food.id }) else { return }
        list.append(food)
    }
}
