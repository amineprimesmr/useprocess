import AuthenticationServices
import SwiftUI

/// Profil — scans visage, métriques et identité.
struct ProcessProfileView: View {
    @Binding var selectedSection: ProcessMainSection

    @EnvironmentObject private var profileService: UnifiedProfileService
    @EnvironmentObject private var healthManager: HealthManager
    @Bindable private var streakStore = ProcessStreakStore.shared
    @Bindable private var faceHistoryStore = FaceScanHistoryStore.shared
    @State private var profileStore = SocialProfileStore.shared

    @State private var selectedAnalysisScan: FaceScanResult?

    @State private var chartHistories: [ProfileChartMetric: [ProfileAnalyticsPoint]] = [:]

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
        ScrollView {
            VStack(spacing: 0) {
                ProfileScanEvolutionHero(
                    historyStore: faceHistoryStore,
                    onOpenScan: { selectedAnalysisScan = $0 }
                )

                profileScrollContent(resolvedProfile)
            }
            .processReportsTabBarScrollOffset()
        }
        .coordinateSpace(name: "processMainScroll")
        .scrollClipDisabled()
        .ignoresSafeArea(edges: .top)
        .scrollIndicators(.hidden)
        .processTransparentScrollSurface()
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

    private func history(for metric: ProfileChartMetric) -> [ProfileAnalyticsPoint] {
        chartHistories[metric] ?? []
    }

    private func chartPoints(for metric: ProfileChartMetric) -> [ProfileAnalyticsPoint] {
        let points = ProfileChartHistoryBuilder.visiblePoints(
            history: history(for: metric),
            range: .profileDefault,
            weekOffset: 0
        )
        if !points.isEmpty { return points }
        return fallbackChartPoints(for: metric)
    }

    private func fallbackChartPoints(for metric: ProfileChartMetric) -> [ProfileAnalyticsPoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        switch metric {
        case .weight:
            if healthManager.todaySnapshot.vitals.bodyMass > 0 {
                return [
                    ProfileAnalyticsPoint(
                        id: "weight-today",
                        date: today,
                        value: healthManager.todaySnapshot.vitals.bodyMass
                    )
                ]
            }
            let profileWeight = profileService.currentProfile?.weight ?? 0
            if profileWeight > 0 {
                return [
                    ProfileAnalyticsPoint(
                        id: "profile-weight",
                        date: today,
                        value: profileWeight
                    )
                ]
            }

        case .retention, .recovery, .cortisol, .definition, .skin:
            if let latest = FaceScanHistoryStore.shared.latestResult,
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
            let effortScore = healthManager.todaySnapshot.effort.effortScore
            if effortScore > 0 {
                return [
                    ProfileAnalyticsPoint(
                        id: "effort-today",
                        date: today,
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
        let currentAverage = ProfileChartHistoryBuilder.average(
            in: ProfileChartHistoryBuilder.visiblePoints(
                history: history(for: metric),
                range: .week,
                weekOffset: 0
            )
        )
        let previousAverage = ProfileChartHistoryBuilder.previousPeriodAverage(
            history: history(for: metric),
            range: .week,
            weekOffset: 0
        )

        guard let currentAverage, let previousAverage else { return nil }
        return currentAverage - previousAverage
    }

    private func refreshProfile(forceHealthRefresh: Bool) async {
        streakStore.reload()
        streakStore.sync(from: WelcomePlanStore.shared.plan)
        if forceHealthRefresh {
            await ProfileHealthSection.refreshAll(force: true)
        }
        await reloadChartHistories()
    }

    private func reloadChartHistories() async {
        FaceScanHistoryStore.shared.reloadForUser(userId: profileService.currentProfile?.userId)

        let scans = FaceScanHistoryStore.shared.history
        let weightSamples = await healthManager.fetchBodyMassHistory(days: 90)
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
}
