import SwiftUI

// MARK: - Page calendrier programme (plein écran)

struct PlanProgramCalendarView: View {
    @Binding var selectedDate: Date
    let plan: FaceOriginPlan?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    @Bindable private var trajectoryStore = ProcessDebloatTrajectoryStore.shared
    @Bindable private var planProgressStore = ProcessPlanProgressStore.shared
    @Bindable private var streakStore = ProcessStreakStore.shared

    @State private var displayedMonth: Date

    private var calendar: Calendar { Self.frenchCalendar }
    private var progress: PlanProgressSnapshot { planProgressStore.snapshot }

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
        .toolbar(.hidden, for: .navigationBar)
        .processClearUIKitHostingBackground()
        .processAppPageBackground()
        .onAppear {
            planProgressStore.reload(plan: plan)
            trajectoryStore.sync(from: plan)
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
            VStack(alignment: .leading, spacing: 22) {
                progressSummaryCard()
                monthSection(plan: plan)
                selectedDayPanel(plan: plan)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .scrollIndicators(.hidden)
    }

    private var emptyPlanContent: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(theme.secondaryText.opacity(0.55))
            Text("Aucun plan actif")
                .font(.title3.weight(.bold))
                .foregroundStyle(theme.primaryText)
            Text("Complète la configuration pour afficher ton calendrier personnalisé.")
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
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
            .buttonStyle(.plain)
            .accessibilityLabel("Fermer")

            Spacer(minLength: 8)

            VStack(spacing: 2) {
                Text("Calendrier")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(theme.primaryText)
                if progress.hasPlan {
                    Text("Programme debloat · \(progress.totalProgramDays) jours")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(theme.secondaryText)
                        .monospacedDigit()
                }
            }

            Spacer(minLength: 8)

            if !Calendar.current.isDateInToday(selectedDate) {
                Button {
                    HapticManager.shared.impact(.light)
                    jumpToToday()
                } label: {
                    Text("Aujourd'hui")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.onboardingAccent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule(style: .continuous)
                                .fill(theme.onboardingAccent.opacity(0.14))
                        )
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(theme.cardStroke.opacity(theme.isDark ? 0.35 : 0.5))
                        .frame(height: 0.5)
                }
                .ignoresSafeArea(edges: .top)
        }
    }

    // MARK: - Résumé progression

    private func progressSummaryCard() -> some View {
        HStack(spacing: 0) {
            summaryMetric(
                value: "\(progress.elapsedProgramDays)",
                suffix: "/\(progress.totalProgramDays)",
                label: "Jours écoulés",
                tint: theme.onboardingAccent
            )

            summaryDivider

            summaryMetric(
                value: "\(streakStore.displayValidatedDays)",
                suffix: nil,
                label: "Jours validés",
                tint: ProcessStreakPalette.flame
            )

            summaryDivider

            summaryMetric(
                value: "S\(progress.currentWeek)",
                suffix: nil,
                label: progress.weeksLabel.isEmpty ? "Semaine" : progress.weeksLabel,
                tint: Color(red: 0.45, green: 0.72, blue: 0.95)
            )
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(summaryCardBackground)
        .accessibilityElement(children: .combine)
    }

    private func summaryMetric(value: String, suffix: String?, label: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
                    .monospacedDigit()
                if let suffix {
                    Text(suffix)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.secondaryText.opacity(0.85))
                        .monospacedDigit()
                }
            }
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(theme.secondaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
    }

    private var summaryDivider: some View {
        Rectangle()
            .fill(theme.cardStroke.opacity(theme.isDark ? 0.35 : 0.45))
            .frame(width: 0.5, height: 44)
    }

    private var summaryCardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(theme.isDark ? Color.white.opacity(0.08) : Color.white.opacity(0.92))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(theme.cardStroke.opacity(theme.isDark ? 0.28 : 0.4), lineWidth: 0.5)
            }
    }

    // MARK: - Mois

    private func monthSection(plan: FaceOriginPlan) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            monthNavigator(plan: plan)
            weekdayHeaderRow
            calendarGrid(plan: plan)
            legendRow
        }
    }

    private func monthNavigator(plan: FaceOriginPlan) -> some View {
        HStack {
            Button {
                shiftMonth(by: -1, plan: plan)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(canGoToPreviousMonth(plan: plan) ? theme.primaryText : theme.secondaryText.opacity(0.35))
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .disabled(!canGoToPreviousMonth(plan: plan))

            Spacer()

            Text(Self.monthTitleFormatter.string(from: displayedMonth))
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(theme.primaryText)
                .textCase(nil)

            Spacer()

            Button {
                shiftMonth(by: 1, plan: plan)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(canGoToNextMonth(plan: plan) ? theme.primaryText : theme.secondaryText.opacity(0.35))
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .disabled(!canGoToNextMonth(plan: plan))
        }
    }

    private var weekdayHeaderRow: some View {
        LazyVGrid(columns: Self.gridColumns, spacing: 8) {
            ForEach(Self.weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.secondaryText.opacity(0.75))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func calendarGrid(plan: FaceOriginPlan) -> some View {
        LazyVGrid(columns: Self.gridColumns, spacing: 8) {
            ForEach(Array(gridCells(for: displayedMonth).enumerated()), id: \.offset) { _, cell in
                if let date = cell {
                    dayCell(date: date, plan: plan)
                } else {
                    Color.clear
                        .frame(height: PlanProgramCalendarDesign.cellHeight)
                }
            }
        }
    }

    private func dayCell(date: Date, plan: FaceOriginPlan) -> some View {
        let model = dayModel(for: date, plan: plan)
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)

        return Button {
            HapticManager.shared.impact(.light)
            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                selectedDate = date
            }
        } label: {
            VStack(spacing: 5) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 15, weight: isSelected ? .bold : .semibold, design: .rounded))
                    .foregroundStyle(model.dayNumberColor(isSelected: isSelected, theme: theme))
                    .monospacedDigit()

                if model.programDayNumber != nil {
                    dayStatusBadge(model: model, isSelected: isSelected)
                        .overlay(alignment: .topTrailing) {
                            if model.isDebloatTarget {
                                Image(systemName: "drop.fill")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundStyle(Color(red: 0.45, green: 0.72, blue: 0.95))
                                    .offset(x: 6, y: -4)
                            }
                        }
                } else {
                    Spacer(minLength: 0)
                        .frame(height: 16)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: PlanProgramCalendarDesign.cellHeight)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(model.cellFill(isSelected: isSelected, theme: theme))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(model.borderColor(isSelected: isSelected, theme: theme), lineWidth: isSelected ? 1.5 : 0.5)
                    }
            }
            .scaleEffect(isSelected ? 1.04 : 1, anchor: .center)
        }
        .buttonStyle(PlanProgramCalendarDayButtonStyle())
        .accessibilityLabel(model.accessibilityLabel)
    }

    @ViewBuilder
    private func dayStatusBadge(model: PlanProgramCalendarDayModel, isSelected: Bool) -> some View {
        switch model.status {
        case .validated(let verdict):
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(verdict.chartColor)
        case .missed:
            Circle()
                .fill(Color(red: 0.92, green: 0.38, blue: 0.38).opacity(0.75))
                .frame(width: 7, height: 7)
        case .partial:
            Circle()
                .fill(Color(red: 1.0, green: 0.72, blue: 0.28))
                .frame(width: 7, height: 7)
        case .today:
            Circle()
                .fill(theme.onboardingAccent)
                .frame(width: 8, height: 8)
        case .future:
            Circle()
                .strokeBorder(theme.secondaryText.opacity(0.32), lineWidth: 1.5)
                .frame(width: 14, height: 14)
        case .inPlan:
            Text("\(model.programDayNumber ?? 0)")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(theme.secondaryText.opacity(0.7))
                .monospacedDigit()
        case .outsidePlan:
            EmptyView()
        }
    }

    private var legendRow: some View {
        HStack(spacing: 14) {
            legendItem(color: ProcessStreakPalette.flame, label: "Validé")
            legendItem(color: Color(red: 1.0, green: 0.72, blue: 0.28), label: "Partiel")
            legendItem(color: theme.onboardingAccent, label: "Aujourd'hui", isRing: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private func legendItem(color: Color, label: String, isRing: Bool = false) -> some View {
        HStack(spacing: 5) {
            if isRing {
                Circle()
                    .strokeBorder(color, lineWidth: 1.5)
                    .frame(width: 10, height: 10)
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
            }
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(theme.secondaryText)
        }
    }

    // MARK: - Panneau jour sélectionné

    @ViewBuilder
    private func selectedDayPanel(plan: FaceOriginPlan) -> some View {
        let model = dayModel(for: selectedDate, plan: plan)

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.panelTitle)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(theme.primaryText)

                    Text(model.panelSubtitle(plan: plan))
                        .font(.subheadline)
                        .foregroundStyle(theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                statusPill(model: model)
            }
        }
        .padding(18)
        .background(summaryCardBackground)
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: selectedDate)
    }

    private func statusPill(model: PlanProgramCalendarDayModel) -> some View {
        Text(model.statusLabel)
            .font(.caption.weight(.bold))
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
        let cardioBefore = ProcessDebloatValidation.consecutiveCardioMisses(
            before: dayKey,
            in: trajectoryStore.allRecordsByDay
        )
        let isValidated = record?.countsAsValidatedDay(consecutiveCardioMissesBefore: cardioBefore) == true
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
            record: record
        )
    }

    // MARK: - Navigation mois

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

    private func gridCells(for month: Date) -> [Date?] {
        let monthStart = Self.startOfMonth(for: month)
        guard let dayRange = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }

        let weekday = calendar.component(.weekday, from: monthStart)
        let leadingBlanks = (weekday - calendar.firstWeekday + 7) % 7

        var cells: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for day in dayRange {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                cells.append(date)
            }
        }
        while cells.count % 7 != 0 {
            cells.append(nil)
        }
        return cells
    }

    // MARK: - Utilitaires

    private static let frenchCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "fr_FR")
        cal.firstWeekday = 2
        return cal
    }()

    private static let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    private static let weekdaySymbols: [String] = {
        let cal = frenchCalendar
        return (0..<7).map { offset in
            let index = (cal.firstWeekday - 1 + offset) % 7
            return cal.veryShortWeekdaySymbols[index].uppercased()
        }
    }()

    private static let monthTitleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    private static func startOfMonth(for date: Date) -> Date {
        let components = frenchCalendar.dateComponents([.year, .month], from: date)
        return frenchCalendar.date(from: components) ?? date
    }
}

