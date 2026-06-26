import Foundation

struct PlanHomeGreeting: Equatable {
    let line: String
    let emoji: String
}

/// Titre accueil Plan — action prioritaire du jour, sinon moment de la journée.
enum PlanHomeGreetingBuilder {
    static func make(
        firstName: String,
        now: Date = Date(),
        selectedDate: Date,
        plan: FaceOriginPlan?,
        isScanDue: Bool,
        hasAnyFaceScan: Bool
    ) -> PlanHomeGreeting {
        let calendar = Calendar.current
        let viewingToday = calendar.isDateInToday(selectedDate)

        if viewingToday, let action = priorityAction(
            firstName: firstName,
            now: now,
            plan: plan,
            isScanDue: isScanDue,
            hasAnyFaceScan: hasAnyFaceScan
        ) {
            return action
        }

        if !viewingToday {
            return pastOrFutureGreeting(for: selectedDate, now: now, firstName: firstName)
        }

        return timeOfDayGreeting(now: now, firstName: firstName)
    }

  // MARK: - Actions (priorité)

    private static func priorityAction(
        firstName: String,
        now: Date,
        plan: FaceOriginPlan?,
        isScanDue: Bool,
        hasAnyFaceScan: Bool
    ) -> PlanHomeGreeting? {
        if !hasAnyFaceScan {
            return .init(line: "Premier scan visage", emoji: "📸")
        }

        if isScanDue {
            return .init(line: "Scan visage du jour", emoji: "📸")
        }

        guard let plan else { return nil }

        let availability = OriginPlanPresenter.journalDayAvailability(for: now, in: plan)
        guard case .editable(let day, _) = availability else { return nil }

        if !OriginPlanPresenter.isDayJournalFilled(plan: plan, day: day) {
            return .init(line: withName("Checklist du jour", firstName: firstName), emoji: "✅")
        }

        if let mealGreeting = unvalidatedMealGreeting(plan: plan, day: day, now: now, firstName: firstName) {
            return mealGreeting
        }

        if day.training != nil {
            return .init(line: "Séance du jour", emoji: "💪")
        }

        if OriginPlanPresenter.isDayJournalFilled(plan: plan, day: day) {
            return .init(line: withName("Journée validée", firstName: firstName), emoji: "🔥")
        }

        return nil
    }

    private static func unvalidatedMealGreeting(
        plan: FaceOriginPlan,
        day: OriginProgramDay,
        now: Date,
        firstName: String
    ) -> PlanHomeGreeting? {
        let slots = plan.configuredMealSlots
        guard !slots.isEmpty else { return nil }

        let validated = Set(
            slots.filter { slot in
                plan.progress.validatedMealsBySlot[day.id]?[slot.rawValue] != nil
            }
        )

        let focusSlot = PlanMealSlotLabel.preferredSlot(
            in: slots,
            planType: plan.nutritionPlanType,
            validated: validated,
            now: now
        )

        guard !validated.contains(focusSlot) else { return nil }

        let slotLabel = mealActionLabel(for: focusSlot, planType: plan.nutritionPlanType)
        return .init(line: slotLabel, emoji: "🍽️")
    }

    private static func mealActionLabel(for slot: MealTimeSlot, planType: NutritionPlanType) -> String {
        if planType == .omad, slot == .lunch {
            return "Valide ton repas"
        }
        switch slot {
        case .breakfast: return "Petit-déj à valider"
        case .lunch: return "Déjeuner à valider"
        case .dinner: return "Dîner à valider"
        case .snack: return "Collation à valider"
        }
    }

    // MARK: - Temps

    private static func timeOfDayGreeting(now: Date, firstName: String) -> PlanHomeGreeting {
        let hour = Calendar.current.component(.hour, from: now)

        switch hour {
        case 5..<11:
            return .init(line: withName("Bon matin", firstName: firstName), emoji: "☀️")
        case 11..<14:
            return .init(line: withName("Bon appétit", firstName: firstName), emoji: "🍽️")
        case 14..<18:
            return .init(line: withName("Bel après-midi", firstName: firstName), emoji: "🌤️")
        case 18..<22:
            return .init(line: withName("Bonne soirée", firstName: firstName), emoji: "🌙")
        default:
            return .init(line: withName("Repos bien", firstName: firstName), emoji: "😴")
        }
    }

    private static func pastOrFutureGreeting(for date: Date, now: Date, firstName: String) -> PlanHomeGreeting {
        let calendar = Calendar.current
        if calendar.isDateInYesterday(date) {
            return .init(line: withName("Hier", firstName: firstName), emoji: "📋")
        }
        if date > calendar.startOfDay(for: now) {
            return .init(line: "Jour à venir", emoji: "📅")
        }
        return .init(line: withName("Ta journée", firstName: firstName), emoji: "📋")
    }

    private static func withName(_ prefix: String, firstName: String) -> String {
        let name = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return prefix }
        return "\(prefix), \(name)"
    }
}
