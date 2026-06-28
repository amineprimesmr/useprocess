import CoreGraphics
import Foundation

// MARK: - Catégories

enum BreakfastBuilderCategory: String, CaseIterable, Identifiable {
    case hydration
    case protein
    case fruit
    case vegetable
    case finish

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hydration: return "Hydratation"
        case .protein: return "Protéine"
        case .fruit: return "Fruits potassium"
        case .vegetable: return "Légumes frais"
        case .finish: return "Finition"
        }
    }

    var subtitle: String {
        switch self {
        case .hydration: return "Obligatoire — au réveil"
        case .protein: return "Obligatoire — 1 choix"
        case .fruit: return "Optionnel — max 2"
        case .vegetable: return "Optionnel — max 2"
        case .finish: return "Optionnel — max 2"
        }
    }

    var icon: String {
        switch self {
        case .hydration: return "drop.fill"
        case .protein: return "bolt.fill"
        case .fruit: return "leaf.fill"
        case .vegetable: return "carrot.fill"
        case .finish: return "sparkles"
        }
    }

    var maxSelections: Int {
        switch self {
        case .hydration, .protein: return 1
        case .fruit, .vegetable, .finish: return 2
        }
    }

    var isRequired: Bool {
        self == .hydration || self == .protein
    }
}

// MARK: - Options

struct BreakfastLayerPlacement: Equatable {
    let x: CGFloat
    let y: CGFloat
    let scale: CGFloat
    let zIndex: Int
}

struct BreakfastBuilderOption: Identifiable, Equatable {
    let id: String
    let category: BreakfastBuilderCategory
    /// Titre carte carousel (peut contenir \n pour 2 lignes).
    let cardTitle: String
    let badge: String
    let item: MealSuggestionItem
    /// PNG calque sur le hero (transparent).
    let layerAsset: String?
    /// Image pleine carte pour le carousel d’options (optionnel).
    let cardPreviewAsset: String?
    let calories: Int
    let placement: BreakfastLayerPlacement?

    var displayTitle: String {
        cardTitle.replacingOccurrences(of: "\n", with: " ")
    }
}

// MARK: - Catalogue

enum BreakfastMealBuilderCatalog {

    static let backgroundAsset = "breakfast_builder_bg"

    static var categories: [BreakfastBuilderCategory] {
        BreakfastBuilderCategory.allCases
    }

    static func options(for category: BreakfastBuilderCategory) -> [BreakfastBuilderOption] {
        allOptions.filter { $0.category == category }
    }

    static func option(id: String) -> BreakfastBuilderOption? {
        allOptions.first { $0.id == id }
    }

    static func option(matching item: MealSuggestionItem) -> BreakfastBuilderOption? {
        allOptions.first {
            $0.item.name.caseInsensitiveCompare(item.name) == .orderedSame
                && $0.item.quantity == item.quantity
        }
    }

    static var defaultSelections: BreakfastBuilderSelections {
        BreakfastBuilderSelections(
            hydration: "water_salt",
            protein: "eggs_2",
            fruits: [],
            vegetables: [],
            finishes: []
        )
    }

    static func buildMeal(from selections: BreakfastBuilderSelections) -> MealSuggestionContent {
        let items = selections.allSelectedOptionIDs.compactMap { option(id: $0)?.item }
        let name = composedName(from: selections)

        return MealSuggestionContent.asProcessDefault(
            name: name,
            mealType: MealTimeSlot.breakfast.rawValue,
            items: items,
            prepMinutes: 12,
            prepSummary: "Compose ton petit-déj debloat — protéine + hydratation + potassium.",
            coachTip: "Eau salée en premier. Pas de pain ni céréales industrielles au matin.",
            tags: ["builder", "debloat", "petit-dejeuner"],
            imageAssetName: heroImageAsset(for: selections)
        )
    }

    static func composedName(from selections: BreakfastBuilderSelections) -> String {
        var parts: [String] = []
        if let protein = option(id: selections.protein) {
            parts.append(protein.displayTitle)
        }
        let fruits = selections.fruits.compactMap { option(id: $0)?.displayTitle }
        let veggies = selections.vegetables.compactMap { option(id: $0)?.displayTitle }
        parts.append(contentsOf: fruits)
        parts.append(contentsOf: veggies)
        if parts.isEmpty { return "Petit-déj debloat" }
        return parts.joined(separator: " · ")
    }

