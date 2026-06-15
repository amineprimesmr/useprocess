import AuthenticationServices
import SwiftUI

/// Page d'accueil onboarding — connexion Apple ou mode démo.
struct OnboardingWelcomeStepView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var profileService: UnifiedProfileService

    var onComplete: () -> Void

    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Image("WelcomePage")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 14) {
                    Button {
                        Task { await handleAppleSignIn() }
                    } label: {
                        HStack(spacing: 10) {
                            if isLoading {
                                ProgressView().tint(OnboardingTheme.filledButtonText(for: colorScheme))
                            } else {
                                Image(systemName: "apple.logo")
                                    .font(.system(size: 20, weight: .semibold))
                                Text("Continuer avec Apple")
                                    .font(.system(size: 18, weight: .bold))
                            }
                        }
                        .foregroundStyle(OnboardingTheme.filledButtonText(for: colorScheme))
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            OnboardingTheme.filledButtonBackground(for: colorScheme),
                            in: RoundedRectangle(cornerRadius: 27)
                        )
                    }
                    .disabled(isLoading)

                    Button {
                        Task { await handleDemo() }
                    } label: {
                        Text("Mode démo")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(OnboardingTheme.narrativeText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .glassStyle()
                    .buttonBorderShape(.roundedRectangle(radius: 25))
                    .disabled(isLoading)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
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

    @MainActor
    private func handleDemo() async {
        guard !isLoading else { return }
        isLoading = true
        HapticManager.shared.impact(.medium)

        do {
            try await OnboardingWelcomeAuth.signInDemo(
                authManager: authManager,
                profileService: profileService
            )
            HapticManager.shared.notification(.success)
            isLoading = false
            onComplete()
        } catch {
            HapticManager.shared.notification(.error)
            errorMessage = "Le mode démo n'a pas pu démarrer. Réessaie."
            isLoading = false
        }
    }
}
