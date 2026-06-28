import Foundation

/// Horaires repas debloat — cibles fixes par structure nutrition.
enum PlanMealSchedule {

    struct Timing: Equatable {
        let targetHour: Int
        let targetMinute: Int
        let windowStartHour: Int
        let windowStartMinute: Int
        let windowEndHour: Int
        let windowEndMinute: Int
        let debloatNote: String

        var targetLabel: String {
            Self.format(hour: targetHour, minute: targetMinute)
        }

        var windowLabel: String {
            "\(Self.format(hour: windowStartHour, minute: windowStartMinute)) – \(Self.format(hour: windowEndHour, minute: windowEndMinute))"
        }

        var carouselSubtitle: String {
            "\(targetLabel) · \(windowLabel)"
        }

        private static func format(hour: Int, minute: Int) -> String {
            guard minute > 0 else { return "\(hour)h" }
            return String(format: "%dh%02d", hour, minute)
        }
    }

    static func timing(for slot: MealTimeSlot, planType: NutritionPlanType) -> Timing? {
        switch planType {
        case .threeMeals:
            switch slot {
            case .breakfast:
                return Timing(
                    targetHour: 8, targetMinute: 30,
                    windowStartHour: 7, windowStartMinute: 30,
                    windowEndHour: 8, windowEndMinute: 30,
                    debloatNote: "Protéines tôt — lance la journée sans pic glycémique ni rétention."
                )
            case .lunch:
                return Timing(
                    targetHour: 13, targetMinute: 0,
                    windowStartHour: 12, windowStartMinute: 30,
                    windowEndHour: 13, windowEndMinute: 30,
                    debloatNote: "Repas le plus dense — digestion optimale en milieu de journée."
                )
            case .dinner:
                return Timing(
                    targetHour: 19, targetMinute: 0,
                    windowStartHour: 18, windowStartMinute: 30,
                    windowEndHour: 19, windowEndMinute: 30,
                    debloatNote: "Sel modéré — finir avant 20 h limite le gonflement du lendemain."
                )
            case .snack:
                return Timing(
                    targetHour: 16, targetMinute: 0,
                    windowStartHour: 16, windowStartMinute: 0,
                    windowEndHour: 16, windowEndMinute: 30,
                    debloatNote: "Seulement si faim réelle — fruit ou fromage, pas de grignotage sucré."
                )
            }

        case .twoMAD:
            switch slot {
            case .lunch:
                return Timing(
                    targetHour: 13, targetMinute: 0,
                    windowStartHour: 12, windowStartMinute: 30,
                    windowEndHour: 13, windowEndMinute: 30,
                    debloatNote: "Premier repas dense — casse le jeûne sans surcharge digestive."
                )
            case .dinner:
                return Timing(
                    targetHour: 19, targetMinute: 0,
                    windowStartHour: 18, windowStartMinute: 30,
                    windowEndHour: 19, windowEndMinute: 30,
                    debloatNote: "Second repas plus léger en sel — 5 h minimum après le déjeuner."
                )
            default:
                return nil
            }

        case .omad:
            guard slot == .lunch else { return nil }
            return Timing(
                targetHour: 18, targetMinute: 30,
                windowStartHour: 17, windowStartMinute: 30,
                windowEndHour: 20, windowEndMinute: 0,
                debloatNote: "Repas unique très dense — fenêtre fermée à 20 h pour debloat et sommeil."
            )
        }
    }

    /// Heure cible affichée sur les cartes repas.
    static func targetLabel(for slot: MealTimeSlot, planType: NutritionPlanType) -> String? {
        timing(for: slot, planType: planType)?.targetLabel
    }

    /// Fenêtre horaire complète pour le détail repas.
    static func windowLabel(for slot: MealTimeSlot, planType: NutritionPlanType) -> String? {
        timing(for: slot, planType: planType)?.windowLabel
    }

    /// Fin de fenêtre (heure) — pour le focus automatique du carousel.
    static func windowEndHour(for slot: MealTimeSlot, planType: NutritionPlanType) -> Int? {
        timing(for: slot, planType: planType)?.windowEndHour
    }

    static func windowStartDate(
        for slot: MealTimeSlot,
        planType: NutritionPlanType,
        on dayDate: Date,
        calendar: Calendar = .current
    ) -> Date? {
        guard let timing = timing(for: slot, planType: planType) else { return nil }
        let dayStart = calendar.startOfDay(for: dayDate)
        return calendar.date(
            bySettingHour: timing.windowStartHour,
            minute: timing.windowStartMinute,
            second: 0,
            of: dayStart
        )
    }

    static func windowEndDate(
        for slot: MealTimeSlot,
        planType: NutritionPlanType,
        on dayDate: Date,
        calendar: Calendar = .current
    ) -> Date? {
        guard let timing = timing(for: slot, planType: planType) else { return nil }
        let dayStart = calendar.startOfDay(for: dayDate)
        return calendar.date(
            bySettingHour: timing.windowEndHour,
            minute: timing.windowEndMinute,
            second: 0,
            of: dayStart
        )
    }
}

// MARK: - Compte à rebours repas

enum PlanMealCountdown {
    enum Presentation: Equatable {
        case validated
        case active
        case counting(seconds: TimeInterval)
        case ended
        case hidden
    }

    static func presentation(
        slot: MealTimeSlot,
        planType: NutritionPlanType,
        dayDate: Date,
        isValidated: Bool,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Presentation {
        if isValidated { return .validated }

        guard let windowStart = PlanMealSchedule.windowStartDate(for: slot, planType: planType, on: dayDate, calendar: calendar),
              let windowEnd = PlanMealSchedule.windowEndDate(for: slot, planType: planType, on: dayDate, calendar: calendar)
        else { return .hidden }

        let dayStart = calendar.startOfDay(for: dayDate)
        let todayStart = calendar.startOfDay(for: now)

        if dayStart < todayStart { return .hidden }

        if now >= windowEnd { return .ended }
        if now >= windowStart { return .active }

        let interval = windowStart.timeIntervalSince(now)
        guard interval > 0 else { return .active }
        return .counting(seconds: interval)
    }

    static func components(for seconds: TimeInterval) -> (hours: Int, minutes: Int, seconds: Int) {
        let total = max(0, Int(seconds.rounded(.down)))
        return (total / 3600, (total % 3600) / 60, total % 60)
    }
}
