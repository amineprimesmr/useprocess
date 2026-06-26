import SwiftUI

/// Bloc Santé (ex-page dédiée) — intégré au profil.
struct ProfileHealthSection: View {
    @EnvironmentObject private var healthManager: HealthManager
    @EnvironmentObject private var dataManager: DailyDataManager
    @Environment(\.appTheme) private var theme

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

            HealthTodayMetricsCard()
        }
        .task { await ProfileHealthSection.refreshAll(force: false) }
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
