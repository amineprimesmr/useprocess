import Foundation
import SwiftUI

// MARK: - Verdict & tendance

enum DebloatDayVerdict: String, Codable, Equatable, CaseIterable {
    case excellent
    case onTrack
    case partial
    case regression
    case missed
    case paused

    var countsForStreak: Bool {
        switch self {
        case .excellent, .onTrack:
            return true
        case .partial, .regression, .missed, .paused:
            return false
        }
    }

    var shortLabel: String {
        switch self {
        case .excellent: return "Excellent"
        case .onTrack: return "Sur la bonne voie"
        case .partial: return "Partiel"
        case .regression: return "Régression"
        case .missed: return "Manqué"
        case .paused: return "Pause"
        }
    }

    var chartColor: Color {
        switch self {
        case .excellent:
            return Color(red: 0.35, green: 0.78, blue: 0.45)
        case .onTrack:
            return Color(red: 0.45, green: 0.82, blue: 0.62)
        case .partial:
            return Color(red: 1.0, green: 0.72, blue: 0.28)
        case .regression:
            return Color(red: 0.92, green: 0.38, blue: 0.38)
        case .missed:
            return Color(red: 0.55, green: 0.55, blue: 0.58)
        case .paused:
            return Color(red: 0.42, green: 0.58, blue: 0.95)
        }
    }
}

enum TrajectoryTrend: String, Codable, Equatable {
    case accelerating
    case stable
    case regressing
    case unknown

    var label: String {
        switch self {
        case .accelerating: return "Accélération"
        case .stable: return "Stable"
        case .regressing: return "Ralentissement"
        case .unknown: return "En cours"
        }
    }

    var systemImage: String {
        switch self {
        case .accelerating: return "arrow.up.right"
        case .stable: return "arrow.right"
        case .regressing: return "arrow.down.right"
        case .unknown: return "ellipsis"
        }
    }
}

// MARK: - Enregistrement journalier

struct DebloatDayRecord: Codable, Equatable, Identifiable {
    var dayKey: String
    var checkInSubmitted: Bool
    var water: Bool?
    var debloatMeal: Bool?
    var cardio: Bool?
    var behaviorScore: Double
    var scanId: String?
    var relativeFaceScore: Int?
    var puffinessDelta: Int?
    var scanScore: Double?
    var compositeScore: Double
    var verdict: DebloatDayVerdict
    var streakAfterDay: Int
    var graceUsed: Bool
    var aiSummary: String?
    var trajectoryTrend: TrajectoryTrend

    var id: String { dayKey }

    var yesCount: Int {
        [water, debloatMeal, cardio].filter { $0 == true }.count
    }

    func countsAsValidatedDay(consecutiveCardioMissesBefore: Int) -> Bool {
        ProcessDebloatTrajectoryEngine.countsAsValidatedDay(
            record: self,
            consecutiveCardioMissesBefore: consecutiveCardioMissesBefore
        )
    }

    var hasScan: Bool { scanId != nil }

    enum CodingKeys: String, CodingKey {
        case dayKey, checkInSubmitted, water, debloatMeal, cardio, postureCircuit
        case behaviorScore, scanId, relativeFaceScore, puffinessDelta, scanScore
        case compositeScore, verdict, streakAfterDay, graceUsed, aiSummary, trajectoryTrend
    }

    init(
        dayKey: String,
        checkInSubmitted: Bool,
        water: Bool?,
        debloatMeal: Bool?,
        cardio: Bool?,
        behaviorScore: Double,
        scanId: String?,
        relativeFaceScore: Int?,
        puffinessDelta: Int?,
        scanScore: Double?,
        compositeScore: Double,
        verdict: DebloatDayVerdict,
        streakAfterDay: Int,
        graceUsed: Bool,
        aiSummary: String?,
        trajectoryTrend: TrajectoryTrend
    ) {
        self.dayKey = dayKey
        self.checkInSubmitted = checkInSubmitted
        self.water = water
        self.debloatMeal = debloatMeal
        self.cardio = cardio
        self.behaviorScore = behaviorScore
        self.scanId = scanId
        self.relativeFaceScore = relativeFaceScore
        self.puffinessDelta = puffinessDelta
        self.scanScore = scanScore
        self.compositeScore = compositeScore
        self.verdict = verdict
        self.streakAfterDay = streakAfterDay
        self.graceUsed = graceUsed
        self.aiSummary = aiSummary
        self.trajectoryTrend = trajectoryTrend
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dayKey = try container.decode(String.self, forKey: .dayKey)
        checkInSubmitted = try container.decode(Bool.self, forKey: .checkInSubmitted)
        water = try container.decodeIfPresent(Bool.self, forKey: .water)
        debloatMeal = try container.decodeIfPresent(Bool.self, forKey: .debloatMeal)
        cardio = try container.decodeIfPresent(Bool.self, forKey: .cardio)
            ?? container.decodeIfPresent(Bool.self, forKey: .postureCircuit)
        behaviorScore = try container.decode(Double.self, forKey: .behaviorScore)
        scanId = try container.decodeIfPresent(String.self, forKey: .scanId)
        relativeFaceScore = try container.decodeIfPresent(Int.self, forKey: .relativeFaceScore)
        puffinessDelta = try container.decodeIfPresent(Int.self, forKey: .puffinessDelta)
        scanScore = try container.decodeIfPresent(Double.self, forKey: .scanScore)
        compositeScore = try container.decode(Double.self, forKey: .compositeScore)
        verdict = try container.decode(DebloatDayVerdict.self, forKey: .verdict)
        streakAfterDay = try container.decode(Int.self, forKey: .streakAfterDay)
        graceUsed = try container.decode(Bool.self, forKey: .graceUsed)
        aiSummary = try container.decodeIfPresent(String.self, forKey: .aiSummary)
        trajectoryTrend = try container.decode(TrajectoryTrend.self, forKey: .trajectoryTrend)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(dayKey, forKey: .dayKey)
        try container.encode(checkInSubmitted, forKey: .checkInSubmitted)
        try container.encodeIfPresent(water, forKey: .water)
        try container.encodeIfPresent(debloatMeal, forKey: .debloatMeal)
        try container.encodeIfPresent(cardio, forKey: .cardio)
        try container.encode(behaviorScore, forKey: .behaviorScore)
        try container.encodeIfPresent(scanId, forKey: .scanId)
        try container.encodeIfPresent(relativeFaceScore, forKey: .relativeFaceScore)
        try container.encodeIfPresent(puffinessDelta, forKey: .puffinessDelta)
        try container.encodeIfPresent(scanScore, forKey: .scanScore)
        try container.encode(compositeScore, forKey: .compositeScore)
        try container.encode(verdict, forKey: .verdict)
        try container.encode(streakAfterDay, forKey: .streakAfterDay)
        try container.encode(graceUsed, forKey: .graceUsed)
        try container.encodeIfPresent(aiSummary, forKey: .aiSummary)
        try container.encode(trajectoryTrend, forKey: .trajectoryTrend)
    }
}

