import SwiftUI

struct SportOnboardingRootView: View {
    @Bindable private var session = AppSession.shared

    var body: some View {
        SportOnboardingView()
            .onAppear {
                syncAuthWithSessionIfNeeded()
            }
    }

    @MainActor
    private func syncAuthWithSessionIfNeeded() {
        // Accès lazy — après le 1er frame, Firebase déjà configuré dans App.init.
        let authManager = AuthenticationManager.shared
        if authManager.hasCompletedOnboarding != session.hasCompletedOnboarding {
            authManager.hasCompletedOnboarding = session.hasCompletedOnboarding
        }
    }
}
