import SwiftUI

private struct ProfileMetricPresentation: Equatable, Identifiable {
    let metric: ProfileChartMetric
    let points: [ProfileAnalyticsPoint]
    let latestValue: Double?
    let deltaVsPrevious: Double?

    var id: ProfileChartMetric { metric }
}

/// Onglet Profil — scans + évolution du score debloat + métriques (cortisol, récup, etc.).
struct ProcessProfileHomeView: View {
    @Binding var selectedSection: ProcessMainSection
    var isTabActive: Bool = true
    var isOnboardingPreview: Bool = false
    var onOpenSettings: () -> Void = {}

    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var profileService: UnifiedProfileService
    @Bindable private var faceHistoryStore = FaceScanHistoryStore.shared
    @Bindable private var planBridge = CoachPlanNavigationBridge.shared
    @State private var profileStore = SocialProfileStore.shared
    @ObservedObject private var creatorMode = ProcessCreatorModeStore.shared

    @State private var chartHistories: [ProfileChartMetric: [ProfileAnalyticsPoint]] = [:]
    @State private var selectedProfileDate = Calendar.current.startOfDay(for: Date())
    @State private var metricPresentations: [ProfileMetricPresentation] = []
    @State private var isReloadingCharts = false
    @State private var chartDataRevision = 0
    @State private var showCalendar = false

    private var profile: UnifiedUserProfile? {
        profileService.currentProfile
    }

    private var initials: String {
        let first = profile?.firstName.first.map(String.init) ?? "?"
        return first.uppercased()
    }

