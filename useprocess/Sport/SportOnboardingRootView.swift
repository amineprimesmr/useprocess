import SwiftUI

struct SportOnboardingRootView: View {
    @Bindable private var session = AppSession.shared
    @ObservedObject private var authManager = AuthenticationManager.shared

    var body: some View {
        SportOnboardingView()
            .onAppear {
                authManager.hasCompletedOnboarding = session.hasCompletedOnboarding
                if !session.hasCompletedOnboarding {
                    authManager.startOnboarding()
                }
            }
    }
}
