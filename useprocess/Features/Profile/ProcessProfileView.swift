import AuthenticationServices
import SwiftUI

private struct ProfileMetricPresentation: Equatable, Identifiable {
    let metric: ProfileChartMetric
    let points: [ProfileAnalyticsPoint]
    let latestValue: Double?
    let deltaVsPrevious: Double?

    var id: ProfileChartMetric { metric }
}


/// Profil — scans visage, métriques et identité.
struct ProcessProfileView: View {
    @Binding var selectedSection: ProcessMainSection
    var isTabActive: Bool = true
    var isOnboardingPreview: Bool = false

    @Environment(\.appTheme) private var theme
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var profileService: UnifiedProfileService
    @Bindable private var faceHistoryStore = FaceScanHistoryStore.shared
    @Bindable private var planBridge = CoachPlanNavigationBridge.shared
    @State private var profileStore = SocialProfileStore.shared

    @State private var selectedAnalysisScan: FaceScanResult?

    @State private var chartHistories: [ProfileChartMetric: [ProfileAnalyticsPoint]] = [:]
    @State private var selectedProfileDate = Calendar.current.startOfDay(for: Date())
    @State private var metricPresentations: [ProfileMetricPresentation] = []
    @State private var isReloadingCharts = false
    @State private var chartDataRevision = 0
    @ObservedObject private var creatorMode = ProcessCreatorModeStore.shared

    private var isFlamePlaybackActive: Bool {
        isTabActive && scenePhase == .active
    }

    var body: some View {
        streakScroll
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .processClearUIKitHostingBackground()
        .fullScreenCover(item: $selectedAnalysisScan) { scan in
            FaceScanResultContent(
                result: scan,
                previous: previousScan(before: scan),
                history: faceHistoryStore.history
            )
        }
        .task(id: profileService.currentProfile?.userId) {
            guard !isOnboardingPreview else { return }
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            if profileService.currentProfile == nil {
                await profileService.loadProfile()
            }
            profileStore.bind(unified: profileService.currentProfile)
            await refreshProfile(forceHealthRefresh: false)
        }
        .onAppear {
            guard !isOnboardingPreview else { return }
            ProcessPerformanceTrace.endProfileOpen()
            ProcessDebloatTrajectoryStore.shared.reload()
            ProcessDebloatTrajectoryStore.shared.sync(from: WelcomePlanStore.shared.plan)
            ProcessPlanProgressStore.shared.reload(plan: WelcomePlanStore.shared.plan)
            rebuildPresentations()
        }
        .onChange(of: profileService.currentProfile?.userId) { _, _ in
            profileStore.bind(unified: profileService.currentProfile)
        }
        .onChange(of: chartDataRevision) { _, _ in
            rebuildPresentations()
        }
        .onChange(of: selectedProfileDate) { _, _ in
            rebuildPresentations()
        }
        .onChange(of: faceHistoryStore.history.count) { _, _ in
            rebuildPresentations()
        }
    }