    static func heroCardTitle(from selections: BreakfastBuilderSelections) -> String {
        let protein = option(id: selections.protein)?.cardTitle ?? "petit\ndéj"
        if selections.fruits.isEmpty && selections.vegetables.isEmpty {
            return protein
        }
        let accent = selections.fruits.compactMap { option(id: $0)?.cardTitle }.first
            ?? selections.vegetables.compactMap { option(id: $0)?.cardTitle }.first
            ?? ""
        if accent.isEmpty { return protein }
        return "\(protein)\n\(accent)"
    }

    static func heroImageAsset(for selections: BreakfastBuilderSelections) -> String {
        if let protein = option(id: selections.protein),
           let preview = protein.cardPreviewAsset,
           ProcessAssetCatalog.contains(preview) {
            return preview
        }
        return "breakfast_builder_composed"
    }

    static func layerOptions(from selections: BreakfastBuilderSelections) -> [BreakfastBuilderOption] {
        selections.allSelectedOptionIDs
            .compactMap { option(id: $0) }
            .filter { $0.layerAsset != nil && $0.placement != nil }
            .sorted { ($0.placement?.zIndex ?? 0) < ($1.placement?.zIndex ?? 0) }
    }

    // MARK: - Data

    private static let allOptions: [BreakfastBuilderOption] = hydrationOptions
        + proteinOptions + fruitOptions + vegetableOptions + finishOptions

    private static let hydrationOptions: [BreakfastBuilderOption] = [
        make(
            id: "water_salt",
            category: .hydration,
            cardTitle: "eau\nsalée",
            badge: "500 ml",
            itemName: ProcessHydrationGuide.morningWaterItemName,
            quantity: ProcessHydrationGuide.morningWaterLabel,
            role: "Hydratation",
            layer: "breakfast_layer_water",
            preview: "breakfast_card_water_salt",
            calories: 0,
            placement: .init(x: 0.22, y: 0.38, scale: 0.72, zIndex: 1)
        ),
        make(
            id: "water_lemon",
            category: .hydration,
            cardTitle: "eau\ncitron",
            badge: "500 ml",
            itemName: "2 grands verres d'eau filtrée + citron frais",
            quantity: ProcessHydrationGuide.morningWaterLabel,
            role: "Hydratation",
            layer: "breakfast_layer_water_lemon",
            preview: "breakfast_card_water_lemon",
            calories: 5,
            placement: .init(x: 0.22, y: 0.38, scale: 0.72, zIndex: 1)
        ),
        make(
            id: "water_mineral",
            category: .hydration,
            cardTitle: "eau\nminérale",
            badge: "500 ml",
            itemName: "Eau minérale légère (Rozana / Volvic)",
            quantity: ProcessHydrationGuide.morningWaterLabel,
            role: "Hydratation",
            layer: "breakfast_layer_water_bottle",
            preview: "breakfast_card_water_mineral",
            calories: 0,
            placement: .init(x: 0.24, y: 0.40, scale: 0.68, zIndex: 1)
        )
    ]

