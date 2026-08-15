import SwiftUI

/// Profil — heatmap 12 mois × 31 jours, style Training Log.
struct ProfileActivityLogSection: View {
    @Environment(\.appTheme) private var theme
    @Bindable private var scanStore = FaceScanHistoryStore.shared
    @Bindable private var trajectoryStore = ProcessDebloatTrajectoryStore.shared
    @Bindable private var hydrationStore = ProcessHydrationLogStore.shared

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = ProcessAppLanguage.shared.locale
        return cal
    }

    private var today: Date {
        calendar.startOfDay(for: Date())
    }

    private var year: Int {
        calendar.component(.year, from: today)
    }

    private var monthLetters: [String] {
        calendar.veryShortMonthSymbols.map { symbol in
            String(symbol.prefix(1)).uppercased()
        }
    }

    var body: some View {
        let levels = activityLevels()

        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(AppCopy.t("Journal d'activité", en: "Training Log"))
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(theme.primaryText)

                Text(AppCopy.t(
                    "Douze mois de ton évolution",
                    en: "A twelve month review of your training"
                ))
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(theme.secondaryText)
            }

            heatmap(levels: levels)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary(levels: levels))
    }

    private func heatmap(levels: [String: Int]) -> some View {
        VStack(spacing: Layout.gap) {
            ForEach(0..<12, id: \.self) { monthIndex in
                HStack(spacing: Layout.gap) {
                    Text(monthLetters[monthIndex])
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(theme.secondaryText.opacity(0.72))
                        .frame(width: Layout.labelWidth)
                        .frame(maxHeight: .infinity)
                        .accessibilityHidden(true)

                    ForEach(1...31, id: \.self) { day in
                        dayCell(month: monthIndex + 1, day: day, levels: levels)
                    }
                }
            }
        }
    }

    private func dayCell(month: Int, day: Int, levels: [String: Int]) -> some View {
        let date = dateInYear(month: month, day: day)
        let isToday = date.map { calendar.isDate($0, inSameDayAs: today) } ?? false
        let isFuture = date.map { $0 > today } ?? false
        let level: Int = {
            guard let date else { return 0 }
            return levels[ProcessStreakStore.dayKey(for: date, calendar: calendar)] ?? 0
        }()

        return RoundedRectangle(cornerRadius: Layout.corner, style: .continuous)
            .fill(
                date == nil
                    ? Color.clear
                    : cellColor(level: level, isToday: isToday, isFuture: isFuture)
            )
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: .infinity)
    }

    private func dateInYear(month: Int, day: Int) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        guard let date = calendar.date(from: components) else { return nil }
        if calendar.component(.month, from: date) != month { return nil }
        return calendar.startOfDay(for: date)
    }

    private func activityLevels() -> [String: Int] {
        var levels: [String: Int] = [:]

        func bump(_ key: String, by amount: Int = 1) {
            levels[key, default: 0] = min(4, levels[key, default: 0] + amount)
        }

        for scan in scanStore.history {
            bump(ProcessStreakStore.dayKey(for: scan.createdAt, calendar: calendar), by: 2)
        }

        for (key, record) in trajectoryStore.allRecordsByDay {
            switch record.verdict {
            case .excellent:
                bump(key, by: 2)
            case .onTrack, .partial:
                bump(key, by: 1)
            default:
                if record.checkInSubmitted { bump(key, by: 1) }
            }
        }

        for (key, log) in hydrationStore.logsByDay where log.milliliters > 0 {
            bump(key)
        }

        return levels
    }

    private func cellColor(level: Int, isToday: Bool, isFuture: Bool) -> Color {
        if isToday {
            return Layout.todayFill
        }
        if isFuture || level <= 0 {
            return theme.isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.07)
        }
        switch level {
        case 1:
            return Color(red: 0.10, green: 0.32, blue: 0.20)
        case 2:
            return Color(red: 0.16, green: 0.50, blue: 0.30)
        case 3:
            return Color(red: 0.30, green: 0.72, blue: 0.42)
        default:
            return Color(red: 0.62, green: 0.90, blue: 0.70)
        }
    }

    private func accessibilitySummary(levels: [String: Int]) -> String {
        let activeDays = levels.filter { $0.value > 0 }.count
        return AppCopy.t(
            "Journal d'activité, \(activeDays) jour\(activeDays > 1 ? "s" : "") actif\(activeDays > 1 ? "s" : "") en \(year)",
            en: activeDays == 1
                ? "Training log, 1 active day in \(year)"
                : "Training log, \(activeDays) active days in \(year)"
        )
    }

    private enum Layout {
        static let todayFill = Color(red: 0.97, green: 0.86, blue: 0.20)
        static let labelWidth: CGFloat = 10
        static let gap: CGFloat = 2.15
        static let corner: CGFloat = 2.1
    }
}
