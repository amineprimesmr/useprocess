//
//  OnboardingProfileChatCoachHeader.swift
//  useprocess
//

import SwiftUI

enum OnboardingProfileChatCoachHeaderProgress {
    static let introQuestionIDs = ["intro_swollen_face", "intro_causes", "intro_next"]
    static let numberedQuestionIDs = [
        "debloat_driver",
        "hydration_level",
        "junk_food",
        "sleep_hours",
        "cardio_frequency"
    ]

    static func value(questionID: String?, engine: MossConversationEngine) -> Double {
        guard let questionID else { return 0 }

        let typing = typingFraction(questionID: questionID, engine: engine)

        if introQuestionIDs.contains(questionID) {
            guard let index = introQuestionIDs.firstIndex(of: questionID) else { return 0 }
            return min(1, (Double(index) + typing) / Double(introQuestionIDs.count))
        }

        if let index = numberedQuestionIDs.firstIndex(of: questionID) {
            let total = Double(numberedQuestionIDs.count)
            return min(1, (Double(index) + typing) / total)
        }

        // Scan / analyse — les 5 questions sont passées.
        return 1
    }

    private static func typingFraction(questionID: String, engine: MossConversationEngine) -> Double {
        let prefix = "process.chat.\(questionID)."
        let lines = engine.messages.filter { $0.sender == .moss && $0.id.hasPrefix(prefix) }
        if lines.isEmpty {
            return engine.isTyping ? 0 : (engine.controlsVisible ? 1 : 0)
        }
        let totalChars = lines.reduce(0) { $0 + $1.text.count }
        let revealedChars = lines.reduce(0) { $0 + $1.revealed }
        guard totalChars > 0 else { return 1 }
        return min(1, Double(revealedChars) / Double(totalChars))
    }
}

struct OnboardingProfileChatCoachHeader: View {
    let progress: Double

    @Environment(\.colorScheme) private var colorScheme

    /// Hauteur utile pour caler le scroll sous le header (aligné bouton retour).
    static let blockHeight: CGFloat = 84

    private enum Metrics {
        static let iconSize: CGFloat = 38
        static let barWidth: CGFloat = 52
        static let barHeight: CGFloat = 7
    }

    private var accentBlue: Color {
        colorScheme == .dark
            ? OnboardingTheme.accentHighlight
            : Color(red: 0.06, green: 0.36, blue: 0.78)
    }

    private var progressFillGradient: LinearGradient {
        PaywallBevelTheme.paywallProTitleGradient(for: colorScheme)
    }

    var body: some View {
        VStack(spacing: 4) {
            logoMark

            Text(AppCopy.t("Process Coach", en: "Process Coach"))
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(OnboardingTheme.primaryText)

            HStack(spacing: 5) {
                Circle()
                    .fill(Color(red: 0.20, green: 0.78, blue: 0.36))
                    .frame(width: 6, height: 6)

                Text(AppCopy.t("Ton coach personnel", en: "Your personal coach"))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(OnboardingTheme.mutedText)
            }

            progressBar
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(AppCopy.t("Process Coach", en: "Process Coach"))
        .accessibilityValue(AppCopy.t(
            "Progression \(Int(clampedProgress * 100)) pour cent",
            en: "Progress \(Int(clampedProgress * 100)) percent"
        ))
    }

    private var logoMark: some View {
        Image("process_coach_avatar")
            .resizable()
            .scaledToFill()
            .frame(width: Metrics.iconSize, height: Metrics.iconSize)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .strokeBorder(
                        accentBlue.opacity(colorScheme == .dark ? 0.22 : 0.14),
                        lineWidth: 0.75
                    )
            }
            .shadow(color: accentBlue.opacity(colorScheme == .dark ? 0.18 : 0.12), radius: 8, y: 0)
            .accessibilityHidden(true)
    }

    private var progressBar: some View {
        ZStack(alignment: .leading) {
            Capsule(style: .continuous)
                .fill(OnboardingTheme.progressTrack)
                .frame(width: Metrics.barWidth, height: Metrics.barHeight)

            Capsule(style: .continuous)
                .fill(progressFillGradient)
                .frame(width: max(Metrics.barHeight, Metrics.barWidth * clampedProgress), height: Metrics.barHeight)
                .shadow(
                    color: PaywallBevelTheme.accentBlueGlow(for: colorScheme).opacity(colorScheme == .dark ? 0.35 : 0.45),
                    radius: 6,
                    y: 0
                )
        }
        .frame(width: Metrics.barWidth, height: Metrics.barHeight)
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: clampedProgress)
    }

    private var clampedProgress: CGFloat {
        CGFloat(min(max(progress, 0), 1))
    }
}
