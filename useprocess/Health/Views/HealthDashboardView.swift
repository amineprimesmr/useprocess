import SwiftUI

/// Bloc Santé (ex-page dédiée) — intégré au profil.
struct ProfileHealthSection: View {
    @EnvironmentObject private var healthManager: HealthManager
    @EnvironmentObject private var dataManager: DailyDataManager
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HealthPageSectionHeader(
                title: AppCopy.t("Santé", en: "Health"),
                subtitle: AppCopy.t("Données du jour · Apple Santé", en: "Today’s data · Apple Health")
            )

            HealthTodayMetricsCard()
        }
        .task {
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            await ProfileHealthSection.refreshAll(force: false)
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
            await healthManager.requestAuthorizationAsync(analyticsSource: "health_dashboard")
        } else if healthManager.isAuthorized {
            await healthManager.performFullSync()
            await dataManager.updateCurrentDayData(with: healthManager)
        }
    }
}