    var body: some View {
        Group {
            if isOnboardingPreview {
                profileScroll
            } else {
                profileScroll.processAdoptForIGTabBar()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .processClearUIKitHostingBackground()
        .task {
            guard !isOnboardingPreview else { return }
            if profileService.currentProfile == nil {
                await profileService.loadProfile()
            }
            profileStore.bind(unified: profileService.currentProfile)
            ProcessCreatorModeStore.shared.syncFromCurrentProfile()
            WelcomePlanStore.shared.reloadForCurrentUser()
            FaceScanHistoryStore.shared.reloadForUser(
                userId: UserScopedStorage.currentUserId()
            )
            await refreshProfile(forceHealthRefresh: false)
        }
        .onAppear {
            guard !isOnboardingPreview else { return }
            profileStore.bind(unified: profileService.currentProfile)
            ProcessCreatorModeStore.shared.syncFromCurrentProfile()
            clearTransientInteractionBlockers()
            selectedProfileDate = Calendar.current.startOfDay(for: creatorMode.effectiveNow)
            rebuildPresentations()
        }
        .onChange(of: chartDataRevision) { _, _ in
            rebuildPresentations()
        }
        .onChange(of: faceHistoryStore.history.count) { _, _ in
            rebuildPresentations()
        }
        .fullScreenCover(isPresented: $showCalendar) {
            PlanProgramCalendarView(
                selectedDate: $selectedProfileDate,
                plan: WelcomePlanStore.shared.plan
            )
        }
    }

    private var profileScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !isOnboardingPreview {
                        profileHeader
                    }

                    identityBlock

                    ProfileDebloatScoreSection(isOnboardingPreview: isOnboardingPreview)

                    Color.clear
                        .frame(height: 0)
                        .id(ProfileStatisticsAnchor.id)

                    profileChartsSection
                }
                .padding(.horizontal, AccountDetailsTheme.horizontalPadding)
                .padding(.top, isOnboardingPreview ? 16 : 10)
                .padding(.bottom, isOnboardingPreview ? 32 : ProcessIGTabMetrics.tabBarOverlayClearance + 32)
            }
            .scrollIndicators(.hidden)
            .processTransparentScrollSurface()
            .onAppear {
                focusProfileStatisticsIfNeeded(using: proxy)
            }
            .onChange(of: planBridge.shouldFocusProfileStatistics) { _, should in
                guard should else { return }
                _ = planBridge.consumeProfileStatisticsFocus()
                focusProfileStatistics(using: proxy)
            }
        }
    }

    private var profileHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            ProcessPageTitleHeader(title: AppCopy.t("Tes progrès", en: "Your progress"))

            Spacer(minLength: 8)

            headerActionsCluster
        }
    }

    @ViewBuilder
    private var headerActionsCluster: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: ProcessAppHeaderControlMetrics.glassClusterSpacing) {
                HStack(spacing: ProcessAppHeaderControlMetrics.glassClusterSpacing) {
                    calendarButton
                    settingsButton
                }
            }
        } else {
            HStack(spacing: 6) {
                calendarButton
                settingsButton
            }
        }
    }

    private var calendarButton: some View {
        Button(action: openCalendar) {
            Image(systemName: "calendar")
                .font(.system(size: ProcessAppHeaderControlMetrics.iconSize, weight: .semibold))
                .foregroundStyle(theme.primaryText)
                .frame(
                    width: ProcessAppHeaderControlMetrics.size,
                    height: ProcessAppHeaderControlMetrics.size
                )
                .contentShape(Circle())
        }
        .processGlassButton(in: Circle())
        .accessibilityLabel(AppCopy.t("Calendrier, choisir une date", en: "Calendar, choose a date"))
    }

    private var settingsButton: some View {
        ProcessGlassIconButton(
            systemName: "gearshape",
            size: ProcessAppHeaderControlMetrics.size,
            iconSize: ProcessAppHeaderControlMetrics.iconSize,
            action: openSettings
        )
        .accessibilityLabel(AppCopy.settings)
    }

    private func openCalendar() {
        HapticManager.shared.impact(.light)
        showCalendar = true
    }

    private func openSettings() {
        clearTransientInteractionBlockers()
        HapticManager.shared.impact(.light)
        onOpenSettings()
    }

    private func clearTransientInteractionBlockers() {
        FaceScanScreenFlash.shared.deactivate(animated: false)
        PlanHomeTutorialStore.shared.cancelScheduledPresentation()
    }

    private var identityBlock: some View {
        ProfileScanEvolutionPair(
            isPlaybackActive: isTabActive,
            initials: initials
        )
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
        .padding(.bottom, 4)
    }

    private var profileChartsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVStack(spacing: 12) {
                ForEach(metricPresentations, id: \.id) { presentation in
                    ProcessStickySection(
                        config: .init(
                            sectionPadding: 14,
                            cornerRadius: 24,
                            isGlassBackground: true
                        )
                    ) {
                        ProfileMetricChartSection(
                            metric: presentation.metric,
                            points: presentation.points,
                            latestValue: presentation.latestValue,
                            deltaVsPrevious: presentation.deltaVsPrevious,
                            presentation: .stickySection
                        )
                    } header: {
                        HStack {
                            Text(presentation.metric.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(theme.primaryText)

                            Spacer(minLength: 0)

                            Image(systemName: presentation.metric.stickySectionIcon)
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(theme.secondaryText)
                        }
                    } minimisedHeader: {
                        HStack(spacing: 6) {
                            Image(systemName: presentation.metric.stickySectionIcon)

                            Text(presentation.metric.stickyMinimisedTitle)

                            Spacer(minLength: 0)
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.secondaryText)
                    }
                }
            }
        }
    }

    private func focusProfileStatisticsIfNeeded(using proxy: ScrollViewProxy) {
        guard planBridge.consumeProfileStatisticsFocus() else { return }
        focusProfileStatistics(using: proxy)
    }

    private func focusProfileStatistics(using proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                proxy.scrollTo(ProfileStatisticsAnchor.id, anchor: .top)
            }
        }
    }

    private func rebuildPresentations() {
        metricPresentations = ProfileChartMetric.profileDisplayOrder.map { metric in
            let points = chartPoints(for: metric)
            return ProfileMetricPresentation(
                metric: metric,
                points: points,
                latestValue: points.last?.value,
                deltaVsPrevious: deltaVsPrevious(for: metric)
            )
        }
    }

    private func history(for metric: ProfileChartMetric) -> [ProfileAnalyticsPoint] {
        chartHistories[metric] ?? []
    }

    private func chartPoints(for metric: ProfileChartMetric) -> [ProfileAnalyticsPoint] {
        let selectedDayEnd = Calendar.current.date(
            byAdding: .day,
            value: 1,
            to: Calendar.current.startOfDay(for: selectedProfileDate)
        ) ?? selectedProfileDate
        let points = ProfileChartHistoryBuilder.visiblePoints(
            history: history(for: metric).filter { $0.date < selectedDayEnd },
            range: .profileDefault,
            weekOffset: 0
        )
        if !points.isEmpty { return points }
        return fallbackChartPoints(for: metric)
    }

    private func fallbackChartPoints(for metric: ProfileChartMetric) -> [ProfileAnalyticsPoint] {
        let calendar = Calendar.current
        let selectedDay = calendar.startOfDay(for: selectedProfileDate)
        let isToday = calendar.isDateInToday(selectedDay)
        let healthManager = HealthManager.shared

        switch metric {
        case .weight:
            if isToday, healthManager.todaySnapshot.vitals.bodyMass > 0 {
                return [
                    ProfileAnalyticsPoint(
                        id: "weight-today",
                        date: selectedDay,
                        value: healthManager.todaySnapshot.vitals.bodyMass
                    )
                ]
            }
            let profileWeight = profileService.currentProfile?.weight ?? 0
            if profileWeight > 0 {
                return [
                    ProfileAnalyticsPoint(
                        id: "profile-weight",
                        date: selectedDay,
                        value: profileWeight
                    )
                ]
            }

        case .retention, .recovery, .cortisol, .definition, .skin:
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: selectedDay) ?? selectedDay
            if let latest = faceHistoryStore.history.first(where: { $0.createdAt < dayEnd }),
               let kind = metric.faceScanKind {
                let value = Double(FaceScanIndicators.displayPercent(for: kind, result: latest))
                if value > 0 {
                    return [
                        ProfileAnalyticsPoint(
                            id: "\(kind.rawValue)-latest",
                            date: calendar.startOfDay(for: latest.createdAt),
                            value: value
                        )
                    ]
                }
            }

        case .effort:
            guard isToday else { break }
            let effortScore = healthManager.todaySnapshot.effort.effortScore
            if effortScore > 0 {
                return [
                    ProfileAnalyticsPoint(
                        id: "effort-today",
                        date: selectedDay,
                        value: effortScore
                    )
                ]
            }
        }

        return []
    }

    private func deltaVsPrevious(for metric: ProfileChartMetric) -> Double? {
        let selectedEnd = Calendar.current.date(
            byAdding: .day,
            value: 1,
            to: Calendar.current.startOfDay(for: selectedProfileDate)
        ) ?? selectedProfileDate
        let scopedHistory = history(for: metric).filter { $0.date < selectedEnd }
        let currentAverage = ProfileChartHistoryBuilder.average(
            in: ProfileChartHistoryBuilder.visiblePoints(
                history: scopedHistory,
                range: .week,
                weekOffset: 0
            )
        )
        let previousAverage = ProfileChartHistoryBuilder.previousPeriodAverage(
            history: scopedHistory,
            range: .week,
            weekOffset: 0
        )

        guard let currentAverage, let previousAverage else { return nil }
        return currentAverage - previousAverage
    }

    private func refreshProfile(forceHealthRefresh: Bool) async {
        if forceHealthRefresh {
            await ProfileHealthSection.refreshAll(force: true)
        }
        await reloadChartHistories()
    }

    private func reloadChartHistories() async {
        guard !isReloadingCharts else { return }
        isReloadingCharts = true
        defer { isReloadingCharts = false }

        FaceScanHistoryStore.shared.reloadForUser(userId: profileService.currentProfile?.userId)

        let scans = FaceScanHistoryStore.shared.history

        var histories: [ProfileChartMetric: [ProfileAnalyticsPoint]] = [:]

        for metric in ProfileChartMetric.profileDisplayOrder {
            guard let kind = metric.faceScanKind else { continue }
            histories[metric] = ProfileChartHistoryBuilder.faceScanIndicatorHistory(
                from: scans,
                kind: kind
            )
        }

        chartHistories = histories
        chartDataRevision &+= 1
    }
}

private enum ProfileStatisticsAnchor {
    static let id = "profileStatistics"
}
