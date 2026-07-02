import SwiftUI

/// En-tête accueil Plan — salutation + cluster glass streak / statut d'activité.
struct PlanHomeTopChrome: View {
    @Binding var selectedSection: ProcessMainSection
    @Binding var selectedDate: Date

    @EnvironmentObject private var profileService: UnifiedProfileService
    @Environment(\.appTheme) private var theme

    @Bindable private var streakStore = ProcessStreakStore.shared
    @Bindable private var planStore = WelcomePlanStore.shared
    @Bindable private var activityStatusStore = ProcessActivityStatusStore.shared
    @State private var showStreakToast = false
    @State private var streakToast = DynamicIslandToastMessage.streak(
        snapshot: ProcessStreakStore.shared.snapshot,
        firstName: nil
    )
    @State private var streakToastDismissTask: Task<Void, Never>?
    @State private var showDatePicker = false
    @State private var showActivityStatusSheet = false

    private static let frenchLocale = Locale(identifier: "fr_FR")

    private var greetingFirstName: String {
        profileService.currentProfile?.firstName
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var currentActivityStatus: ProcessActivityStatus {
        activityStatusStore.status(for: selectedDate)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                PlanHomeGreetingLabel(greeting: homeGreeting)

                homeDatePickerButton

                homeActivityStatusChip
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            headerActionsCluster
        }
        .padding(.top, 14)
        .padding(.bottom, 4)
        .sheet(isPresented: $showDatePicker) {
            homeDatePickerSheet
        }
        .sheet(isPresented: $showActivityStatusSheet) {
            ProcessActivityStatusSheet(selectedDate: $selectedDate)
        }
        .dynamicIslandToast(isPresented: $showStreakToast, value: streakToast)
        .onAppear {
            streakStore.sync(from: planStore.plan)
            activityStatusStore.reload()
        }
        .onChange(of: profileService.currentProfile?.userId) { _, _ in
            streakStore.reload()
            streakStore.sync(from: planStore.plan)
            activityStatusStore.reload()
        }
        .onChange(of: planStore.plan?.lastUpdated) { _, _ in
            streakStore.sync(from: planStore.plan)
        }
        .onChange(of: selectedDate) { _, _ in
            activityStatusStore.reload()
        }
    }

