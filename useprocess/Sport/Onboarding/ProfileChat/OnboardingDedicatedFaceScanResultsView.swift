//
//  OnboardingDedicatedFaceScanResultsView.swift
//  useprocess
//

import SwiftUI

/// Page dédiée du premier scan : anneau + indicateurs ouverts/verrouillés, sans « Ce qui change ».
struct OnboardingDedicatedFaceScanResultsView: View {
    @Environment(\.colorScheme) private var colorScheme

    let result: FaceScanResult
    var isSigningIn: Bool
    var onContinue: () -> Void

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
        ZStack(alignment: .bottom) {
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

                    Spacer(minLength: 150)
                }
            }

            bottomCTA
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

            Button {
                guard !isSigningIn else { return }
                HapticManager.shared.impact(.medium)
                onContinue()
            } label: {
                HStack(spacing: 10) {
                    if isSigningIn {
                        ProgressView()
                            .tint(appleButtonForeground)
                    } else if needsAppleSignIn {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 20, weight: .semibold))
                        Text("Continuer avec Apple")
                            .font(.system(size: 17, weight: .bold))
                    } else {
                        Text("Continuer")
                            .font(.system(size: 17, weight: .bold))
                    }
                }
                .foregroundStyle(appleButtonForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Capsule().fill(appleButtonBackground))
                .contentShape(Capsule())
            }
            .disabled(isSigningIn)
            .opacity(isSigningIn ? 0.72 : 1)

            if needsAppleSignIn {
                Text("Connecte-toi pour sauvegarder ton analyse et retrouver ton plan sur tous tes appareils.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(FaceScanWhoopPalette.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 28)
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
            .ignoresSafeArea(edges: .bottom)
        )
    }
}
