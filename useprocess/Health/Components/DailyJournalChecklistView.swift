import SwiftUI

// MARK: - Design tokens (référence journal sombre)

private enum JournalDesign {
    static let cardFill = Color(red: 0.11, green: 0.11, blue: 0.12)
    static let segmentTrack = Color.white.opacity(0.08)
    static let completedBlue = Color(red: 0.0, green: 0.48, blue: 1.0)
    static let failedOrange = Color(red: 0.72, green: 0.38, blue: 0.18)
    static let goldCheck = Color(red: 0.92, green: 0.75, blue: 0.35)
    static let progressGreen = Color(red: 0.35, green: 0.78, blue: 0.45)
    static let mutedIcon = Color.white.opacity(0.35)

    enum Strip {
        static let cellWidth: CGFloat = 44
        static let cellHeight: CGFloat = 56
        static let cellRadius: CGFloat = 15
        static let selectedScale: CGFloat = 1.08
        static let slotWidth: CGFloat = 50
        static let slotHeight: CGFloat = 64
        static let stripHeight: CGFloat = 76
        static let cellSpacing: CGFloat = 8
    }
}

// MARK: - Vue principale

struct DailyJournalChecklistView: View {
    let plan: FaceOriginPlan
    @Binding var selectedDate: Date
    var showHeader: Bool = true
    var showWeekStrip: Bool = true
    var showChecklist: Bool = true

    @Namespace private var faceScanHistoryZoomNamespace
    @Namespace private var mealZoomNamespace
    @State private var faceHistoryStore = FaceScanHistoryStore.shared
    @State private var isChecklistExpanded = true
    @State private var showFaceScan = false
    @State private var showFaceScanHistory = false
    @State private var selectedFaceScan: FaceScanResult?
    @EnvironmentObject private var healthManager: HealthManager
    @Environment(\.appTheme) private var theme

    private var livePlan: FaceOriginPlan { WelcomePlanStore.shared.plan ?? plan }

