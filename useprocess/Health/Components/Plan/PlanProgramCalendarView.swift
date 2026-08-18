import SwiftUI
import UIKit

// MARK: - Page calendrier programme (plein écran)

struct PlanProgramCalendarView: View {
    @Binding var selectedDate: Date
    let plan: FaceOriginPlan?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    @Bindable private var trajectoryStore = ProcessDebloatTrajectoryStore.shared
    @Bindable private var planProgressStore = ProcessPlanProgressStore.shared
    @Bindable private var streakStore = ProcessStreakStore.shared
    @Bindable private var scanStore = FaceScanHistoryStore.shared

    @State private var displayedMonth: Date

    private var calendar: Calendar { Self.appCalendar }
    private var progress: PlanProgressSnapshot { planProgressStore.snapshot }

    private var calendarAccent: Color {
        Color(red: 0.22, green: 0.48, blue: 0.96)
    }

    init(selectedDate: Binding<Date>, plan: FaceOriginPlan?) {
        _selectedDate = selectedDate
        self.plan = plan
        let initial = Calendar.current.startOfDay(for: selectedDate.wrappedValue)
        _displayedMonth = State(initialValue: Self.startOfMonth(for: initial))
    }

    var body: some View {
        ZStack {
            ProcessScreenBackground()

            if let plan {
                calendarContent(plan: plan)
            } else {
                emptyPlanContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .top, spacing: 0) {
            topBar
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if plan != nil {
                bottomStatsBar
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .processClearUIKitHostingBackground()
        .processAppPageBackground()
        .onAppear {
            planProgressStore.reload(plan: plan)
            trajectoryStore.sync(from: plan)
            scanStore.reloadForUser(userId: UserScopedStorage.currentUserId())
        }
        .onChange(of: selectedDate) { _, newDate in
            let month = Self.startOfMonth(for: newDate)
            if !calendar.isDate(month, equalTo: displayedMonth, toGranularity: .month) {
                displayedMonth = month
            }
        }
    }

    // MARK: - Contenu principal

    @ViewBuilder
    private func calendarContent(plan: FaceOriginPlan) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heroHeader(plan: plan)
                calendarCard(plan: plan)
                selectedDayPanel(plan: plan)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    private var emptyPlanContent: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(theme.secondaryText.opacity(0.55))
            Text(AppCopy.t("Aucun plan actif", en: "No active plan"))
                .font(.title3.weight(.bold))
                .foregroundStyle(theme.primaryText)
            Text(AppCopy.t(
                "Complète la configuration pour afficher ton calendrier personnalisé.",
                en: "Finish setup to show your personalized calendar."
            ))
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    // MARK: - En-tête hero

    private func heroHeader(plan: FaceOriginPlan) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Self.monthHeroFormatter.string(from: displayedMonth))
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(theme.primaryText)
                .textCase(nil)

            Text(AppCopy.t(
                "Appuie sur un jour pour voir ce scan.",
                en: "Tap any day to see that scan."
            ))
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)

            HStack(alignment: .firstTextBaseline) {
                Text(AppCopy.t("PROGRESSION", en: "PROGRESS"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.secondaryText.opacity(0.72))
                    .tracking(0.6)

                Spacer(minLength: 8)

                Text(scansThisMonthLabel)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(calendarAccent)
                    .tracking(0.5)
                    .multilineTextAlignment(.trailing)
            }
        }
        .contentShape(Rectangle())
        .gesture(monthSwipeGesture(plan: plan))
    }

    private var scansThisMonthLabel: String {
        let count = scansInDisplayedMonth
        if count == 0 {
            return AppCopy.t("0 SCAN CE MOIS", en: "0 SCANS THIS MONTH")
        }
        return AppCopy.t(
            "\(count) SCAN\(count > 1 ? "S" : "") CE MOIS",
            en: count == 1 ? "1 SCAN THIS MONTH" : "\(count) SCANS THIS MONTH"
        )
    }

    private var scansInDisplayedMonth: Int {
        scanStore.history.filter {
            calendar.isDate($0.createdAt, equalTo: displayedMonth, toGranularity: .month)
        }.count
    }

    // MARK: - Carte calendrier

