//
//  OnboardingDedicatedFaceScanResultsView.swift
//  useprocess
//

import StoreKit
import SwiftUI

/// Page dédiée du premier scan : anneau + indicateurs ouverts/verrouillés, sans « Ce qui change ».
struct OnboardingDedicatedFaceScanResultsView: View {
    @Environment(\.requestReview) private var requestReview

    let result: FaceScanResult
    var onContinue: () -> Void

    private var fullDateTitle: String {
        let formatter = DateFormatter()
        formatter.locale = ProcessAppLanguage.shared.locale
        formatter.dateFormat = ProcessAppLanguage.shared.isEnglish ? "EEEE, MMMM d" : "EEEE d MMMM"
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
            Text(OnboardingCopy.t("Premier scan", en: "First scan"))
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
            Text(OnboardingCopy.t(
                "Ton analyse est prête. Continue pour créer ton plan.",
                en: "Your analysis is ready. Continue to create your plan."
            ))
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(FaceScanWhoopPalette.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)

            FaceIDContinueButton {
                HapticManager.shared.impact(.medium)
                onContinue()
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
