import Foundation

/// Libellés builder petit-déj — FR persisté (`cardTitle` / `badge` / `item.name`), EN via `AppCopy.t`.
enum ProcessLocalizedBreakfastBuilderContent {

    @MainActor
    static func cardTitle(for option: BreakfastBuilderOption) -> String {
        if let en = cardTitlesFRToEN[option.id] {
            return AppCopy.t(option.cardTitle, en: en)
        }
        return option.cardTitle
    }

    @MainActor
    static func badge(for option: BreakfastBuilderOption) -> String {
        if let en = badgesFRToEN[option.badge] {
            return AppCopy.t(option.badge, en: en)
        }
        return option.badge
    }

    @MainActor
    static func itemName(for option: BreakfastBuilderOption) -> String {
        if let en = itemNamesFRToEN[option.id] {
            return AppCopy.t(option.item.name, en: en)
        }
        return option.item.name
    }

    /// Clés = `BreakfastBuilderOption.id`.
    static let cardTitlesFRToEN: [String: String] = [
        "eggs_2": "2 eggs",
        "eggs_3": "3 eggs",
        "yogurt": "greek\nyogurt",
        "kefir": "kefir",
        "banana": "banana",
        "kiwi": "kiwi",
        "avocado": "avocado",
        "melon": "melon",
        "roquette": "arugula",
        "tomato": "tomatoes",
        "cucumber": "cucumber",
        "fennel": "fennel",
        "lemon": "lemon",
        "olive_oil": "olive\noil",
        "ginger": "ginger",
    ]

    /// Clés = badge FR persisté.
    static let badgesFRToEN: [String: String] = [
        "P 14 g": "P 14 g",
        "P 21 g": "P 21 g",
        "P 15 g": "P 15 g",
        "P 8 g": "P 8 g",
        "K+": "K+",
        "fibres": "fiber",
        "digest": "digest",
        "vit C": "vit C",
        "EVO": "EVO",
    ]

    /// Clés = `BreakfastBuilderOption.id` → `item.name` EN.
    static let itemNamesFRToEN: [String: String] = [
        "eggs_2": "Fried eggs",
        "eggs_3": "Fried eggs",
        "yogurt": "Plain Greek yogurt",
        "kefir": "Plain kefir",
        "banana": "Ripe banana",
        "kiwi": "Kiwi",
        "avocado": "Ripe avocado",
        "melon": "Melon / watermelon",
        "roquette": "Arugula",
        "tomato": "Cherry tomatoes",
        "cucumber": "Cucumber",
        "fennel": "Raw fennel",
        "lemon": "Fresh lemon",
        "olive_oil": "Extra-virgin olive oil",
        "ginger": "Fresh grated ginger",
    ]

    /// Parties de `composedName` FR → EN (titres carte sans `\n`).
    static let composedPartFRToEN: [String: String] = [
        "2 œufs": "2 eggs",
        "3 œufs": "3 eggs",
        "yaourt grec": "greek yogurt",
        "kéfir": "kefir",
        "banane": "banana",
        "kiwi": "kiwi",
        "avocat": "avocado",
        "melon": "melon",
        "roquette": "arugula",
        "tomates": "tomatoes",
        "concombre": "cucumber",
        "fenouil": "fennel",
        "citron": "lemon",
        "huile d'olive": "olive oil",
        "gingembre": "ginger",
        "Petit-déj debloat": "Debloat breakfast",
    ]

    @MainActor
    static func localizedComposedMealName(_ fr: String) -> String {
        let trimmed = fr.trimmingCharacters(in: .whitespacesAndNewlines)
        if let en = composedPartFRToEN[trimmed] {
            return AppCopy.t(trimmed, en: en)
        }
        let parts = trimmed.components(separatedBy: " · ")
        guard parts.count > 1 else { return trimmed }
        let localized = parts.map { part -> String in
            if let en = composedPartFRToEN[part] {
                return AppCopy.t(part, en: en)
            }
            return part
        }
        return localized.joined(separator: " · ")
    }
}