    private var homeActivityStatusChip: some View {
        Button(action: openActivityStatus) {
            HStack(spacing: 8) {
                ProcessActivityStatusBadge(
                    status: currentActivityStatus,
                    size: 28,
                    iconSize: 13
                )

                VStack(alignment: .leading, spacing: 1) {
                    Text(currentActivityStatus.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.primaryText)

                    Text("Jusqu'à modification")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(theme.secondaryText)
                }

                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(theme.secondaryText.opacity(0.8))
            }
            .padding(.leading, 6)
            .padding(.trailing, 12)
            .padding(.vertical, 6)
            .background {
                Capsule(style: .continuous)
                    .fill(theme.cardBackgroundStrong.opacity(theme.isDark ? 0.55 : 0.72))
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(Color.primary.opacity(theme.isDark ? 0.10 : 0.06), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
        .accessibilityLabel("Statut d'activité, \(currentActivityStatus.title)")
    }

    private var homeGreeting: PlanHomeGreeting {
        PlanHomeGreetingBuilder.make(firstName: greetingFirstName)
    }

    private var homeDateLabel: String {
        let calendar = Calendar.current
        let date = calendar.startOfDay(for: selectedDate)
        return formattedWeekdayDayMonth(date)
    }

    private var homeDatePickerButton: some View {
        Button {
            HapticManager.shared.impact(.light)
            showDatePicker = true
        } label: {
            HStack(spacing: 5) {
                Text(homeDateLabel)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(theme.secondaryText)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Changer le jour affiché")
        .accessibilityHint("Ouvre le sélecteur de date")
    }

  @ViewBuilder
    private var homeDatePickerSheet: some View {
        NavigationStack {
            DatePicker(
                "Jour",
                selection: $selectedDate,
                in: homeDatePickerRange,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .environment(\.locale, Self.frenchLocale)
            .padding(.horizontal, 12)
            .navigationTitle("Choisir un jour")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") {
                        normalizeSelectedDate()
                        showDatePicker = false
                    }
                }
            }
            .onAppear {
                normalizeSelectedDate()
            }
        }
        .processAppPageBackground()
        .processAppPresentationBackground()
        .presentationDetents([.medium, .large])
    }

    private var homeDatePickerRange: ClosedRange<Date> {
        let dates: [Date] = {
            guard let plan = planStore.plan else {
                return OriginPlanPresenter.journalStripDates()
            }
            return OriginPlanPresenter.journalStripDates(in: plan)
        }()
        if let first = dates.first, let last = dates.last {
            return first...last
        }
        let today = Calendar.current.startOfDay(for: Date())
        return today...today
    }

    private func normalizeSelectedDate() {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: selectedDate)
        let range = homeDatePickerRange
        if day < range.lowerBound {
            selectedDate = range.lowerBound
        } else if day > range.upperBound {
            selectedDate = range.upperBound
        } else {
            selectedDate = day
        }
    }

    private func formattedWeekdayDayMonth(_ date: Date) -> String {
        date.formatted(
            .dateTime.weekday(.wide).day().month(.wide)
                .locale(Self.frenchLocale)
        )
    }

    private enum GlassClusterMetrics {
        static let streakTileWidth: CGFloat = 54
        static let tileSize: CGFloat = 50
        static let statusIconSize: CGFloat = 34
        static let spacing: CGFloat = 22
        static let mergeOffset: CGFloat = -22
        static let iconSize: CGFloat = 15
    }

    @ViewBuilder
    private var headerActionsCluster: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: GlassClusterMetrics.spacing) {
                HStack(spacing: GlassClusterMetrics.spacing) {
                    Button(action: openStreak) {
                        streakGlassTile
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Streak, \(streakStore.displayStreak) jours")

                    Button(action: openActivityStatus) {
                        activityStatusGlassTile
                    }
                    .buttonStyle(.plain)
                    .offset(x: GlassClusterMetrics.mergeOffset, y: 0.0)
                    .accessibilityLabel("Statut d'activité, \(currentActivityStatus.title)")
                }
            }
        } else {
            HStack(spacing: 10) {
                Button(action: openStreak) {
                    legacyStreakButton
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Streak, \(streakStore.displayStreak) jours")

                Button(action: openActivityStatus) {
                    legacyActivityStatusButton
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Statut d'activité, \(currentActivityStatus.title)")
            }
        }
    }

    @available(iOS 26.0, *)
    private var streakGlassTile: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.system(size: GlassClusterMetrics.iconSize, weight: .semibold))
                .foregroundStyle(streakFlameColor)

            Text("\(streakStore.displayStreak)")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(theme.primaryText)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(width: GlassClusterMetrics.streakTileWidth, height: GlassClusterMetrics.tileSize)
        .glassEffect()
    }

    @available(iOS 26.0, *)
    private var activityStatusGlassTile: some View {
        ProcessActivityStatusBadge(
            status: currentActivityStatus,
            size: GlassClusterMetrics.statusIconSize,
            iconSize: 15
        )
        .frame(width: GlassClusterMetrics.tileSize, height: GlassClusterMetrics.tileSize)
        .glassEffect()
    }

    private var legacyStreakButton: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(streakFlameColor)
            Text("\(streakStore.displayStreak)")
                .font(.system(size: 15, weight: .bold))
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .processGlassCircle(interactive: true)
    }

    private var legacyActivityStatusButton: some View {
        ProcessActivityStatusBadge(
            status: currentActivityStatus,
            size: 36,
            iconSize: 16
        )
        .frame(width: 44, height: 44)
        .processGlassCircle(interactive: true)
    }

    private var streakFlameColor: Color {
        streakStore.displayStreak > 0 ? ProcessStreakPalette.flame : theme.secondaryText.opacity(0.65)
    }

    private func openActivityStatus() {
        HapticManager.shared.impact(.light)
        showActivityStatusSheet = true
    }

    private func openStreak() {
        HapticManager.shared.impact(.light)
        streakStore.sync(from: planStore.plan)
        streakToastDismissTask?.cancel()
        streakToast = .streak(
            snapshot: streakStore.snapshot,
            firstName: greetingFirstName.isEmpty ? nil : greetingFirstName
        )
        showStreakToast = true
        streakToastDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3.8))
            guard !Task.isCancelled else { return }
            showStreakToast = false
        }
    }
}

// MARK: - Salutation accueil

private struct PlanHomeGreetingLabel: View {
    let greeting: PlanHomeGreeting

    @Environment(\.appTheme) private var theme

    private var greetingGradient: LinearGradient {
        if theme.isDark {
            LinearGradient(
                colors: [
                    Color.white,
                    Color.white.opacity(0.58)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.92),
                    Color.black.opacity(0.42)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    var body: some View {
        Text(greeting.line)
            .font(.system(size: 28, weight: .bold))
            .foregroundStyle(greetingGradient)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