    private func calendarCard(plan: FaceOriginPlan) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            calendarCardHeader(plan: plan)
            weekdayHeaderRow
            calendarGrid(plan: plan)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
        .background(calendarCardBackground)
        .gesture(monthSwipeGesture(plan: plan))
    }

    private func calendarCardHeader(plan: FaceOriginPlan) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.secondaryText.opacity(0.75))

            Text(cardTitle)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 4)

            Button {
                shiftMonth(by: 1, plan: plan)
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(theme.secondaryText.opacity(0.55))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.processPlain)
            .accessibilityLabel(AppCopy.t("Mois suivant", en: "Next month"))
        }
    }

    private var cardTitle: String {
        let month = Self.monthCardFormatter.string(from: displayedMonth)
        return AppCopy.t(
            "Scans & Journal — \(month)",
            en: "Scans & Diary — \(month)"
        )
    }

    private var weekdayHeaderRow: some View {
        LazyVGrid(columns: Self.gridColumns, spacing: 10) {
            ForEach(Self.weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.secondaryText.opacity(0.62))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func calendarGrid(plan: FaceOriginPlan) -> some View {
        LazyVGrid(columns: Self.gridColumns, spacing: 10) {
            ForEach(gridCells(for: displayedMonth), id: \.timeIntervalSinceReferenceDate) { date in
                dayCell(date: date, plan: plan)
            }
        }
    }

    private func dayCell(date: Date, plan: FaceOriginPlan) -> some View {
        let model = dayModel(for: date, plan: plan)
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isCurrentMonth = calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month)

        return Button {
            HapticManager.shared.impact(.light)
            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                selectedDate = date
                if !isCurrentMonth {
                    displayedMonth = Self.startOfMonth(for: date)
                }
            }
        } label: {
            let diameter = PlanProgramCalendarDesign.cellDiameter
            ZStack {
                if let scan = model.scan {
                    PlanProgramCalendarScanThumb(scan: scan)
                        .frame(width: diameter, height: diameter)
                        .clipShape(Circle())
                        .opacity(isCurrentMonth ? 1 : 0.42)
                } else {
                    Circle()
                        .fill(circleFill(isCurrentMonth: isCurrentMonth, isSelected: isSelected))
                    Text("\(calendar.component(.day, from: date))")
                        .font(.system(size: 15, weight: isSelected ? .bold : .medium, design: .rounded))
                        .foregroundStyle(dayNumberColor(isCurrentMonth: isCurrentMonth, isSelected: isSelected))
                        .monospacedDigit()
                }

                Circle()
                    .strokeBorder(
                        isSelected
                            ? calendarAccent
                            : (model.scan == nil
                               ? Color.clear
                               : Color.white.opacity(theme.isDark ? 0.22 : 0.42)),
                        lineWidth: isSelected ? 2 : 0.6
                    )
            }
            .frame(width: diameter, height: diameter)
            .frame(maxWidth: .infinity)
            .frame(height: diameter)
        }
        .buttonStyle(PlanProgramCalendarDayButtonStyle())
        .accessibilityLabel(model.accessibilityLabel)
    }

    private func dayNumberColor(isCurrentMonth: Bool, isSelected: Bool) -> Color {
        if !isCurrentMonth {
            return theme.secondaryText.opacity(0.28)
        }
        return isSelected ? theme.primaryText : theme.primaryText.opacity(0.82)
    }

    private func circleFill(isCurrentMonth: Bool, isSelected: Bool) -> Color {
        if isSelected {
            return theme.isDark ? Color.white.opacity(0.10) : Color.white
        }
        if !isCurrentMonth {
            return theme.isDark ? Color.white.opacity(0.03) : Color.black.opacity(0.025)
        }
        return theme.isDark ? Color.white.opacity(0.07) : Color.black.opacity(0.045)
    }

    private var calendarCardBackground: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(theme.isDark ? Color.white.opacity(0.09) : Color.white)
            .shadow(
                color: Color.black.opacity(theme.isDark ? 0.22 : 0.06),
                radius: 18,
                x: 0,
                y: 8
            )
    }

    // MARK: - Barre stats bas

    private var bottomStatsBar: some View {
        HStack(spacing: 10) {
            bottomStatCard(
                label: AppCopy.t("SÉRIE", en: "STREAK"),
                value: streakValue,
                valueColor: theme.primaryText,
                labelColor: theme.secondaryText.opacity(0.72),
                fill: statCardFill
            )
            bottomStatCard(
                label: AppCopy.t("MEILLEUR JOUR", en: "BEST DAY"),
                value: bestDayLabel,
                valueColor: calendarAccent,
                labelColor: theme.secondaryText.opacity(0.72),
                fill: statCardFill
            )
            bottomStatCard(
                label: AppCopy.t("MANQUÉS", en: "SKIPPED"),
                value: "\(skippedDaysCount)",
                valueColor: .white,
                labelColor: .white.opacity(0.82),
                fill: calendarAccent
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(theme.cardStroke.opacity(theme.isDark ? 0.28 : 0.35))
                        .frame(height: 0.5)
                }
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func bottomStatCard(
        label: String,
        value: String,
        valueColor: Color,
        labelColor: Color,
        fill: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(labelColor)
                .tracking(0.5)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(valueColor)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(fill)
        }
    }

    private var statCardFill: Color {
        theme.isDark ? Color.white.opacity(0.10) : Color.white
    }

    private var streakValue: String {
        let days = streakStore.displayStreak
        return AppCopy.t("\(days)j", en: "\(days)d")
    }

    private var bestDayLabel: String {
        guard let record = bestDayRecord,
              let date = ProcessDebloatTrajectoryEngine.date(from: record.dayKey, calendar: calendar) else {
            return "—"
        }
        return Self.shortDayFormatter.string(from: date)
    }

    private var bestDayRecord: DebloatDayRecord? {
        trajectoryStore.allRecordsByDay.values
            .filter(\.checkInSubmitted)
            .max(by: { $0.compositeScore < $1.compositeScore })
    }

    private var skippedDaysCount: Int {
        trajectoryStore.allRecordsByDay.values.filter { $0.verdict == .missed }.count
    }

    // MARK: - Barre supérieure

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                HapticManager.shared.impact(.light)
                withAnimation(ProcessZoomTransitionID.presentationSpring) {
                    dismiss()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(theme.primaryText)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(theme.cardBackgroundStrong.opacity(theme.isDark ? 0.95 : 0.82))
                    )
            }
            .buttonStyle(.processPlain)
            .accessibilityLabel(AppCopy.close)

            Spacer(minLength: 8)

            if !Calendar.current.isDateInToday(selectedDate) {
                Button {
                    HapticManager.shared.impact(.light)
                    jumpToToday()
                } label: {
                    Text(AppCopy.today)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(calendarAccent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule(style: .continuous)
                                .fill(calendarAccent.opacity(0.14))
                        )
                }
                .buttonStyle(.processPlain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    // MARK: - Panneau jour sélectionné

    @ViewBuilder
    private func selectedDayPanel(plan: FaceOriginPlan) -> some View {
        let model = dayModel(for: selectedDate, plan: plan)

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(model.panelTitle)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(theme.primaryText)

                    Text(model.panelSubtitle(plan: plan))
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                statusPill(model: model)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(theme.isDark ? Color.white.opacity(0.08) : Color.white.opacity(0.88))
        )
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: selectedDate)
    }

    private func statusPill(model: PlanProgramCalendarDayModel) -> some View {
        Text(model.statusLabel)
            .font(.caption2.weight(.bold))
            .foregroundStyle(model.statusTint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(model.statusTint.opacity(0.14))
            )
    }

    // MARK: - Modèle jour

    private func dayModel(for date: Date, plan: FaceOriginPlan) -> PlanProgramCalendarDayModel {
        let dayStart = calendar.startOfDay(for: date)
        let availability = OriginPlanPresenter.journalDayAvailability(for: dayStart, in: plan)
        let programDay = OriginPlanPresenter.programDay(in: plan, for: dayStart)
        let dayKey = ProcessStreakStore.dayKey(for: dayStart, calendar: calendar)
        let record = trajectoryStore.allRecordsByDay[dayKey]
        let isValidated = record?.checkInSubmitted == true
            || ProcessEveningCheckInStore.shared.hasSubmitted(on: dayStart)
        let isToday = calendar.isDateInToday(dayStart)
        let isDebloatTarget = programDay.map { $0.globalDayIndex + 1 == progress.totalProgramDays } ?? false

        let status: PlanProgramCalendarDayStatus
        switch availability {
        case .outsidePlan:
            status = .outsidePlan
        case .future:
            status = .future
        case .editable:
            if isValidated, let record {
                status = .validated(record.verdict)
            } else if isToday {
                status = .today
            } else if record?.checkInSubmitted == true {
                status = .partial
            } else {
                status = .missed
            }
        }

        return PlanProgramCalendarDayModel(
            date: dayStart,
            programDay: programDay,
            programDayNumber: programDay.map { $0.globalDayIndex + 1 },
            isDebloatTarget: isDebloatTarget,
            isToday: isToday,
            status: status,
            record: record,
            scan: latestScan(on: dayStart)
        )
    }

    /// Dernier scan du jour avec une photo locale (historique newest-first).
    private func latestScan(on dayStart: Date) -> FaceScanResult? {
        guard let scan = scanStore.history.first(where: {
            calendar.isDate($0.createdAt, inSameDayAs: dayStart)
        }) else {
            return nil
        }
        let reconciled = FaceScanImageStore.reconcileMediaMetadata(for: scan)
        guard FaceScanImageStore.resolvedSnapshotFilename(for: reconciled) != nil else {
            return nil
        }
        return reconciled
    }

    // MARK: - Navigation mois

    private func monthSwipeGesture(plan: FaceOriginPlan) -> some Gesture {
        DragGesture(minimumDistance: 36)
            .onEnded { value in
                if value.translation.width < -40, canGoToNextMonth(plan: plan) {
                    shiftMonth(by: 1, plan: plan)
                } else if value.translation.width > 40, canGoToPreviousMonth(plan: plan) {
                    shiftMonth(by: -1, plan: plan)
                }
            }
    }

    private func shiftMonth(by value: Int, plan: FaceOriginPlan) {
        guard let next = calendar.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        HapticManager.shared.selection()
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
            displayedMonth = Self.startOfMonth(for: next)
        }
    }

    private func planDateRange(plan: FaceOriginPlan) -> (start: Date, end: Date)? {
        guard let start = plan.calendar.startedAt, plan.calendar.totalDays > 0 else { return nil }
        let startDay = calendar.startOfDay(for: start)
        guard let endDay = calendar.date(byAdding: .day, value: plan.calendar.totalDays - 1, to: startDay) else {
            return nil
        }
        return (startDay, endDay)
    }

    private func canGoToPreviousMonth(plan: FaceOriginPlan) -> Bool {
        guard let range = planDateRange(plan: plan),
              let prev = calendar.date(byAdding: .month, value: -1, to: displayedMonth) else { return true }
        let prevEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: Self.startOfMonth(for: prev)) ?? prev
        return prevEnd >= range.start
    }

    private func canGoToNextMonth(plan: FaceOriginPlan) -> Bool {
        guard let range = planDateRange(plan: plan),
              let next = calendar.date(byAdding: .month, value: 1, to: displayedMonth) else { return true }
        return next <= range.end
    }

    private func jumpToToday() {
        let today: Date
        if let plan {
            today = OriginPlanPresenter.preferredHomeDate(in: plan)
        } else {
            today = calendar.startOfDay(for: Date())
        }
        selectedDate = today
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
            displayedMonth = Self.startOfMonth(for: today)
        }
    }

    private func gridCells(for month: Date) -> [Date] {
        let monthStart = Self.startOfMonth(for: month)
        guard let dayRange = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }

        let weekday = calendar.component(.weekday, from: monthStart)
        let leadingDays = (weekday - calendar.firstWeekday + 7) % 7

        guard let gridStart = calendar.date(byAdding: .day, value: -leadingDays, to: monthStart) else {
            return []
        }

        let lastDayOfMonth = calendar.date(byAdding: .day, value: dayRange.count - 1, to: monthStart) ?? monthStart
        let trailingWeekday = calendar.component(.weekday, from: lastDayOfMonth)
        let trailingDays = (7 - ((trailingWeekday - calendar.firstWeekday + 7) % 7 + 1)) % 7
        let totalCells = leadingDays + dayRange.count + trailingDays

        return (0..<totalCells).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: gridStart)
        }
    }

    // MARK: - Utilitaires

    @MainActor
    private static var appCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = ProcessAppLanguage.shared.locale
        cal.firstWeekday = 2
        return cal
    }

    private static let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 7)

    @MainActor
    private static var weekdaySymbols: [String] {
        let cal = appCalendar
        return (0..<7).map { offset in
            let index = (cal.firstWeekday - 1 + offset) % 7
            return cal.veryShortWeekdaySymbols[index].uppercased()
        }
    }

    @MainActor
    private static var monthHeroFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = ProcessAppLanguage.shared.locale
        formatter.dateFormat = "MMMM."
        return formatter
    }

    @MainActor
    private static var monthCardFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = ProcessAppLanguage.shared.locale
        formatter.dateFormat = "MMMM"
        return formatter
    }

    @MainActor
    private static var shortDayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = ProcessAppLanguage.shared.locale
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter
    }

    @MainActor
    private static func startOfMonth(for date: Date) -> Date {
        let components = appCalendar.dateComponents([.year, .month], from: date)
        return appCalendar.date(from: components) ?? date
    }
}

