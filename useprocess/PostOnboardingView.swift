import SwiftUI

/// Écran minimal après l'onboarding — fond uni, sans dégradé.
struct PostOnboardingView: View {
    @Bindable private var session = AppSession.shared

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
                Text(AppConfiguration.appDisplayName)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)

                Text("Onboarding terminé")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))

                Button("Rejouer l'onboarding") {
                    session.resetOnboarding()
                }
                .buttonStyle(.bordered)
                .tint(.white)
            }
            .padding(.horizontal, 32)
        }
        .onAppear { AppIntegrations.shared.refresh() }
    }
}
