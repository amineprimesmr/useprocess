//
//  OnboardingProfileChatCoachHeader.swift
//  useprocess
//

import SwiftUI

enum OnboardingProfileChatCoachHeaderProgress {
    struct Snapshot: Equatable {
        let segmentCount: Int
        let completedSegments: Int
        let activeProgress: Double
    }

    static let introQuestionIDs = ["intro_swollen_face", "intro_causes", "intro_next"]
    static let numberedQuestionIDs = [
        "debloat_driver",
        "hydration_level",
        "junk_food",
        "sleep_hours",
        "cardio_frequency"
    ]

    private static let introSegments: [(questionID: String, blockIndex: Int)] = [
        ("intro_swollen_face", 0),
        ("intro_swollen_face", 1),
        ("intro_causes", 0),
        ("intro_next", 0)
    ]

    static func snapshot(questionID: String?, engine: MossConversationEngine) -> Snapshot? {
        guard let questionID, introQuestionIDs.contains(questionID) else {
            return nil
        }

        let segmentIndex = introSegmentIndex(questionID: questionID, engine: engine)
        let lineID = OnboardingMossChatHelpers.lineID(
            questionID: introSegments[segmentIndex].questionID,
            blockIndex: introSegments[segmentIndex].blockIndex
        )
        return Snapshot(
            segmentCount: 4,
            completedSegments: segmentIndex,
            activeProgress: typingFraction(lineID: lineID, engine: engine)
        )
    }

    private static func introSegmentIndex(questionID: String, engine: MossConversationEngine) -> Int {
        switch questionID {
        case "intro_swollen_face":
            let block1 = OnboardingMossChatHelpers.lineID(questionID: "intro_swollen_face", blockIndex: 1)
            return engine.messages.contains(where: { $0.id == block1 }) ? 1 : 0
        case "intro_causes":
            return 2
        case "intro_next":
            return 3
        default:
            return 0
        }
    }

    private static func typingFraction(lineID: String, engine: MossConversationEngine) -> Double {
        guard let line = engine.messages.first(where: { $0.id == lineID && $0.sender == .moss }) else {
            return engine.isTyping ? 0 : (engine.controlsVisible ? 1 : 0)
        }
        guard line.text.count > 0 else { return 1 }
        return min(1, Double(line.revealed) / Double(line.text.count))
    }
}

struct OnboardingProfileChatCoachHeader: View {
    let progress: OnboardingProfileChatCoachHeaderProgress.Snapshot

    /// Hauteur utile sous le bouton retour — alignée sur la barre onboarding standard.
    static let blockHeight: CGFloat = 5

    var body: some View {
        OnboardingSegmentedProgressBar(
            segmentCount: progress.segmentCount,
            completedSegments: progress.completedSegments,
            activeSegmentProgress: progress.activeProgress,
            height: Self.blockHeight
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AppCopy.t("Progression", en: "Progress"))
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        let current = min(progress.completedSegments + 1, progress.segmentCount)
        return AppCopy.t(
            "Étape \(current) sur \(progress.segmentCount)",
            en: "Step \(current) of \(progress.segmentCount)"
        )
    }
}
