import SwiftUI

/// Bloc Santé (ex-page dédiée) — intégré au profil.
struct ProfileHealthSection: View {
    @EnvironmentObject private var healthManager: HealthManager
    @EnvironmentObject private var dataManager: DailyDataManager
    @EnvironmentObject private var profileService: UnifiedProfileService
    @Environment(\.appTheme) private var theme

    @Namespace private var faceScanHistoryZoomNamespace
    @State private var showFaceScan = false
    @State private var showFaceHistory = false
    @State private var selectedFaceScan: FaceScanResult?
    @State private var faceHistoryStore = FaceScanHistoryStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HealthPageSectionHeader(
                title: "Santé",
                subtitle: "Données du jour · Apple Santé"
            )

            if healthManager.readinessScore > 0 {
                ReadinessScoreGaugeView(
                    score: healthManager.readinessScore,
                    label: healthManager.readinessLabel,
                    subtitle: healthManager.readinessFactors.prefix(2).joined(separator: " · ")
                )
            }

            FaceScanHealthCompact(
                latest: faceHistoryStore.latestResult,
                faceDayScore: healthManager.faceDayScore,
                isScanDue: faceHistoryStore.isScanDue,
                daysUntilNextScan: faceHistoryStore.daysUntilNextScan,
                correlationHint: healthManager.faceCorrelations.first.map {
                    OriginPlanPresenter.truncate($0.message, max: 90)
                },
                historyZoomNamespace: faceScanHistoryZoomNamespace,
                onScan: { showFaceScan = true },
                onHistory: {
                    HapticManager.shared.impact(.light)
                    showFaceHistory = true
                }
            )

            HealthTodayMetricsCard()
        }
        .task { await ProfileHealthSection.refreshAll(force: false) }
        .onAppear {
            faceHistoryStore = FaceScanHistoryStore.shared
        }
        .fullScreenCover(isPresented: $showFaceScan) { faceScanCover }
        .fullScreenCover(isPresented: $showFaceHistory) {
            FaceScanHistoryView(history: faceHistoryStore.history) { scan in
                showFaceHistory = false
                selectedFaceScan = scan
            }
            .processZoomTransition(id: .faceScanHistory, namespace: faceScanHistoryZoomNamespace)
        }
        .sheet(item: $selectedFaceScan) { scan in
            FaceScanDetailView(
                result: scan,
                previous: faceHistoryStore.history.first(where: { $0.id != scan.id && $0.createdAt < scan.createdAt })
            )
        }
    }

    private static var lastRefresh: Date?

    static func refreshAll(force: Bool = true) async {
        if !force, let last = lastRefresh, Date().timeIntervalSince(last) < 120 {
            return
        }
        lastRefresh = Date()

        let healthManager = HealthManager.shared
        let dataManager = DailyDataManager.shared

        if healthManager.isHealthDataAvailable && !healthManager.isAuthorized {
            await healthManager.requestAuthorizationAsync()
        } else if healthManager.isAuthorized {
            await healthManager.performFullSync()
            await dataManager.updateCurrentDayData(with: healthManager)
        }
    }

    private var faceScanCover: some View {
        FaceScanPrivacyGateView(
            onDismiss: { showFaceScan = false },
            onComplete: { _ in
                faceHistoryStore = FaceScanHistoryStore.shared
                showFaceScan = false
                Task { await ProfileHealthSection.refreshAll(force: true) }
            }
        )
        .environmentObject(profileService)
    }
}

/// Conservé pour compatibilité — redirige vers le contenu profil.
struct HealthDashboardView: View {
    @Binding var selectedSection: ProcessMainSection

    var body: some View {
        ProcessProfileView(selectedSection: $selectedSection)
            .onAppear {
                selectedSection = .profile
            }
    }
}
