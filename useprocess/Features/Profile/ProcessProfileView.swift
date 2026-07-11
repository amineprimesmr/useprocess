import AuthenticationServices
import SwiftUI

/// Profil — scans visage, métriques et identité.
struct ProcessProfileView: View {
    @Binding var selectedSection: ProcessMainSection

    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var profileService: UnifiedProfileService
    @EnvironmentObject private var healthManager: HealthManager
    @Bindable private var faceHistoryStore = FaceScanHistoryStore.shared
    @Bindable private var planBridge = CoachPlanNavigationBridge.shared
    @State private var profileStore = SocialProfileStore.shared

    @State private var selectedAnalysisScan: FaceScanResult?

    @State private var chartHistories: [ProfileChartMetric: [ProfileAnalyticsPoint]] = [:]
    @State private var selectedProfileDate = Calendar.current.startOfDay(for: Date())

    private var resolvedProfile: SocialProfile {
        if let profile = profileStore.profile {
            return profile
        }
        if let unified = profileService.currentProfile {
            return SocialProfile.from(unified: unified)
        }
        return .guest
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    ProfileScanEvolutionHero(
                        historyStore: faceHistoryStore,
                        selectedDate: selectedProfileDate,
                        onOpenScan: { selectedAnalysisScan = $0 }
                    )

                    Color.clear
                        .frame(height: 0)
                        .id(ProfileStatisticsAnchor.id)

                    ProfileWeightStatisticsSection(
                        history: history(for: .weight),
                        latestValue: latestValue(for: .weight),
                        deltaVsPrevious: deltaVsPrevious(for: .weight)
                    )
                    .padding(.top, 14)
                    .padding(.bottom, 20)

                    profileScrollContent(resolvedProfile)
                }
                .processReportsTabBarScrollOffset()
            }
            .coordinateSpace(name: "processMainScroll")
            .scrollClipDisabled()
            .ignoresSafeArea(edges: .top)
            .scrollIndicators(.hidden)
            .processTransparentScrollSurface()
            .simultaneousGesture(profileDaySwipeGesture)
            .onAppear {
                selectedProfileDate = Calendar.current.startOfDay(for: Date())
                focusProfileStatisticsIfNeeded(using: proxy)
            }
            .onChange(of: planBridge.shouldFocusProfileStatistics) { _, should in
                guard should else { return }
                _ = planBridge.consumeProfileStatisticsFocus()
                focusProfileStatistics(using: proxy)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .processClearUIKitHostingBackground()
        .fullScreenCover(item: $selectedAnalysisScan) { scan in
            FaceScanResultContent(
                result: scan,
                previous: previousScan(before: scan),
                history: faceHistoryStore.history
            )
        }
        .task(id: profileService.currentProfile?.userId) {
            if profileService.currentProfile == nil {
                await profileService.loadProfile()
            }
            profileStore.bind(unified: profileService.currentProfile)
            await refreshProfile(forceHealthRefresh: false)
        }
        .onAppear {
            ProcessPerformanceTrace.endProfileOpen()
            Task { await reloadChartHistories() }
        }
        .onChange(of: profileService.currentProfile?.userId) { _, _ in
            profileStore.bind(unified: profileService.currentProfile)
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: selectedProfileDate)
    }

    @ViewBuilder
    private func profileScrollContent(_ profile: SocialProfile) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            ProfileIdentityBlock(
                displayName: profile.displayName,
                isPrivate: profile.isPrivate
            )

            profileChartsSection
        }
        .padding(.horizontal, ProfileTheme.horizontalPadding)
        .padding(.top, 20)
        .padding(.bottom, 32)
        .safeAreaPadding(.bottom, 8)
    }

    private var profileChartsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Indicateurs")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(theme.secondaryText)

            VStack(spacing: 16) {
                ForEach(ProfileChartMetric.profileDisplayOrder) { metric in
                    ProfileMetricChartSection(
                        metric: metric,
                        points: chartPoints(for: metric),
                        latestValue: latestValue(for: metric),
                        deltaVsPrevious: deltaVsPrevious(for: metric)
                    )
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
            if let latest = faceHistoryStore.history
                .filter({ $0.createdAt < calendar.date(byAdding: .day, value: 1, to: selectedDay) ?? selectedDay })
                .sorted(by: { $0.createdAt > $1.createdAt })
                .first,
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

    private func latestValue(for metric: ProfileChartMetric) -> Double? {
        chartPoints(for: metric).last?.value
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
        ProcessDebloatTrajectoryStore.shared.reload()
        ProcessDebloatTrajectoryStore.shared.sync(from: WelcomePlanStore.shared.plan)
        ProcessPlanProgressStore.shared.reload(plan: WelcomePlanStore.shared.plan)
        if forceHealthRefresh {
            await ProfileHealthSection.refreshAll(force: true)
        }
        await reloadChartHistories()
    }

    private func reloadChartHistories() async {
        FaceScanHistoryStore.shared.reloadForUser(userId: profileService.currentProfile?.userId)

        let scans = FaceScanHistoryStore.shared.history
        let weightSamples = await healthManager.fetchBodyMassHistory(days: 365)
        let effortSamples = await healthManager.fetchEffortHistory(days: 90)
        let profileWeight = profileService.currentProfile?.weight ?? 0

        var histories: [ProfileChartMetric: [ProfileAnalyticsPoint]] = [:]
        histories[.weight] = ProfileChartHistoryBuilder.mergeWithProfileFallback(
            history: weightSamples,
            profileWeight: profileWeight
        )
        histories[.effort] = effortSamples

        for metric in ProfileChartMetric.profileDisplayOrder {
            guard let kind = metric.faceScanKind else { continue }
            histories[metric] = ProfileChartHistoryBuilder.faceScanIndicatorHistory(
                from: scans,
                kind: kind
            )
        }

        chartHistories = histories
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
        let today = calendar.startOfDay(for: Date())
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