// MARK: - Modèle & design

private enum PlanProgramCalendarDesign {
    static let cellDiameter: CGFloat = 40
}

private enum PlanProgramCalendarDayStatus {
    case outsidePlan
    case future
    case today
    case inPlan
    case validated(DebloatDayVerdict)
    case partial
    case missed
}

private struct PlanProgramCalendarDayModel {
    let date: Date
    let programDay: OriginProgramDay?
    let programDayNumber: Int?
    let isDebloatTarget: Bool
    let isToday: Bool
    let status: PlanProgramCalendarDayStatus
    let record: DebloatDayRecord?
    let scan: FaceScanResult?

    @MainActor
    var panelTitle: String {
        if let programDayNumber {
            return AppCopy.t(
                "Jour \(programDayNumber) du programme",
                en: "Day \(programDayNumber) of the program"
            )
        }
        return formattedWideDate
    }

    @MainActor
    func panelSubtitle(plan: FaceOriginPlan) -> String {
        var parts: [String] = [formattedWideDate]
        if let programDay {
            if let week = plan.calendar.weeks.first(where: { $0.weekNumber == programDay.weekNumber }) {
                parts.append(week.phaseTitle)
            }
            if !programDay.title.isEmpty {
                parts.append(programDay.title)
            }
        }
        return parts.joined(separator: " · ")
    }

