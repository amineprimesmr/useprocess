import Foundation
import SwiftUI

// MARK: - Verdict & tendance

enum DebloatDayVerdict: String, nonisolated Codable, Equatable, CaseIterable, Sendable {
    case excellent
    case onTrack
    case partial
    case regression
    case pending
    case missed
    case paused

    var countsForStreak: Bool {
        switch self {
        case .excellent, .onTrack:
            return true
        case .partial, .regression, .pending, .missed, .paused:
            return false
        }
    }

    @MainActor
    var shortLabel: String {
        switch self {
        case .excellent: return AppCopy.t("Excellent", en: "Excellent")
        case .onTrack: return AppCopy.t("Sur la bonne voie", en: "On track")
        case .partial: return AppCopy.t("Partiel", en: "Partial")
        case .regression: return AppCopy.t("Régression", en: "Regression")
        case .pending: return AppCopy.t("En attente", en: "Pending")
        case .missed: return AppCopy.t("Manqué", en: "Missed")
        case .paused: return AppCopy.t("Pause", en: "Paused")
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
        case .pending:
            return Color(red: 0.55, green: 0.58, blue: 0.65)
        case .missed:
            return Color(red: 0.55, green: 0.55, blue: 0.58)
        case .paused:
            return Color(red: 0.42, green: 0.58, blue: 0.95)
        }
    }
}

enum TrajectoryTrend: String, nonisolated Codable, Equatable, Sendable {
    case accelerating
    case stable
    case regressing
    case unknown

    @MainActor
    var label: String {
        switch self {
        case .accelerating: return AppCopy.t("Accélération", en: "Accelerating")
        case .stable: return AppCopy.t("Stable", en: "Stable")
        case .regressing: return AppCopy.t("Ralentissement", en: "Slowing")
        case .unknown: return AppCopy.t("En cours", en: "In progress")
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

struct DebloatDayRecord: nonisolated Codable, Equatable, Identifiable, Sendable {
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

struct ProcessDebloatTrajectoryState: nonisolated Codable, Equatable, Sendable {
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

    @MainActor
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

    @MainActor
    var streakTitle: String {
        switch totalValidatedDays {
        case 0: return AppCopy.t("Jours validés", en: "Validated Days")
        case 1: return AppCopy.t("1 jour validé", en: "1 Validated Day")
        default: return AppCopy.t(
            "\(totalValidatedDays) jours validés",
            en: "\(totalValidatedDays) Validated Days"
        )
        }
    }

    @MainActor
    func encouragement(firstName: String?) -> String {
        let trimmed = firstName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let nameSuffix = trimmed.isEmpty ? "" : ", \(trimmed)"

        switch todayVerdict {
        case .excellent:
            return AppCopy.t(
                "Journée solide\(nameSuffix) — ta trajectoire accélère.",
                en: "Strong day\(nameSuffix) — your trajectory is accelerating."
            )
        case .onTrack:
            return AppCopy.t(
                "Tu restes sur la bonne voie\(nameSuffix).",
                en: "You're staying on track\(nameSuffix)."
            )
        case .partial:
            return AppCopy.t(
                "Journée partielle\(nameSuffix) — demain on serre le protocole.",
                en: "Partial day\(nameSuffix) — tighten the protocol tomorrow."
            )
        case .regression:
            return AppCopy.t(
                "Régression détectée\(nameSuffix) — le coach t’aide à recaler.",
                en: "Regression detected\(nameSuffix) — the coach will help you recalibrate."
            )
        case .missed:
            return AppCopy.t(
                "Check manqué — valide-le pour continuer.",
                en: "Missed check-in — validate it to continue."
            )
        case .pending:
            return AppCopy.t(
                "Check du jour en attente — valide-le quand tu veux.",
                en: "Today's check-in pending — validate it whenever you're ready."
            )
        case .paused, .none:
            if totalValidatedDays >= 7 {
                return AppCopy.t(
                    "Régularité solide\(nameSuffix) — ne lâche pas.",
                    en: "Solid consistency\(nameSuffix) — don't quit."
                )
            }
            if totalValidatedDays > 0 {
                return AppCopy.t(
                    "Continue comme ça\(nameSuffix) !",
                    en: "Keep it up\(nameSuffix)!"
                )
            }
            return AppCopy.t(
                "Complète ton check pour lancer ta trajectoire\(nameSuffix).",
                en: "Complete your check-in to start your trajectory\(nameSuffix)."
            )
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
