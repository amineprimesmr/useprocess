import Foundation

// MARK: - Tiers & catégories

enum DebloatFoodTier: String, Codable, CaseIterable, Identifiable, Hashable {
    case hero
    case prefer
    case moderate
    case avoid

    var id: String { rawValue }

    var badgeLabel: String {
        switch self {
        case .hero: return "Hero K"
        case .prefer: return "Drainant"
        case .moderate: return "Modéré"
        case .avoid: return "À éviter"
        }
    }

    var shortLabel: String {
        switch self {
        case .hero: return "Prioritaire"
        case .prefer: return "À privilégier"
        case .moderate: return "Avec modération"
        case .avoid: return "À éviter"
        }
    }
}

enum DebloatFoodCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    case legumes
    case fruits
    case potassium
    case magnesium
    case protein
    case herbs
    case drinks
    case avoidSodium
    case avoidOther

    var id: String { rawValue }

    var sectionTitle: String {
        switch self {
        case .legumes: return "Légumes drainants"
        case .fruits: return "Fruits drainants"
        case .potassium: return "Sources de potassium"
        case .magnesium: return "Sources de magnésium"
        case .protein: return "Protéines de qualité"
        case .herbs: return "Herbes & condiments"
        case .drinks: return "Boissons"
        case .avoidSodium: return "Très riches en sodium"
        case .avoidOther: return "Rétention / inflammation"
        }
    }

    var aisle: DebloatGroceryAisle {
        switch self {
        case .legumes, .fruits: return .produce
        case .protein: return .protein
        case .drinks: return .drinks
        case .herbs: return .herbs
        case .potassium, .magnesium, .avoidSodium, .avoidOther: return .grocery
        }
    }
}

enum DebloatGroceryAisle: String, Codable, CaseIterable, Identifiable, Hashable {
    case produce
    case protein
    case grocery
    case drinks
    case herbs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .produce: return "Fruits & légumes"
        case .protein: return "Protéines"
        case .grocery: return "Épicerie"
        case .drinks: return "Boissons"
        case .herbs: return "Herbes & épices"
        }
    }

    var sortOrder: Int {
        switch self {
        case .produce: return 0
        case .protein: return 1
        case .grocery: return 2
        case .herbs: return 3
        case .drinks: return 4
        }
    }
}

enum DebloatGroceryBudget: String, Codable, CaseIterable, Identifiable, Hashable {
    case economy
    case standard
    case comfort

    var id: String { rawValue }

    var title: String {
        switch self {
        case .economy: return "Économique"
        case .standard: return "Normal"
        case .comfort: return "Confort"
        }
    }

    var subtitle: String {
        switch self {
        case .economy: return "Essentiels high-K, peu de marques"
        case .standard: return "Équilibre visage + variété"
        case .comfort: return "Plus de choix drainants & boissons"
        }
    }
}

// MARK: - Food item

struct DebloatFoodItem: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let category: DebloatFoodCategory
    let tier: DebloatFoodTier
    let potassiumMgPer100g: Double?
    let sodiumMgPer100g: Double?
    let magnesiumMgPer100g: Double?
    let debloatScore: Int
    let whyItHelpsOrHurts: String
    let tags: [String]
    let swaps: [String]
    let portionHint: String?

    var isEveningSafe: Bool { tags.contains("soir-safe") }
    var isHighPotassium: Bool { tags.contains("high-K") }
    var isTrend: Bool { tags.contains("tiktok-trend") }

    var saltGramsPer100g: Double? {
        guard let sodium = sodiumMgPer100g else { return nil }
        return sodium / 400.0
    }

    var exceedsSaltLabelThreshold: Bool {
        guard let salt = saltGramsPer100g else { return false }
        return salt > 1.5
    }

    var potassiumSodiumRatio: Double? {
        guard let k = potassiumMgPer100g, let na = sodiumMgPer100g else { return nil }
        return k / max(na, 1)
    }
}

enum DebloatFoodScoreEngine {
    /// 0.45×K + 0.35×lowNa + 0.20×Mg, malus soir/salé/UT.
    static func score(
        potassiumMgPer100g: Double?,
        sodiumMgPer100g: Double?,
        magnesiumMgPer100g: Double?,
        tier: DebloatFoodTier,
        tags: [String]
    ) -> Int {
        if tier == .avoid {
            let na = sodiumMgPer100g ?? 800
            let base = max(0, 28 - (na / 80))
            return Int(min(35, max(0, base)).rounded())
        }

        let kScore = potassiumComponent(potassiumMgPer100g)
        let naScore = lowSodiumComponent(sodiumMgPer100g)
        let mgScore = magnesiumComponent(magnesiumMgPer100g)
        var raw = kScore * 0.45 + naScore * 0.35 + mgScore * 0.20

        if tags.contains("ultra-processed") { raw -= 18 }
        if tags.contains("evening-risk") { raw -= 10 }
        if tier == .hero { raw = max(raw, 82) }
        if tier == .moderate { raw = min(raw, 62) }

        return Int(min(100, max(0, raw)).rounded())
    }

    private static func potassiumComponent(_ value: Double?) -> Double {
        guard let value else { return 40 }
        if value >= 400 { return 100 }
        if value >= 200 { return 60 + ((value - 200) / 200) * 40 }
        return max(12, (value / 200) * 60)
    }

    private static func lowSodiumComponent(_ value: Double?) -> Double {
        guard let value else { return 55 }
        if value <= 50 { return 100 }
        if value <= 200 { return 100 - ((value - 50) / 150) * 25 }
        if value >= 800 { return 8 }
        return 75 - ((value - 200) / 600) * 67
    }

    private static func magnesiumComponent(_ value: Double?) -> Double {
        guard let value else { return 35 }
        if value >= 150 { return 100 }
        if value >= 50 { return 55 + ((value - 50) / 100) * 45 }
        return max(10, (value / 50) * 55)
    }
}

enum DebloatFoodNameNormalizer {
    static func normalize(_ raw: String) -> String {
        raw
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
            .lowercased()
            .replacingOccurrences(of: "œ", with: "oe")
            .replacingOccurrences(of: "æ", with: "ae")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func tokens(_ raw: String) -> [String] {
        let normalized = normalize(raw)
        return normalized
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 }
    }
}
