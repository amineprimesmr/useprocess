//
//  OnboardingPostPaymentThankYouView.swift
//  useprocess
//
//  Page dédiée après le paywall — remerciement + Sign in with Apple.
//

import SwiftUI

struct OnboardingPostPaymentThankYouView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var profileService: UnifiedProfileService

    let viewModel: OnboardingViewModel
    var onComplete: () -> Void

    @State private var isSigningIn = false
    @State private var errorMessage: String?

    private var needsAppleSignIn: Bool {
        AppConfiguration.firebaseConfigured && AuthUser.current == nil
    }

    private var appleButtonBackground: Color {
        colorScheme == .dark ? .white : .black
    }

    private var appleButtonForeground: Color {
        colorScheme == .dark ? .black : .white
    }

    var body: some View {
        ZStack {
            OnboardingTheme.screenBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 24)

                celebrationBlock
                    .padding(.horizontal, 32)

                Spacer(minLength: 32)

                bottomCTA
                    .padding(.horizontal, 28)
                    .padding(.bottom, 44)
            }
            .regularWidthContainer(maxWidth: AdaptiveScreenLayout.onboardingChatMaxWidth)
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

    private var celebrationBlock: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                OnboardingTheme.accentHighlight.opacity(0.22),
                                OnboardingTheme.accentHighlight.opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 96, height: 96)

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(OnboardingTheme.accentHighlight)
                    .symbolEffect(.bounce, value: isSigningIn)
            }

            VStack(spacing: 12) {
                Text("Merci !")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(OnboardingTheme.primaryText)

                Text("Ton accès Pro est activé. Connecte-toi pour sauvegarder ton profil, ton scan et ton plan.")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(OnboardingTheme.bodyText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var bottomCTA: some View {
        VStack(spacing: 14) {
            Group {
                if isSigningIn {
                    HStack {
                        Spacer(minLength: 0)
                        ProgressView()
                            .tint(needsAppleSignIn ? appleButtonForeground : .black)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(
                        Capsule().fill(
                            needsAppleSignIn ? appleButtonBackground : FaceIDScanColors.continueFill
                        )
                    )
                } else if needsAppleSignIn {
                    Button {
                        Task { await signInWithAppleAndFinish() }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 20, weight: .semibold))
                            Text("Continuer avec Apple")
                                .font(.system(size: 17, weight: .bold))
                        }
                        .foregroundStyle(appleButtonForeground)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(Capsule().fill(appleButtonBackground))
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.processPlain)
                } else {
                    FaceIDContinueButton {
                        HapticManager.shared.impact(.medium)
                        onComplete()
                    }
                }
            }
            .opacity(isSigningIn ? 0.72 : 1)

            if needsAppleSignIn {
                Text("Tes données restent privées et synchronisées sur tous tes appareils.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(OnboardingTheme.mutedText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
        }
    }

    @MainActor
    private func signInWithAppleAndFinish() async {
        guard !isSigningIn else { return }
        isSigningIn = true
        errorMessage = nil
        HapticManager.shared.impact(.medium)

        do {
            try await OnboardingAppleAuth.authenticateAndMigrate(
                authManager: authManager,
                profileService: profileService,
                viewModel: viewModel
            )
            HapticManager.shared.notification(.success)
            isSigningIn = false
            onComplete()
        } catch {
            HapticManager.shared.notification(.error)
            errorMessage = error.localizedDescription
            isSigningIn = false
        }
    }
}
