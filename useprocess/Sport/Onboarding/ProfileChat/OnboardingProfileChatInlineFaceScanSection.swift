//
//  OnboardingProfileChatInlineFaceScanSection.swift
//  useprocess
//

import SwiftUI

/// Bouton scan dans le chat — la capture se fait en page dédiée.
struct OnboardingProfileChatInlineFaceScanSection: View {
    @Environment(\.colorScheme) private var colorScheme

    let isSubmitting: Bool
    let isScanRevealed: Bool
    var onLaunchScan: () -> Void

    var body: some View {
        Button {
            guard !isSubmitting else { return }
            HapticManager.shared.impact(.medium)
            onLaunchScan()
        } label: {
            Text(OnboardingCopy.t("Lancer le scan", en: "Start the scan"))
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
        .onboardingChatAnswerReveal(isRevealed: isScanRevealed)
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