    private var dayAvailability: OriginPlanPresenter.JournalDayAvailability {
        OriginPlanPresenter.journalDayAvailability(for: selectedDate, in: livePlan)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if showHeader {
                journalHeader
            }
            if showWeekStrip {
                JournalWeekDayStrip(
                    selectedDate: $selectedDate,
                    plan: livePlan
                )
                .padding(.top, -4)
                .padding(.leading, -6)
                .padding(.bottom, 8)
            }

            PlanLastFaceScanSection(
                latest: faceHistoryStore.latestResult,
                isScanDue: faceHistoryStore.isScanDue,
                zoomNamespace: faceScanHistoryZoomNamespace,
                onScan: {
                    showFaceScan = true
                },
                onOpenHistory: {
                    showFaceScanHistory = true
                }
            )
            .environmentObject(UnifiedProfileService.shared)
            .padding(.bottom, showWeekStrip ? 0 : 8)

            switch dayAvailability {
            case .editable(let day, _):
                if showChecklist {
                    journalSections(for: day, isEditable: true)
                }

                PlanNutritionDaySection(
                    plan: livePlan,
                    day: day,
                    isEditable: true,
                    mealZoomNamespace: mealZoomNamespace
                )
                    .environmentObject(UnifiedProfileService.shared)
                    .padding(.top, 28)

                PlanTrainingDaySection(
                    plan: livePlan,
                    day: day,
                    selectedDate: selectedDate,
                    isEditable: true
                )

                PlanPostureDaySection(plan: livePlan)
                    .padding(.top, 28)

                PlanFaceDaySection(plan: livePlan)
                    .padding(.top, 28)
            case .future:
                if showChecklist {
                    journalUnavailableCard(
                        title: "Jour à venir",
                        message: "Tu pourras remplir ta checklist une fois cette journée commencée.",
                        systemImage: "calendar.badge.clock"
                    )
                } else {
                    journalUnavailableCard(
                        title: "Jour à venir",
                        message: "Le contenu de cette journée sera disponible le jour J.",
                        systemImage: "calendar.badge.clock"
                    )
                }
            case .outsidePlan:
                journalUnavailableCard(
                    title: "Hors protocole",
                    message: "Cette date n'est pas couverte par ton calendrier Origine.",
                    systemImage: "calendar.badge.exclamationmark"
                )
            }
        }
        .fullScreenCover(isPresented: $showFaceScan) {
            FaceScanPrivacyGateView(
                onDismiss: { showFaceScan = false },
                onComplete: { result in
                    showFaceScan = false
                    faceHistoryStore = FaceScanHistoryStore.shared
                    FaceScanCoachHandoffCoordinator.deliver(result: result)
                },
                skipResultSheet: true
            )
            .environmentObject(UnifiedProfileService.shared)
        }
        .fullScreenCover(isPresented: $showFaceScanHistory) {
            FaceScanHistoryView(
                history: faceHistoryStore.history,
                isScanDue: faceHistoryStore.isScanDue,
                onSelect: { scan in
                    showFaceScanHistory = false
                    selectedFaceScan = scan
                },
                onScan: {
                    showFaceScanHistory = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        showFaceScan = true
                    }
                }
            )
            .processZoomTransition(id: .faceScanHistory, namespace: faceScanHistoryZoomNamespace)
        }
        .sheet(item: $selectedFaceScan) { scan in
            FaceScanDetailView(
                result: scan,
                previous: faceHistoryStore.history.first(where: { $0.id != scan.id && $0.createdAt < scan.createdAt })
            )
        }
        .onChange(of: selectedDate) { _, _ in
            if case .editable(let day, _) = dayAvailability {
                syncChecklistExpansion(for: day)
            }
        }
        .onAppear {
            faceHistoryStore = FaceScanHistoryStore.shared
        }
    }

    private var journalHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Journal")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(theme.primaryText)
            Text(monthYearLabel(for: selectedDate))
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)
        }
    }

    @ViewBuilder
    private func journalSections(for day: OriginProgramDay, isEditable: Bool) -> some View {
        let isFilled = OriginPlanPresenter.isDayJournalFilled(plan: livePlan, day: day)
        let summary = OriginPlanPresenter.journalCompletionSummary(
            plan: livePlan,
            day: day,
            date: selectedDate
        )

        Group {
            if isFilled, !isChecklistExpanded {
                JournalDayCompletionCard(
                    summary: summary,
                    theme: theme,
                    onEdit: {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                            isChecklistExpanded = true
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                checklistContent(for: day, isEditable: isEditable)
                    .transition(.opacity.combined(with: .offset(y: 8)))
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: isChecklistExpanded)
        .onAppear {
            syncChecklistExpansion(for: day)
        }
        .onChange(of: journalFilledToken(for: day)) { _, _ in
            if OriginPlanPresenter.isDayJournalFilled(plan: livePlan, day: day) {
                HapticManager.shared.notification(.success)
                withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                    isChecklistExpanded = false
                }
            } else {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.88)) {
                    isChecklistExpanded = true
                }
            }
        }
    }

    @ViewBuilder
    private func checklistContent(for day: OriginProgramDay, isEditable: Bool) -> some View {
        PlanDayChronologicalTimeline(
            day: day,
            plan: livePlan,
            selectedDate: selectedDate,
            isEditable: isEditable,
            onTaskStatusChange: { taskId, dayId, status in
                WelcomePlanStore.shared.setJournalTaskStatus(status, taskId: taskId, dayId: dayId)
            }
        )
    }

    private func journalFilledToken(for day: OriginProgramDay) -> String {
        let tasks = OriginPlanPresenter.manualJournalTasks(from: day, plan: livePlan)
        return tasks.map { task in
            "\(task.id):\(livePlan.progress.status(for: task.id, dayId: day.id)?.rawValue ?? "nil")"
        }.joined(separator: "|")
    }

    private func syncChecklistExpansion(for day: OriginProgramDay) {
        isChecklistExpanded = !OriginPlanPresenter.isDayJournalFilled(plan: livePlan, day: day)
    }

    private func journalUnavailableCard(title: String, message: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.primaryText)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.isDark ? JournalDesign.cardFill : theme.cardBackgroundStrong)
        )
    }

    private func monthYearLabel(for date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "fr_FR")
        df.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return df.string(from: date)
    }
}

// MARK: - Carte journée complète

private struct JournalDayCompletionCard: View {
    let summary: OriginPlanPresenter.JournalDayCompletionSummary
    let theme: AppTheme
    var onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(JournalDesign.goldCheck.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(JournalDesign.goldCheck)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(theme.primaryText)
                    Text(summary.dateLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.secondaryText)
                }

