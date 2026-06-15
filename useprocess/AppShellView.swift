import SwiftUI

/// Racine SwiftUI — onboarding sport puis écran principal.
struct AppShellView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable private var session = AppSession.shared

    private var theme: AppTheme {
        AppTheme(appearance: session.appearance, colorScheme: colorScheme)
    }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            if session.hasCompletedOnboarding {
                MainAppView()
            } else {
                SportOnboardingRootView()
            }
        }
        .environment(\.appTheme, theme)
        .preferredColorScheme(session.appearance.preferredColorScheme)
        .environmentObject(AuthenticationManager.shared)
        .environmentObject(UnifiedProfileService.shared)
        .environmentObject(HealthManager.shared)
        .environmentObject(PermissionsManager.shared)
        .environmentObject(DailyDataManager.shared)
        .task {
            if AppConfiguration.firebaseConfigured {
                _ = UserSessionCoordinator.shared
                await UnifiedProfileService.shared.loadProfile()
            }
            if session.hasCompletedOnboarding, HealthManager.shared.isHealthDataAvailable {
                if HealthManager.shared.isAuthorized {
                    await HealthManager.shared.performFullSync()
                    await DailyDataManager.shared.updateCurrentDayData(with: HealthManager.shared)
                }
            }
        }
    }
}