    @MainActor
    private var formattedWideDate: String {
        let df = DateFormatter()
        df.locale = ProcessAppLanguage.shared.locale
        df.setLocalizedDateFormatFromTemplate("EEEE d MMMM")
        return df.string(from: date)
    }

    @MainActor
    var statusLabel: String {
        switch status {
        case .outsidePlan: return AppCopy.t("Hors plan", en: "Outside plan")
        case .future: return AppCopy.t("À venir", en: "Upcoming")
        case .today: return AppCopy.today
        case .inPlan: return AppCopy.t("En cours", en: "In progress")
        case .validated(let verdict): return verdict.shortLabel
        case .partial: return AppCopy.t("Partiel", en: "Partial")
        case .missed: return AppCopy.t("Manqué", en: "Missed")
        }
    }

    var statusTint: Color {
        switch status {
        case .outsidePlan: return Color.secondary
        case .future: return Color(red: 0.42, green: 0.58, blue: 0.95)
        case .today: return Color(red: 0.35, green: 0.55, blue: 0.95)
        case .inPlan: return Color.secondary
        case .validated(let verdict): return verdict.chartColor
        case .partial: return Color(red: 1.0, green: 0.72, blue: 0.28)
        case .missed: return Color(red: 0.92, green: 0.38, blue: 0.38)
        }
    }

