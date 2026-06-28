import Foundation

struct PlanMealsDayBundle: Identifiable, Equatable {
    let date: Date
    let day: OriginProgramDay
    let entries: [PlanDayMealEntry]

    var id: String { day.id }

    var validatedCount: Int {
        entries.filter(\.isValidated).count
    }
}

enum PlanMealsOverviewProvider {

    /// Jours du protocole à partir d’une date (inclus), ordre calendaire.
    @MainActor
    static func loadDayBundles(
        plan: FaceOriginPlan,
        from anchorDate: Date,
        store: WelcomePlanStore,
        limit: Int? = nil
    ) -> [PlanMealsDayBundle] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: anchorDate)
        var bundles: [PlanMealsDayBundle] = []
        let scanCap = max(plan.calendar.totalDays + 14, 30)

        for offset in 0..<scanCap {
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { break }
            guard let day = OriginPlanPresenter.programDay(in: plan, for: date) else {
                if offset > 0, bundles.isEmpty == false { break }
                continue
            }

            PlanDayMealsProvider.ensureDefaultDrafts(plan: plan, day: day, store: store)
            let entries = PlanDayMealsProvider.entries(plan: plan, day: day, store: store)
            bundles.append(PlanMealsDayBundle(date: date, day: day, entries: entries))

            if let limit, bundles.count >= limit { break }
        }

        return bundles
    }

    static func dayTitle(for date: Date, relativeTo now: Date = Date()) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Aujourd’hui" }
        if calendar.isDateInTomorrow(date) { return "Demain" }
        let df = DateFormatter()
        df.locale = Locale(identifier: "fr_FR")
        df.setLocalizedDateFormatFromTemplate("EEEE d MMM")
        return df.string(from: date)
    }

    static func daySubtitle(for date: Date, day: OriginProgramDay) -> String {
        "Jour \(day.globalDayIndex + 1) · \(day.weekdayLabel)"
    }
}