    private var streakScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                // VStack (pas LazyVStack) en tête : TimelineView de la flamme doit rester actif.
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: 0)
                        .id(ProfileOnboardingPreviewTopAnchor.id)

                    ProfileStreakAchievementsSection(
                        selectedDate: $selectedProfileDate,
                        isPlaybackActive: isFlamePlaybackActive,
                        isOnboardingPreview: isOnboardingPreview,
                        showsSectionHeader: true
                    )

                    Color.clear
                        .frame(height: 0)
                        .id(ProfileStatisticsAnchor.id)

                    profileScrollContent
                }
                .frame(maxWidth: .infinity, alignment: .top)
                .processReportsTabBarScrollOffset()
            }
            .coordinateSpace(name: "processMainScroll")
            .scrollIndicators(.hidden)
            .modifier(ProcessProfileTabBarAdoption(enabled: !isOnboardingPreview))
            .processTransparentScrollSurface()
            .simultaneousGesture(profileDaySwipeGesture)
            .onAppear {
                selectedProfileDate = Calendar.current.startOfDay(for: creatorMode.effectiveNow)
                if isOnboardingPreview {
                    bootstrapOnboardingPreview()
                    focusOnboardingPreviewStreakTop(using: proxy)
                } else {
                    focusProfileStatisticsIfNeeded(using: proxy)
                }
            }
            .onChange(of: planBridge.shouldFocusProfileStatistics) { _, should in
                guard should else { return }
                _ = planBridge.consumeProfileStatisticsFocus()
                focusProfileStatistics(using: proxy)
            }
            .onChange(of: isTabActive) { _, active in
                guard isOnboardingPreview, active else { return }
                bootstrapOnboardingPreview()
                focusOnboardingPreviewStreakTop(using: proxy)
            }
        }
    }

    private struct ProcessProfileTabBarAdoption: ViewModifier {
        let enabled: Bool

        func body(content: Content) -> some View {
            if enabled {
                content.processAdoptForIGTabBar()
            } else {
                content
            }
        }
    }

    private var profileScrollContent: some View {
        profileChartsSection
            .padding(.horizontal, ProfileTheme.horizontalPadding)
            .padding(.top, 20)
            .padding(.bottom, 32)
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

    private func focusOnboardingPreviewStreakTop(using proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            proxy.scrollTo(ProfileOnboardingPreviewTopAnchor.id, anchor: .top)
        }
    }

    private func focusProfileStatistics(using proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                proxy.scrollTo(ProfileStatisticsAnchor.id, anchor: .top)
            }
        }
    }

    private func bootstrapOnboardingPreview() {
        ProcessDebloatTrajectoryStore.shared.reload()
        ProcessDebloatTrajectoryStore.shared.sync(from: WelcomePlanStore.shared.plan)
        ProcessPlanProgressStore.shared.reload(plan: WelcomePlanStore.shared.plan)
        ProcessStreakStore.shared.sync(from: WelcomePlanStore.shared.plan)
        chartHistories = Self.previewChartHistories()
        chartDataRevision &+= 1
        rebuildPresentations()
    }

    private static func previewChartHistories() -> [ProfileChartMetric: [ProfileAnalyticsPoint]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let series: [(ProfileChartMetric, [Double])] = [
            (.cortisol, [68, 64, 61, 58, 55, 52, 49]),
            (.recovery, [62, 58, 55, 51, 48, 45, 42]),
            (.retention, [72, 68, 63, 58, 54, 50, 46]),
            (.definition, [55, 58, 61, 64, 67, 70, 73]),
            (.skin, [58, 61, 64, 67, 70, 73, 76])
        ]

        var histories: [ProfileChartMetric: [ProfileAnalyticsPoint]] = [:]
        for (metric, values) in series {
            histories[metric] = values.enumerated().compactMap { index, value in
                guard let date = calendar.date(byAdding: .day, value: -(values.count - 1 - index), to: today) else {
                    return nil
                }
                return ProfileAnalyticsPoint(
                    id: "preview-\(metric.id)-\(index)",
                    date: date,
                    value: value
                )
            }
        }
        return histories
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
        ProcessDebloatTrajectoryStore.shared.sync(from: WelcomePlanStore.shared.plan)
        ProcessPlanProgressStore.shared.reload(plan: WelcomePlanStore.shared.plan)
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

    private func previousScan(before scan: FaceScanResult) -> FaceScanResult? {
        let ordered = faceHistoryStore.history
        guard let index = ordered.firstIndex(where: { $0.id == scan.id }),
              index + 1 < ordered.count else { return nil }
        return ordered[index + 1]
    }

    private var profileDaySwipeGesture: some Gesture {
        DragGesture(minimumDistance: 28, coordinateSpace: .local)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) > 70, abs(horizontal) > abs(vertical) * 1.2 else { return }

                if horizontal < 0 {
                    moveSelectedProfileDate(by: -1)
                } else {
                    moveSelectedProfileDate(by: 1)
                }
            }
    }

    private func moveSelectedProfileDate(by dayDelta: Int) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: creatorMode.effectiveNow)
        let current = calendar.startOfDay(for: selectedProfileDate)
        guard let candidate = calendar.date(byAdding: .day, value: dayDelta, to: current) else { return }
        let minDate = earliestSelectableProfileDate(calendar: calendar, today: today)
        let clamped = max(min(candidate, today), minDate)
        guard clamped != selectedProfileDate else { return }

        HapticManager.shared.selection()
        selectedProfileDate = clamped
    }

    private func earliestSelectableProfileDate(calendar: Calendar, today: Date) -> Date {
        if let startedAt = WelcomePlanStore.shared.plan?.calendar.startedAt {
            return calendar.startOfDay(for: startedAt)
        }

        let metricDates = chartHistories.values
            .flatMap { $0.map(\.date) }
            .map { calendar.startOfDay(for: $0) }
        let scanDates = faceHistoryStore.history
            .map { calendar.startOfDay(for: $0.createdAt) }

        if let earliest = (metricDates + scanDates).min() {
            return earliest
        }

        return calendar.date(byAdding: .day, value: -30, to: today) ?? today
    }
}

private enum ProfileStatisticsAnchor {
    static let id = "profileStatistics"
}

private enum ProfileOnboardingPreviewTopAnchor {
    static let id = "profileOnboardingPreviewTop"
}