// MARK: - Modèle & design

private enum PlanProgramCalendarDesign {
    static let cellHeight: CGFloat = 52
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

    var panelTitle: String {
        if let programDayNumber {
            return "Jour \(programDayNumber) du programme"
        }
        return date.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    func panelSubtitle(plan: FaceOriginPlan) -> String {
        var parts: [String] = [date.formatted(.dateTime.weekday(.wide).day().month(.wide))]
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

    var statusLabel: String {
        switch status {
        case .outsidePlan: return "Hors plan"
        case .future: return "À venir"
        case .today: return "Aujourd'hui"
        case .inPlan: return "En cours"
        case .validated(let verdict): return verdict.shortLabel
        case .partial: return "Partiel"
        case .missed: return "Manqué"
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

    var accessibilityLabel: String {
        var parts = [panelTitle, statusLabel]
        if isToday { parts.append("aujourd'hui") }
        if isDebloatTarget { parts.append("objectif debloat") }
        return parts.joined(separator: ", ")
    }

    func dayNumberColor(isSelected: Bool, theme: AppTheme) -> Color {
        switch status {
        case .outsidePlan:
            return theme.secondaryText.opacity(0.35)
        default:
            return isSelected ? theme.primaryText : theme.primaryText.opacity(0.88)
        }
    }

    func cellFill(isSelected: Bool, theme: AppTheme) -> Color {
        if isSelected {
            return theme.isDark ? Color.white.opacity(0.14) : Color.white.opacity(0.95)
        }
        switch status {
        case .outsidePlan:
            return .clear
        case .validated:
            return theme.isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.03)
        default:
            return theme.isDark ? Color.white.opacity(0.04) : Color.black.opacity(0.025)
        }
    }

    func borderColor(isSelected: Bool, theme: AppTheme) -> Color {
        if isDebloatTarget {
            return Color(red: 0.45, green: 0.72, blue: 0.95).opacity(isSelected ? 0.85 : 0.45)
        }
        if isSelected {
            return theme.onboardingAccent.opacity(0.5)
        }
        if isToday {
            return theme.onboardingAccent.opacity(0.35)
        }
        return theme.cardStroke.opacity(theme.isDark ? 0.2 : 0.25)
    }
}

private struct PlanProgramCalendarDayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.78), value: configuration.isPressed)
    }
}

// MARK: - Compatibilité (alias sheet → plein écran)

typealias PlanHomeCalendarSheet = PlanProgramCalendarView