    @MainActor
    var accessibilityLabel: String {
        var parts = [panelTitle, statusLabel]
        if isToday { parts.append(AppCopy.today.lowercased()) }
        if isDebloatTarget {
            parts.append(AppCopy.t("objectif debloat", en: "debloat goal"))
        }
        if scan != nil {
            parts.append(AppCopy.t("scan visage enregistré", en: "face scan saved"))
        }
        return parts.joined(separator: ", ")
    }
}

/// Miniature ronde — photo du scan du jour (pas de vidéo, trop lourd dans la grille).
private struct PlanProgramCalendarScanThumb: View {
    let scan: FaceScanResult

    @State private var snapshot: UIImage?

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let framing = scan.resolvedStudioFraming

            Group {
                if let snapshot {
                    Image(uiImage: snapshot)
                        .resizable()
                        .scaledToFill()
                } else {
                    Circle()
                        .fill(Color.primary.opacity(0.08))
                }
            }
            .frame(width: side, height: side)
            .scaleEffect(framing.scale)
            .offset(
                x: CGFloat(framing.offsetX) * side,
                y: CGFloat(framing.offsetY) * side
            )
            .frame(width: side, height: side)
            .clipped()
        }
        .onAppear(perform: loadSnapshot)
        .onChange(of: scan.id) { _, _ in
            loadSnapshot()
        }
    }

    private func loadSnapshot() {
        let reconciled = FaceScanImageStore.reconcileMediaMetadata(for: scan)
        if let filename = FaceScanImageStore.resolvedSnapshotFilename(for: reconciled) {
            snapshot = FaceScanImageStore.load(filename: filename)
        } else {
            snapshot = nil
        }
    }
}

private struct PlanProgramCalendarDayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.78), value: configuration.isPressed)
    }
}

// MARK: - Compatibilité (alias sheet → plein écran)

typealias PlanHomeCalendarSheet = PlanProgramCalendarView
