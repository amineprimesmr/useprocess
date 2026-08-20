import SwiftUI

struct SportOnboardingRootView: View {
    @Bindable private var session = AppSession.shared

    var body: some View {
        SportOnboardingView()
            .id("fresh-onboarding-\(session.blocksAuthenticatedOnboardingRestore)-\(session.hasCompletedOnboarding)")
            .onAppear {
                syncAuthWithSessionIfNeeded()
            }
    }

    @MainActor
    private func syncAuthWithSessionIfNeeded() {
        let authManager = AuthenticationManager.shared
        authManager.hasCompletedOnboarding = session.hasCompletedOnboarding
        if session.blocksAuthenticatedOnboardingRestore || !session.hasCompletedOnboarding {
            authManager.isInOnboarding = true
        }
    }
}
