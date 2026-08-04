//
//  OnboardingDedicatedFaceScanResultsView.swift
//  useprocess
//

import StoreKit
import SwiftUI

/// Page dédiée du premier scan : anneau + indicateurs ouverts/verrouillés, sans « Ce qui change ».
struct OnboardingDedicatedFaceScanResultsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.requestReview) private var requestReview

    let result: FaceScanResult
    var isSigningIn: Bool
    var onContinue: () -> Void

    /// Premier scan onboarding : Apple tant qu’aucune session Firebase n’existe.
    /// (Ne pas lier l’affichage à `firebaseConfigured` — sinon le CTA retombe sur « Continuer » sans logo Apple.)
    private var needsAppleSignIn: Bool {
        AuthUser.current == nil
    }

    private var appleButtonBackground: Color {
        colorScheme == .dark ? .white : .black
    }

    private var appleButtonForeground: Color {
        colorScheme == .dark ? .black : .white
    }

    private var fullDateTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "EEEE d MMMM"
        let raw = formatter.string(from: result.createdAt)
        return raw.prefix(1).uppercased() + raw.dropFirst()
    }

    var body: some View {
        ZStack {
            FaceScanWhoopPalette.canvas.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 18)

                    FaceScanWhoopScoreRing(result: result)
                        .padding(.bottom, 22)

                    OnboardingFaceDeepAnalysisView(
                        result: result,
                        ringScale: 1,
                        showsScoreRing: false,
                        showsUnlockTeaser: false
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomCTA
            }
        }
        .task {
            guard !OnboardingAppStoreRatingPrompt.hasBeenShown else { return }
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            OnboardingAppStoreRatingPrompt.markShown()
            requestReview()
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("Premier scan")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(FaceScanWhoopPalette.secondary)
                .textCase(.uppercase)
                .tracking(0.8)

            Text(fullDateTitle)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(FaceScanWhoopPalette.label)
        }
        .frame(maxWidth: .infinity)
    }

    private var bottomCTA: some View {
        VStack(spacing: 10) {
            if !needsAppleSignIn {
                Text("Ton analyse est prête. Continue pour créer ton plan.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(FaceScanWhoopPalette.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }

            Group {
                if isSigningIn {
                    HStack {
                        Spacer(minLength: 0)
                        ProgressView()
                            .tint(needsAppleSignIn ? appleButtonForeground : .black)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        Capsule().fill(
                            needsAppleSignIn ? appleButtonBackground : FaceIDScanColors.continueFill
                        )
                    )
                } else if needsAppleSignIn {
                    Button {
                        HapticManager.shared.impact(.medium)
                        onContinue()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 20, weight: .semibold))
                            Text("Continuer avec Apple")
                                .font(.system(size: 17, weight: .bold))
                        }
                        .foregroundStyle(appleButtonForeground)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Capsule().fill(appleButtonBackground))
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                } else {
                    FaceIDContinueButton {
                        HapticManager.shared.impact(.medium)
                        onContinue()
                    }
                }
            }
            .opacity(isSigningIn ? 0.72 : 1)

            if needsAppleSignIn {
                Text("Connecte-toi pour sauvegarder ton analyse")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(FaceScanWhoopPalette.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background(
            LinearGradient(
                colors: [
                    FaceScanWhoopPalette.canvas.opacity(0),
                    FaceScanWhoopPalette.canvas.opacity(0.92),
                    FaceScanWhoopPalette.canvas
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}
