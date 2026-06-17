import SwiftUI

/// Page d'accueil onboarding avec connexion Apple.
struct OnboardingWelcomeStepView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var profileService: UnifiedProfileService

    var onComplete: () -> Void

    @State private var isLoading = false
    @State private var errorMessage: String?

    private var welcomeBackgroundImage: String {
        LayoutConstants.isIPad ? "WelcomePageiPad" : "WelcomePage"
    }

    private var horizontalPadding: CGFloat {
        LayoutConstants.isIPad ? 48 : 32
    }

    private var bottomPadding: CGFloat {
        LayoutConstants.isIPad ? 56 : 48
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image(welcomeBackgroundImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()

                VStack(spacing: 0) {
                    Spacer()

                    VStack(spacing: 14) {
                        Button {
                            Task { await handleAppleSignIn() }
                        } label: {
                            HStack(spacing: 10) {
                                if isLoading {
                                    ProgressView()
                                        .tint(.black)
                                } else {
                                    Image(systemName: "apple.logo")
                                        .font(.system(size: 20, weight: .semibold))
                                    Text("Continuer avec Apple")
                                        .font(.system(size: 18, weight: .bold))
                                }
                            }
                            .foregroundStyle(Color.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 27, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(isLoading)
                    }
                    .regularWidthContainer(maxWidth: 480)
                    .padding(.horizontal, horizontalPadding)
                    .frame(maxWidth: geometry.size.width)
                    .padding(.bottom, bottomPadding)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
        .alert("Connexion impossible", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @MainActor
    private func handleAppleSignIn() async {
        guard !isLoading else { return }
        isLoading = true
        HapticManager.shared.impact(.heavy)

        do {
            try await OnboardingWelcomeAuth.signInWithApple(
                authManager: authManager,
                profileService: profileService
            )
            HapticManager.shared.notification(.success)
            isLoading = false
            onComplete()
        } catch {
            HapticManager.shared.notification(.error)
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}
