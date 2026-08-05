import Foundation

/// Libellés repas catalogue — FR persisté, EN affiché via `AppCopy.t`.
enum ProcessLocalizedMealContent {
    @MainActor
    static func name(_ fr: String, en: String) -> String {
        AppCopy.t(fr, en: en)
    }

    @MainActor
    static func tip(_ fr: String, en: String) -> String {
        AppCopy.t(fr, en: en)
    }

    @MainActor
    static func summary(_ fr: String, en: String) -> String {
        AppCopy.t(fr, en: en)
    }

    @MainActor
    static func prep(_ fr: String, en: String) -> String {
        AppCopy.t(fr, en: en)
    }

    @MainActor
    static func itemName(_ fr: String, en: String) -> String {
        AppCopy.t(fr, en: en)
    }

    @MainActor
    static func quantity(_ fr: String, en: String) -> String {
        AppCopy.t(fr, en: en)
    }

    @MainActor
    static func role(_ fr: String) -> String {
        switch fr.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "protéine", "proteine":
            return AppCopy.t("Protéine", en: "Protein")
        case "glucide":
            return AppCopy.t("Glucide", en: "Carb")
        case "légume", "legume":
            return AppCopy.t("Légume", en: "Vegetable")
        case "gras":
            return AppCopy.t("Gras", en: "Fat")
        case "autre":
            return AppCopy.t("Autre", en: "Other")
        default:
            return fr
        }
    }

    /// Nom d’ingrédient affiché — repas catalogue, aliments Debloat, puis builder petit-déj.
    @MainActor
    static func ingredientName(_ fr: String) -> String {
        let trimmed = fr.trimmingCharacters(in: .whitespacesAndNewlines)
        if let en = itemNamesFRToEN[trimmed] {
            return itemName(trimmed, en: en)
        }
        if let food = DebloatFoodCatalog.item(matchingName: trimmed) {
            return food.localizedName
        }
        if let en = breakfastIngredientNamesFRToEN[trimmed] {
            return AppCopy.t(trimmed, en: en)
        }
        return trimmed
    }

    @MainActor
    static func ingredientQuantity(_ fr: String) -> String {
        let trimmed = fr.trimmingCharacters(in: .whitespacesAndNewlines)
        if let en = quantitiesFRToEN[trimmed] {
            return quantity(trimmed, en: en)
        }
        if let en = ingredientQuantitiesFRToEN[trimmed] {
            return AppCopy.t(trimmed, en: en)
        }
        return ProcessLocalizedDebloatFoodContent.portionHint(trimmed)
    }

    /// Ingrédients builder petit-déj (clés = `MealSuggestionItem.name` FR).
    static let breakfastIngredientNamesFRToEN: [String: String] = [
        "Œufs au plat": "Fried eggs",
        "Yaourt grec nature": "Plain Greek yogurt",
        "Kéfir nature": "Plain kefir",
        "Banane bien mûre": "Ripe banana",
        "Kiwi": "Kiwi",
        "Avocat mûr": "Ripe avocado",
        "Melon / pastèque": "Melon / watermelon",
        "Roquette": "Arugula",
        "Tomates cerises": "Cherry tomatoes",
        "Concombre": "Cucumber",
        "Fenouil cru": "Raw fennel",
        "Citron frais": "Fresh lemon",
        "Huile d'olive extra vierge": "Extra-virgin olive oil",
        "Gingembre frais râpé": "Fresh grated ginger",
    ]

    static let ingredientQuantitiesFRToEN: [String: String] = [
        "1 c. à café": "1 tsp",
        "1 c. à soupe": "1 tbsp",
        "1 c. à s.": "1 tbsp",
        "2 c. à s.": "2 tbsp",
        "1 pincée": "1 pinch",
        "1/2": "1/2",
        "1/2 citron": "1/2 lemon",
        "160 g cuit": "160 g cooked",
        "180 g cuit": "180 g cooked",
        "180 g": "180 g",
        "200 ml": "200 ml",
        "80 g": "80 g",
        "100 g": "100 g",
        "150 g": "150 g",
        "60 g": "60 g",
    ]

    /// Noms catalogue FR → EN (clés = `MealSuggestionContent.name` persisté).
    static let mealNamesFRToEN: [String: String] = [
        // Breakfast
        "Œufs Brouillés Banane Kiwi": "Scrambled Eggs Banana Kiwi",
        "Yaourt Myrtilles Miel": "Yogurt Blueberries Honey",
        "Bowl Saumon Avocat Concombre": "Salmon Avocado Cucumber Bowl",
        // Lunch
        "Poulet Patate Douce Brocoli": "Chicken Sweet Potato Broccoli",
        "Patate Douce Viande Avocat": "Sweet Potato Meat Avocado",
        "Salade Poulet Avocat Composée": "Chicken Avocado Mixed Salad",
        "Saumon Quinoa Salade Concombre": "Salmon Quinoa Cucumber Salad",
        "Dinde Pommes Salade Verte": "Turkey Potatoes Green Salad",
        "Bœuf Haché Riz Poivrons": "Ground Beef Rice Peppers",
        "Lieu Noir Haricots Salade Fenouil": "Pollock Green Beans Fennel Salad",
        // Dinner
        "Steak Salade Épinards Pommes": "Steak Spinach Salad Potatoes",
        "Poulet Rôti Salade Avocat": "Roasted Chicken Avocado Salad",
        "Dinde Brocoli Riz Basmati": "Turkey Broccoli Basmati Rice",
        "Cabillaud Carottes Salade Mâche": "Cod Carrots Lamb's Lettuce Salad",
        // OMAD
        "Assiette OMAD Steak Patate Avocat": "OMAD Plate Steak Potato Avocado",
        "Bowl OMAD Poulet Quinoa Salade": "OMAD Chicken Quinoa Salad Bowl",
        // Snack
        "Banane Skyr": "Banana Skyr",
        "Ananas Dinde Rôtie": "Pineapple Roast Turkey",
    ]

    /// Tips catalogue FR → EN (clés = `coachTip` persisté).
    static let mealTipsFRToEN: [String: String] = [
        "Zéro sel dans la poêle — poivre et herbes suffisent.":
            "No salt in the pan — pepper and herbs are enough.",
        "Une seule c. à café de miel — le goût sucré vient surtout des myrtilles.":
            "Just one teaspoon of honey — the sweetness mostly comes from the blueberries.",
        "Saumon fumé = sodium élevé — toujours frais.":
            "Smoked salmon = high sodium — always use fresh.",
        "Herbes et citron plutôt que sel sur le poulet.":
            "Herbs and lemon instead of salt on the chicken.",
        "1 grosse portion ou 2 moyennes — sel très léger, le citron et le cumin portent le goût.":
            "1 large portion or 2 medium — go very light on salt; lemon and cumin carry the flavor.",
        "Pas de sauce salade du commerce (sodium + sucre).":
            "No store-bought salad dressing (sodium + sugar).",
        "Change du riz — quinoa + salade = variété et fibres.":
            "Switch it up from rice — quinoa + salad = variety and fiber.",
        "Journée rétention : sel modéré, citron sur la dinde.":
            "Retention day: moderate salt, lemon on the turkey.",
        "Herbes et huile infusée à l'ail — pas de sauce taco ou tomate salée.":
            "Herbs and garlic-infused oil — no taco sauce or salty tomato sauce.",
        "Poisson blanc le soir aussi possible — très léger en sel.":
            "White fish works in the evening too — very light on salt.",
        "Sel léger le soir ; poivre, herbes et huile infusée à l'ail sur le steak.":
            "Go light on salt at night; pepper, herbs, and garlic-infused oil on the steak.",
        "Marinade citron-herbes maison — pas marinade industrielle.":
            "Homemade lemon-herb marinade — not a store-bought one.",
        "Alternative chaude quand tu ne veux pas de salade froide.":
            "A warm option when you don't want a cold salad.",
        "Poisson blanc le soir — sel modéré, citron sur le poisson.":
            "White fish at night — moderate salt, lemon on the fish.",
        "Sel contrôlé dans la fenêtre OMAD — herbes et citron en priorité.":
            "Keep salt controlled in the OMAD window — herbs and lemon first.",
        "Tout en un bol dense — pas de sauce crémeuse industrielle.":
            "Everything in one dense bowl — no creamy store-bought sauce.",
        "Idéal après le sport — sans boisson dans le repas.":
            "Ideal after training — no drink with the meal.",
        "La dinde maison évite le sodium élevé des charcuteries.":
            "Homemade turkey avoids the high sodium in deli meats.",
    ]
}