    private static let proteinOptions: [BreakfastBuilderOption] = [
        make(
            id: "eggs_2",
            category: .protein,
            cardTitle: "2 œufs",
            badge: "P 14 g",
            itemName: "Œufs au plat",
            quantity: "2",
            role: "Protéine",
            layer: "breakfast_layer_eggs_2",
            preview: "breakfast_card_eggs_2",
            calories: 140,
            placement: .init(x: 0.52, y: 0.48, scale: 0.88, zIndex: 3)
        ),
        make(
            id: "eggs_3",
            category: .protein,
            cardTitle: "3 œufs",
            badge: "P 21 g",
            itemName: "Œufs au plat",
            quantity: "3",
            role: "Protéine",
            layer: "breakfast_layer_eggs_3",
            preview: "breakfast_card_eggs_3",
            calories: 210,
            placement: .init(x: 0.52, y: 0.48, scale: 0.92, zIndex: 3)
        ),
        make(
            id: "yogurt",
            category: .protein,
            cardTitle: "yaourt\ngrec",
            badge: "P 15 g",
            itemName: "Yaourt grec nature",
            quantity: "180 g",
            role: "Protéine",
            layer: "breakfast_layer_yogurt",
            preview: "breakfast_card_yogurt",
            calories: 110,
            placement: .init(x: 0.50, y: 0.52, scale: 0.78, zIndex: 3)
        ),
        make(
            id: "kefir",
            category: .protein,
            cardTitle: "kéfir",
            badge: "P 8 g",
            itemName: "Kéfir nature",
            quantity: "200 ml",
            role: "Protéine",
            layer: "breakfast_layer_kefir",
            preview: "breakfast_card_kefir",
            calories: 90,
            placement: .init(x: 0.48, y: 0.50, scale: 0.75, zIndex: 3)
        )
    ]

    private static let fruitOptions: [BreakfastBuilderOption] = [
        make(
            id: "banana",
            category: .fruit,
            cardTitle: "banane",
            badge: "K+",
            itemName: "Banane bien mûre",
            quantity: "1",
            role: "Glucide",
            layer: "breakfast_layer_banana",
            preview: "breakfast_card_banana",
            calories: 105,
            placement: .init(x: 0.78, y: 0.55, scale: 0.82, zIndex: 4)
        ),
        make(
            id: "kiwi",
            category: .fruit,
            cardTitle: "kiwi",
            badge: "K+",
            itemName: "Kiwi",
            quantity: "1",
            role: "Glucide",
            layer: "breakfast_layer_kiwi",
            preview: "breakfast_card_kiwi",
            calories: 45,
            placement: .init(x: 0.72, y: 0.42, scale: 0.70, zIndex: 4)
        ),
        make(
            id: "avocado",
            category: .fruit,
            cardTitle: "avocat",
            badge: "K+",
            itemName: "Avocat mûr",
            quantity: "1/2",
            role: "Gras",
            layer: "breakfast_layer_avocado",
            preview: "breakfast_card_avocado",
            calories: 120,
            placement: .init(x: 0.76, y: 0.50, scale: 0.80, zIndex: 4)
        ),
        make(
            id: "melon",
            category: .fruit,
            cardTitle: "melon",
            badge: "K+",
            itemName: "Melon / pastèque",
            quantity: "150 g",
            role: "Glucide",
            layer: "breakfast_layer_melon",
            preview: "breakfast_card_melon",
            calories: 50,
            placement: .init(x: 0.80, y: 0.46, scale: 0.76, zIndex: 4)
        )
    ]

    private static let vegetableOptions: [BreakfastBuilderOption] = [
        make(
            id: "roquette",
            category: .vegetable,
            cardTitle: "roquette",
            badge: "fibres",
            itemName: "Roquette",
            quantity: "80 g",
            role: "Légume",
            layer: "breakfast_layer_roquette",
            preview: "breakfast_card_roquette",
            calories: 20,
            placement: .init(x: 0.68, y: 0.58, scale: 0.74, zIndex: 2)
        ),
        make(
            id: "tomato",
            category: .vegetable,
            cardTitle: "tomates",
            badge: "fibres",
            itemName: "Tomates cerises",
            quantity: "150 g",
            role: "Légume",
            layer: "breakfast_layer_tomato",
            preview: "breakfast_card_tomato",
            calories: 30,
            placement: .init(x: 0.74, y: 0.52, scale: 0.76, zIndex: 2)
        ),
        make(
            id: "cucumber",
            category: .vegetable,
            cardTitle: "concombre",
            badge: "fibres",
            itemName: "Concombre",
            quantity: "100 g",
            role: "Légume",
            layer: "breakfast_layer_cucumber",
            preview: "breakfast_card_cucumber",
            calories: 15,
            placement: .init(x: 0.70, y: 0.56, scale: 0.72, zIndex: 2)
        ),
        make(
            id: "fennel",
            category: .vegetable,
            cardTitle: "fenouil",
            badge: "digest",
            itemName: "Fenouil cru",
            quantity: "60 g",
            role: "Légume",
            layer: "breakfast_layer_fennel",
            preview: "breakfast_card_fennel",
            calories: 18,
            placement: .init(x: 0.66, y: 0.50, scale: 0.68, zIndex: 2)
        )
    ]

