//
//  OnboardingProfileChatInlineFaceScanSection.swift
//  useprocess
//

import SwiftUI

/// Scan visage inline — intégré au fil de discussion, sans flash ni page imbriquée.
struct OnboardingProfileChatInlineFaceScanSection: View {
    @Environment(\.colorScheme) private var colorScheme

    let phase: OnboardingProfileChatViewModel.FaceScanInlinePhase
    let analysisProgress: Double
    let analysisPhaseIndex: Int
    let analysisPhaseLabel: String
    let analysisDisplayedPercentage: Int
    let analysisElapsedSeconds: Int
    let scanResult: FaceScanResult?
    let resultsUnlocked: Bool
    let isSubmitting: Bool
    let skipLabel: String?
    let isScanRevealed: Bool
    let capturedPayload: FaceScanCapturePayload?
    var onLaunchScan: () async -> Void
    var onSkip: () async -> Void
    var onCapture: (FaceScanCapturePayload, FaceWellnessMarkers) -> Void
    var onContinueResults: () -> Void

    private var viewportDiameter: CGFloat {
        min(UIScreen.main.bounds.width - 104, 228)
    }

    private var whoopRingScale: CGFloat {
        min(0.78, (UIScreen.main.bounds.width - 104) / 360)
    }

    private var heroScale: CGFloat {
        min(0.72, whoopRingScale * 0.92)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch phase {
            case .idle:
                idleContent
                    .id(FaceScanThreadAnchor.idle)
            case .capturing:
                captureContent
                    .id(FaceScanThreadAnchor.capturing)
            case .analyzing:
                analyzingContent
                    .id(FaceScanThreadAnchor.analyzing)
            case .results:
                resultsContent
                    .id(FaceScanThreadAnchor.results)
            }
        }
        .animation(OnboardingProfileChatAnswerReveal.spring, value: phase)
        .animation(.easeInOut(duration: 0.22), value: analysisProgress)
        .animation(OnboardingProfileChatAnswerReveal.spring, value: resultsUnlocked)
    }

    // MARK: - Idle

    @ViewBuilder
    private var idleContent: some View {
        launchScanButton
            .onboardingChatAnswerReveal(isRevealed: isScanRevealed)
    }

    private var launchScanButton: some View {
        Button {
            guard !isSubmitting else { return }
            HapticManager.shared.impact(.medium)
            Task { await onLaunchScan() }
        } label: {
            Text("Lancer le scan")
                .font(.system(size: OnboardingProfileChatDepthStyle.answerFontSize + 1, weight: .bold))
                .foregroundStyle(
                    isSubmitting
                        ? OnboardingTheme.mutedText
                        : OnboardingTheme.onboardingPrimaryActionText(for: colorScheme)
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .contentShape(Capsule())
        }
        .onboardingPrimaryActionStyle()
        .disabled(isSubmitting)
        .opacity(isSubmitting ? 0.55 : 1)
    }

    // MARK: - Capture

    private var captureContent: some View {
        FaceScanCaptureScreen(
            presentation: .embeddedCard(viewportDiameter: viewportDiameter),
            showsInlineHeader: false,
            onSkip: {
                Task { await onSkip() }
            },
            showsMediaImport: false,
            compactSkipAction: true,
            skipButtonTitle: skipLabel ?? "Faire mon scan plus tard",
            allowsScreenFlash: false,
            onContinue: onCapture
        )
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Analysis

    @ViewBuilder
    private var analyzingContent: some View {
        if let payload = capturedPayload {
            VStack(alignment: .leading, spacing: 18) {
                FaceScanAnalysisHeroView(payload: payload)
                    .scaleEffect(heroScale)
                    .frame(maxWidth: .infinity, alignment: .center)

                OnboardingProfileChatAnalysisPanel(
                    phaseLabel: analysisPhaseLabel,
                    phaseIndex: analysisPhaseIndex,
                    displayedPercentage: analysisDisplayedPercentage,
                    progress: analysisProgress,
                    elapsedSeconds: analysisElapsedSeconds,
                    isVisible: true,
                    steps: OnboardingAnalysisProgressConfig.faceScanAnalysisSteps
                )
            }
        }
    }

    // MARK: - Results — directement dans le fil, sans rectangle sombre

    @ViewBuilder
    private var resultsContent: some View {
        if let result = scanResult {
            FaceScanWhoopInlineResults(
                result: result,
                allowsCoachHandoff: false,
                showsInsight: false,
                showsTrends: false,
                ringScale: whoopRingScale,
                style: .chatThread
            )

            if resultsUnlocked {
                Button(action: onContinueResults) {
                    Text("Ça veut dire quoi ?")
                        .font(.system(size: OnboardingProfileChatDepthStyle.answerFontSize + 1, weight: .bold))
                        .foregroundStyle(OnboardingTheme.onboardingPrimaryActionText(for: colorScheme))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .contentShape(Capsule())
                }
                .onboardingPrimaryActionStyle()
                .padding(.top, 8)
                .id(FaceScanThreadAnchor.continueButton)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
    }
}

enum FaceScanThreadAnchor {
    static let idle = "face_scan_idle"
    static let capturing = "face_scan_capturing"
    static let analyzing = "face_scan_analyzing"
    static let results = "face_scan_results"
    static let continueButton = "face_scan_continue"
    static let bottom = "face_scan_bottom"
}