                Spacer(minLength: 0)

                Text("\(summary.completedCount)/\(summary.totalCount)")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(theme.onboardingAccent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(theme.onboardingAccent.opacity(0.12), in: Capsule())
            }

            Text(summary.analysis)
                .font(.subheadline)
                .foregroundStyle(theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                confirmationRow(
                    icon: "checkmark.circle.fill",
                    tint: JournalDesign.progressGreen,
                    text: "Tes réponses sont enregistrées."
                )
                confirmationRow(
                    icon: "arrow.triangle.2.circlepath",
                    tint: theme.onboardingAccent,
                    text: "Ton protocole Origine a été mis à jour."
                )
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.coachUserBubble.opacity(theme.isDark ? 0.22 : 0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Button(action: onEdit) {
                Text("Modifier mes réponses")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(theme.isDark ? JournalDesign.cardFill : theme.cardBackgroundStrong)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(JournalDesign.goldCheck.opacity(0.28), lineWidth: 1)
                }
        )
    }

    private func confirmationRow(icon: String, tint: Color, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(theme.primaryText)
        }
    }
}

// MARK: - Bandeau dates (relief 3D)

struct JournalWeekDayStrip: View {
    @Binding var selectedDate: Date
    let plan: FaceOriginPlan

    @Environment(\.appTheme) private var theme

    private var stripDates: [Date] {
        OriginPlanPresenter.journalStripDates(in: plan)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .center, spacing: JournalDesign.Strip.cellSpacing) {
                    ForEach(stripDates, id: \.self) { date in
                        dayCell(for: date)
                            .id(date)
                            .frame(
                                width: JournalDesign.Strip.slotWidth,
                                height: JournalDesign.Strip.slotHeight
                            )
                            .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                content
                                    .opacity(0.62 + (1 - min(abs(phase.value), 1)) * 0.38)
                            }
                    }
                }
                .scrollTargetLayout()
                .padding(.leading, 6)
                .padding(.trailing, 16)
                .frame(height: JournalDesign.Strip.stripHeight)
            }
            .scrollTargetBehavior(.viewAligned)
            .onAppear {
                scrollToSelected(proxy, animated: false)
            }
            .onChange(of: selectedDate) { _, _ in
                scrollToSelected(proxy, animated: true)
            }
        }
        .frame(height: JournalDesign.Strip.stripHeight)
    }

    private func scrollToSelected(_ proxy: ScrollViewProxy, animated: Bool) {
        let target = Calendar.current.startOfDay(for: selectedDate)
        if animated {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                proxy.scrollTo(target, anchor: .center)
            }
        } else {
            proxy.scrollTo(target, anchor: .center)
        }
    }

    private func dayCell(for date: Date) -> some View {
        let cal = Calendar.current
        let isSelected = cal.isDate(date, inSameDayAs: selectedDate)
        let isToday = cal.isDateInToday(date)
        let isFuture = OriginPlanPresenter.isFutureJournalDate(date)
        let availability = OriginPlanPresenter.journalDayAvailability(for: date, in: plan)
        let isComplete = if case .editable(let day, _) = availability {
            OriginPlanPresenter.isDayJournalComplete(plan: plan, day: day)
        } else {
            false
        }
        let programDayLabel = programDayNumberLabel(for: date)

        return Button {
            HapticManager.shared.impact(.light)
            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                selectedDate = date
            }
        } label: {
            ZStack {
                JournalDayTileBackground(
                    isDark: theme.isDark,
                    isSelected: isSelected,
                    accent: theme.onboardingAccent
                )

                VStack(spacing: 8) {
                    Text(programDayLabel)
                        .font(.system(size: 17, weight: isSelected ? .bold : .semibold, design: .rounded))
                        .foregroundStyle(isSelected ? theme.primaryText : theme.secondaryText.opacity(0.92))
                        .monospacedDigit()
                        .contentTransition(.numericText())

                    dayStatusIcon(isComplete: isComplete, isFuture: isFuture, isToday: isToday, isSelected: isSelected)
                }
            }
            .frame(width: JournalDesign.Strip.cellWidth, height: JournalDesign.Strip.cellHeight)
            .scaleEffect(isSelected ? 1.03 : 1, anchor: .center)
            .animation(.spring(response: 0.32, dampingFraction: 0.78), value: isSelected)
        }
        .buttonStyle(JournalDayCellButtonStyle())
        .accessibilityLabel(accessibilityLabel(for: date, programDay: programDayLabel, isToday: isToday, isComplete: isComplete))
    }

    private func programDayNumberLabel(for date: Date) -> String {
        guard let day = OriginPlanPresenter.programDay(in: plan, for: date) else {
            return "·"
        }
        return "\(day.globalDayIndex + 1)"
    }

    private func accessibilityLabel(for date: Date, programDay: String, isToday: Bool, isComplete: Bool) -> String {
        var parts: [String] = []
        if programDay != "·" {
            parts.append("Jour \(programDay) du protocole")
        }
        parts.append(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
        if isToday { parts.append("aujourd'hui") }
        if isComplete { parts.append("complet") }
        return parts.joined(separator: ", ")
    }

    @ViewBuilder
    private func dayStatusIcon(isComplete: Bool, isFuture: Bool, isToday: Bool, isSelected: Bool) -> some View {
        if isComplete {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(JournalDesign.goldCheck.opacity(0.22))
                        .frame(width: 24, height: 24)
                        .blur(radius: 2)
                }
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(JournalDesign.goldCheck)
            }
            .frame(height: 18)
        } else if isFuture {
            Circle()
                .strokeBorder(theme.secondaryText.opacity(0.28), lineWidth: 1.5)
                .frame(width: 16, height: 16)
        } else if isToday {
            Circle()
                .fill(theme.onboardingAccent)
                .frame(width: 7, height: 7)
                .shadow(color: theme.onboardingAccent.opacity(0.5), radius: 4)
        } else {
            Circle()
                .strokeBorder(theme.secondaryText.opacity(0.4), lineWidth: 1.5)
                .frame(width: 16, height: 16)
        }
    }
}