    private static let finishOptions: [BreakfastBuilderOption] = [
        make(
            id: "lemon",
            category: .finish,
            cardTitle: "citron",
            badge: "vit C",
            itemName: "Citron frais",
            quantity: "1/2",
            role: "Autre",
            layer: "breakfast_layer_lemon",
            preview: "breakfast_card_lemon",
            calories: 5,
            placement: .init(x: 0.58, y: 0.40, scale: 0.55, zIndex: 5)
        ),
        make(
            id: "olive_oil",
            category: .finish,
            cardTitle: "huile\nd'olive",
            badge: "EVO",
            itemName: "Huile d'olive extra vierge",
            quantity: "1 c. à café",
            role: "Gras",
            layer: "breakfast_layer_olive_oil",
            preview: "breakfast_card_olive_oil",
            calories: 45,
            placement: .init(x: 0.60, y: 0.62, scale: 0.50, zIndex: 5)
        ),
        make(
            id: "ginger",
            category: .finish,
            cardTitle: "gingembre",
            badge: "digest",
            itemName: "Gingembre frais râpé",
            quantity: "1 pincée",
            role: "Autre",
            layer: "breakfast_layer_ginger",
            preview: "breakfast_card_ginger",
            calories: 2,
            placement: .init(x: 0.56, y: 0.44, scale: 0.48, zIndex: 5)
        )
    ]

    private static func make(
        id: String,
        category: BreakfastBuilderCategory,
        cardTitle: String,
        badge: String,
        itemName: String,
        quantity: String,
        role: String,
        layer: String,
        preview: String,
        calories: Int,
        placement: BreakfastLayerPlacement
    ) -> BreakfastBuilderOption {
        BreakfastBuilderOption(
            id: id,
            category: category,
            cardTitle: cardTitle,
            badge: badge,
            item: MealSuggestionItem(name: itemName, quantity: quantity, role: role),
            layerAsset: layer,
            cardPreviewAsset: preview,
            calories: calories,
            placement: placement
        )
    }
}

// MARK: - Sélections

struct BreakfastBuilderSelections: Equatable {
    var hydration: String
    var protein: String
    var fruits: Set<String>
    var vegetables: Set<String>
    var finishes: Set<String>

    var allSelectedOptionIDs: [String] {
        [hydration, protein]
            + fruits.sorted()
            + vegetables.sorted()
            + finishes.sorted()
    }

    var estimatedCalories: Int {
        allSelectedOptionIDs.compactMap { BreakfastMealBuilderCatalog.option(id: $0)?.calories }.reduce(0, +)
    }

    func isSelected(_ option: BreakfastBuilderOption) -> Bool {
        switch option.category {
        case .hydration: return hydration == option.id
        case .protein: return protein == option.id
        case .fruit: return fruits.contains(option.id)
        case .vegetable: return vegetables.contains(option.id)
        case .finish: return finishes.contains(option.id)
        }
    }

    mutating func toggle(_ option: BreakfastBuilderOption) {
        let max = option.category.maxSelections
        switch option.category {
        case .hydration:
            hydration = option.id
        case .protein:
            protein = option.id
        case .fruit:
            fruits = Self.toggledSet(fruits, id: option.id, max: max)
        case .vegetable:
            vegetables = Self.toggledSet(vegetables, id: option.id, max: max)
        case .finish:
            finishes = Self.toggledSet(finishes, id: option.id, max: max)
        }
    }

    private static func toggledSet(_ set: Set<String>, id: String, max: Int) -> Set<String> {
        var copy = set
        if copy.contains(id) {
            copy.remove(id)
            return copy
        }
        if copy.count < max {
            copy.insert(id)
            return copy
        }
        if max == 1 {
            return [id]
        }
        if let first = copy.first {
            copy.remove(first)
        }
        copy.insert(id)
        return copy
    }
}