struct ProcessDebloatTrajectoryState: Codable, Equatable {
    var recordsByDay: [String: DebloatDayRecord] = [:]
    var graceUsedDayKeys: Set<String> = []
    var consecutiveMisses: Int = 0
    var consecutiveCardioMisses: Int = 0
    var longestStreak: Int = 0
    var debloatJourneyConversationId: String?
    var schemaVersion: Int = 3
}

// MARK: - Snapshot UI

struct DebloatTrajectoryPoint: Identifiable, Equatable {
    let id: String
    let date: Date
    let compositeScore: Double
    let verdict: DebloatDayVerdict
    let hasScan: Bool
}

struct DebloatTrajectorySnapshot: Equatable {
    let currentStreak: Int
    let longestStreak: Int
    let todayCompositeScore: Double
    let todayVerdict: DebloatDayVerdict?
    let todayProgress: Double
    let isTodayComplete: Bool
    let trajectoryTrend: TrajectoryTrend
    let velocitySlope: Double
    let chartPoints: [DebloatTrajectoryPoint]
    let calendarWeek: [ProcessStreakDaySnapshot]
    let nextMilestone: ProcessStreakMilestone?
    let daysUntilNextMilestone: Int?
    let totalValidatedDays: Int

    var velocityLabel: String {
        if chartPoints.count < 3 { return TrajectoryTrend.unknown.label }
        if velocitySlope > 2.5 { return TrajectoryTrend.accelerating.label }
        if velocitySlope < -2.5 { return TrajectoryTrend.regressing.label }
        return TrajectoryTrend.stable.label
    }

    var velocityTrend: TrajectoryTrend {
        if chartPoints.count < 3 { return .unknown }
        if velocitySlope > 2.5 { return .accelerating }
        if velocitySlope < -2.5 { return .regressing }
        return .stable
    }

    var streakTitle: String {
        switch totalValidatedDays {
        case 0: return "Jours validés"
        case 1: return "1 jour validé"
        default: return "\(totalValidatedDays) jours validés"
        }
    }

    func encouragement(firstName: String?) -> String {
        let trimmed = firstName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let nameSuffix = trimmed.isEmpty ? "" : ", \(trimmed)"

        switch todayVerdict {
        case .excellent:
            return "Journée solide\(nameSuffix) — ta trajectoire accélère."
        case .onTrack:
            return "Tu restes sur la bonne voie\(nameSuffix)."
        case .partial:
            return "Journée partielle\(nameSuffix) — demain on serre le protocole."
        case .regression:
            return "Régression détectée\(nameSuffix) — le coach t’aide à recaler."
        case .missed:
            return "Bilan manqué — valide ce soir pour continuer."
        case .paused, .none:
            if totalValidatedDays >= 7 { return "Régularité solide\(nameSuffix) — ne lâche pas." }
            if totalValidatedDays > 0 { return "Continue comme ça\(nameSuffix) !" }
            return "Complète ton bilan du soir pour lancer ta trajectoire\(nameSuffix)."
        }
    }

    static let empty = DebloatTrajectorySnapshot(
        currentStreak: 0,
        longestStreak: 0,
        todayCompositeScore: 0,
        todayVerdict: nil,
        todayProgress: 0,
        isTodayComplete: false,
        trajectoryTrend: .unknown,
        velocitySlope: 0,
        chartPoints: [],
        calendarWeek: [],
        nextMilestone: ProcessStreakMilestone.catalog.first,
        daysUntilNextMilestone: ProcessStreakMilestone.catalog.first?.days,
        totalValidatedDays: 0
    )
}
