import SwiftUI

struct SportOnboardingRootView: View {
    @Bindable private var session = AppSession.shared
    @ObservedObject private var authManager = AuthenticationManager.shared

    var body: some View {
        SportOnboardingView()
            .onAppear {
                syncAuthWithSessionIfNeeded()
            }
    }

    @MainActor
    private func syncAuthWithSessionIfNeeded() {
        if authManager.hasCompletedOnboarding != session.hasCompletedOnboarding {
            authManager.hasCompletedOnboarding = session.hasCompletedOnboarding
        }
    }
}