private struct JournalDayCellButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

private struct JournalDayTileBackground: View {
    let isDark: Bool
    var isSelected: Bool = false
    var accent: Color = .blue

    private var radius: CGFloat { JournalDesign.Strip.cellRadius }

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(tileGradient)

            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            .black.opacity(isDark ? 0.18 : 0.04),
                            .clear,
                            .black.opacity(isDark ? 0.18 : 0.04)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [
                            (isDark ? Color.white : Color.white).opacity(isDark ? 0.14 : 0.55),
                            .clear
                        ],
                        center: UnitPoint(x: 0.5, y: 0.04),
                        startRadius: 0,
                        endRadius: radius * 2.4
                    )
                )

            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            .clear,
                            .black.opacity(isDark ? 0.30 : 0.10)
                        ],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                )

            JournalStripCurvedHighlight(isDark: isDark, intensity: isSelected ? 1.25 : 1)
                .padding(.horizontal, 5)
                .padding(.top, 3)
                .frame(height: 13)

            if isSelected {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                accent.opacity(isDark ? 0.24 : 0.16),
                                accent.opacity(isDark ? 0.08 : 0.04)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(isDark ? 0.22 : 0.70),
                            Color.white.opacity(isDark ? 0.04 : 0.12)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.75
                )
                .padding(0.5)
        }
        .overlay {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: borderColors,
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: isSelected ? 1.25 : 0.5
                )
        }
        .shadow(color: .black.opacity(isDark ? 0.55 : 0.14), radius: isSelected ? 3 : 2, x: 0, y: isSelected ? 2 : 1)
        .shadow(
            color: shadowColor,
            radius: isSelected ? 5 : 7,
            x: 0,
            y: isSelected ? 3 : 4
        )
    }

    private var tileGradient: LinearGradient {
        if isDark {
            return LinearGradient(
                colors: [
                    Color(red: 0.19, green: 0.19, blue: 0.20),
                    Color(red: 0.11, green: 0.11, blue: 0.12),
                    Color(red: 0.06, green: 0.06, blue: 0.07)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        return LinearGradient(
            colors: [
                Color(white: 0.99),
                Color(white: 0.93),
                Color(white: 0.84)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var borderColors: [Color] {
        if isSelected {
            return [
                accent.opacity(0.55),
                accent.opacity(0.22)
            ]
        }
        if isDark {
            return [
                Color.white.opacity(0.16),
                Color.white.opacity(0.04)
            ]
        }
        return [
            Color.white.opacity(0.95),
            Color.black.opacity(0.06)
        ]
    }

    private var shadowColor: Color {
        if isSelected {
            return accent.opacity(isDark ? 0.14 : 0.10)
        }
        return .black.opacity(isDark ? 0.38 : 0.10)
    }
}

private struct JournalStripCurvedHighlight: View {
    let isDark: Bool
    var intensity: CGFloat = 1

    var body: some View {
        GeometryReader { geo in
            ZStack {
                curvedPath(in: geo.size, lift: 0)
                    .stroke(
                        LinearGradient(
                            colors: highlightColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1.2 * intensity
                    )
                    .blur(radius: 0.25)

                curvedPath(in: geo.size, lift: 2.5)
                    .stroke(
                        (isDark ? Color.white : Color.white).opacity(isDark ? 0.08 * intensity : 0.35 * intensity),
                        lineWidth: 5 * intensity
                    )
                    .blur(radius: 3.5)
            }
        }
        .frame(height: 20)
    }

    private var highlightColors: [Color] {
        if isDark {
            return [
                Color.white.opacity(0.04 * intensity),
                Color.white.opacity(0.48 * intensity),
                Color.white.opacity(0.62 * intensity),
                Color.white.opacity(0.48 * intensity),
                Color.white.opacity(0.04 * intensity)
            ]
        }
        return [
            Color.white.opacity(0.25 * intensity),
            Color.white.opacity(0.98 * intensity),
            Color.white,
            Color.white.opacity(0.98 * intensity),
            Color.white.opacity(0.25 * intensity)
        ]
    }

    private func curvedPath(in size: CGSize, lift: CGFloat) -> Path {
        Path { path in
            let w = size.width
            let baseline: CGFloat = 12 - lift
            let controlY: CGFloat = 1 - lift
            path.move(to: CGPoint(x: 0, y: baseline))
            path.addQuadCurve(
                to: CGPoint(x: w, y: baseline),
                control: CGPoint(x: w / 2, y: controlY)
            )
        }
    }
}

// MARK: - Ligne tâche manuelle

struct JournalTaskRow: View {
    let task: OriginPlanTask
    let dayId: String
    let plan: FaceOriginPlan
    var isEditable: Bool = true
    var onStatusChange: (JournalTaskStatus?) -> Void

    @Environment(\.appTheme) private var theme

    private var status: JournalTaskStatus? {
        plan.progress.status(for: task.id, dayId: dayId)
    }

    var body: some View {
        HStack(spacing: 14) {
            Text(OriginPlanPresenter.taskEmoji(for: task))
                .font(.system(size: 26))
                .frame(width: 32, alignment: .center)

            Text(OriginPlanPresenter.journalDisplayTitle(for: task))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(theme.primaryText)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isEditable {
                JournalTriStateControl(status: status) { newStatus in
                    onStatusChange(newStatus)
                }
            } else {
                JournalTriStateIndicator(status: status)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(journalCardBackground)
    }

    private var journalCardBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(theme.isDark ? JournalDesign.cardFill : theme.cardBackgroundStrong)
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(theme.cardStroke.opacity(0.5), lineWidth: 0.5)
            }
    }
}

// MARK: - Contrôle 3 états (✗ · ✓)

struct JournalTriStateIndicator: View {
    var status: JournalTaskStatus?

    var body: some View {
        HStack(spacing: 0) {
            indicatorSegment(icon: "xmark", isActive: status == .failed, activeFill: JournalDesign.failedOrange)
            indicatorSegment(icon: "minus", isActive: status == nil, activeFill: Color.clear, muted: status != nil)
            indicatorSegment(icon: "checkmark", isActive: status == .completed, activeFill: JournalDesign.completedBlue)
        }
        .padding(3)
        .background(Capsule(style: .continuous).fill(JournalDesign.segmentTrack))
        .allowsHitTesting(false)
    }

    private func indicatorSegment(icon: String, isActive: Bool, activeFill: Color, muted: Bool = false) -> some View {
        ZStack {
            if isActive, activeFill != .clear {
                Capsule(style: .continuous).fill(activeFill)
            }
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(isActive && activeFill != .clear ? .white : JournalDesign.mutedIcon.opacity(muted ? 0.55 : 1))
        }
        .frame(width: 34, height: 28)
    }
}

struct JournalTriStateControl: View {
    var status: JournalTaskStatus?
    var onChange: (JournalTaskStatus?) -> Void

    var body: some View {
        HStack(spacing: 0) {
            segment(
                icon: "xmark",
                isActive: status == .failed,
                activeFill: JournalDesign.failedOrange
            ) {
                onChange(status == .failed ? nil : .failed)
            }

            segment(
                icon: "minus",
                isActive: false,
                activeFill: Color.clear,
                iconColor: status == nil ? JournalDesign.mutedIcon : JournalDesign.mutedIcon.opacity(0.55)
            ) {
                onChange(nil)
            }

            segment(
                icon: "checkmark",
                isActive: status == .completed,
                activeFill: JournalDesign.completedBlue
            ) {
                onChange(status == .completed ? nil : .completed)
            }
        }
        .padding(3)
        .background(Capsule(style: .continuous).fill(JournalDesign.segmentTrack))
    }

    private func segment(
        icon: String,
        isActive: Bool,
        activeFill: Color,
        iconColor: Color = .white,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                if isActive, activeFill != .clear {
                    Capsule(style: .continuous)
                        .fill(activeFill)
                }
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(isActive && activeFill != .clear ? .white : iconColor)
            }
            .frame(width: 34, height: 28)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tâches automatiques

private struct JournalAutoStepsRow: View {
    let steps: Int
    let target: Int

    @Environment(\.appTheme) private var theme

    private var progress: Double {
        guard target > 0 else { return 0 }
        return Double(steps) / Double(target)
    }

    var body: some View {
        HStack(spacing: 14) {
            Text("👟")
                .font(.system(size: 26))
                .frame(width: 32, alignment: .center)

            Text("\(formatted(target))+ pas")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(theme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(steps > 0 ? formatted(steps) + " pas" : "—")
                .font(.caption.weight(.medium))
                .foregroundStyle(theme.secondaryText)
                .monospacedDigit()

            JournalCircularProgressRing(
                progress: progress,
                fillColor: steps >= target ? JournalDesign.progressGreen : theme.secondaryText.opacity(0.5)
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(autoCardBackground)
    }

    private var autoCardBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(theme.isDark ? JournalDesign.cardFill : theme.cardBackgroundStrong)
    }

    private func formatted(_ value: Int) -> String {
        let nf = NumberFormatter()
        nf.locale = Locale(identifier: "fr_FR")
        nf.numberStyle = .decimal
        nf.groupingSeparator = " "
        return nf.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

private struct JournalAutoExerciseRow: View {
    let minutes: Int
    let target: Int

    @Environment(\.appTheme) private var theme

    private var progress: Double {
        guard target > 0 else { return 0 }
        return Double(minutes) / Double(target)
    }

    var body: some View {
        HStack(spacing: 14) {
            Text("🏃")
                .font(.system(size: 26))
                .frame(width: 32, alignment: .center)

            Text("Exercice")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(theme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(minutes) min")
                .font(.caption.weight(.medium))
                .foregroundStyle(theme.secondaryText)
                .monospacedDigit()

            JournalCircularProgressRing(
                progress: progress,
                fillColor: minutes >= target ? JournalDesign.progressGreen : theme.secondaryText.opacity(0.5)
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.isDark ? JournalDesign.cardFill : theme.cardBackgroundStrong)
        )
    }
}

private struct JournalContinuousHabitRow: View {
    let title: String
    let detail: String

    @Environment(\.appTheme) private var theme

    private var emoji: String {
        let lower = title.lowercased()
        if lower.contains("mewing") { return "👅" }
        if lower.contains("déglut") || lower.contains("deglut") { return "🫁" }
        if lower.contains("mastication") { return "🍽️" }
        return "∞"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(emoji)
                .font(.system(size: 26))
                .frame(width: 32, alignment: .center)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.primaryText)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.isDark ? JournalDesign.cardFill : theme.cardBackgroundStrong)
        )
    }
}

struct JournalCircularProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 3
    var size: CGFloat = 28
    var trackColor: Color = Color.white.opacity(0.12)
    var fillColor: Color = JournalDesign.progressGreen

    var body: some View {
        ZStack {
            Circle()
                .stroke(trackColor, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(fillColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }
}
