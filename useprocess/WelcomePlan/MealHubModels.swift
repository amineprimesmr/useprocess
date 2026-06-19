import Foundation

// MARK: - Créneaux repas

enum MealTimeSlot: String, Codable, CaseIterable, Identifiable {
    case breakfast = "Petit-déjeuner"
    case lunch = "Déjeuner"
    case dinner = "Dîner"
    case snack = "Collation"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"
        case .snack: return "leaf.fill"
        }
    }

    static func from(mealType: String) -> MealTimeSlot {
        let lower = mealType.lowercased()
        if lower.contains("petit") || lower.contains("pdj") { return .breakfast }
        if lower.contains("dîner") || lower.contains("diner") { return .dinner }
        if lower.contains("collation") || lower.contains("snack") { return .snack }
        return .lunch
    }
}

// MARK: - Scores décomposés

struct MealSubScores: Codable, Equatable {
    var protocolFit: Int
    var satiety: Int
    var antiBloat: Int

    static var balanced: MealSubScores {
        MealSubScores(protocolFit: 75, satiety: 75, antiBloat: 75)
    }

    var average: Int {
        (protocolFit + satiety + antiBloat) / 3
    }
}

// MARK: - Liste courses

struct MealShoppingItem: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var quantity: String
    var isChecked: Bool
    var dayId: String?
    var addedAt: Date

    init(
        id: String = UUID().uuidString,
        name: String,
        quantity: String,
        isChecked: Bool = false,
        dayId: String? = nil,
        addedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.isChecked = isChecked
        self.dayId = dayId
        self.addedAt = addedAt
    }
}

// MARK: - Historique

struct MealHistoryEntry: Codable, Identifiable, Equatable {
    let id: String
    let dayId: String
    let validatedAt: Date
    var mealPayload: String
    var mealSlot: MealTimeSlot
    var protocolScore: Int

    init(
        id: String = UUID().uuidString,
        dayId: String,
        validatedAt: Date = Date(),
        mealPayload: String,
        mealSlot: MealTimeSlot,
        protocolScore: Int
    ) {
        self.id = id
        self.dayId = dayId
        self.validatedAt = validatedAt
        self.mealPayload = mealPayload
        self.mealSlot = mealSlot
        self.protocolScore = protocolScore
    }

    var content: MealSuggestionContent? {
        MealSuggestionContent.fromStored(mealPayload)
    }
}

// MARK: - Feedback post-repas

enum MealFeeling: String, Codable, CaseIterable, Identifiable {
    case great = "Super"
    case ok = "Correct"
    case heavy = "Ballonné"
    case tired = "Fatigué"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .great: return "face.smiling.fill"
        case .ok: return "face.smiling"
        case .heavy: return "wind"
        case .tired: return "moon.zzz.fill"
        }
    }
}

struct MealFeedbackEntry: Codable, Identifiable, Equatable {
    let id: String
    let dayId: String
    let mealHistoryId: String?
    var rating: Int
    var feeling: MealFeeling
    var note: String
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        dayId: String,
        mealHistoryId: String? = nil,
        rating: Int,
        feeling: MealFeeling,
        note: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.dayId = dayId
        self.mealHistoryId = mealHistoryId
        self.rating = rating
        self.feeling = feeling
        self.note = note
        self.createdAt = createdAt
    }
}
