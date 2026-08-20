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

    static func snapshot(
        questionID: String?,
        engine: MossConversationEngine,
        isGlowUpResultsPresented: Bool = false
    ) -> Snapshot? {
        if isGlowUpResultsPresented {
            return glowUpResultsSnapshot()
        }

        guard let questionID else { return nil }

        if introQuestionIDs.contains(questionID) {
            return introSnapshot(questionID: questionID, engine: engine)
        }

        if numberedQuestionIDs.contains(questionID) {
            return numberedSnapshot(questionID: questionID, engine: engine)
        }

        if questionID == "profile_summary" {
            return Snapshot(
                segmentCount: numberedQuestionIDs.count,
                completedSegments: numberedQuestionIDs.count,
                activeProgress: 1
            )
        }

        return nil
    }

    /// Fin de l’intro — page animation glow-up (même barre 4 segments, tout rempli).
    static func glowUpResultsSnapshot() -> Snapshot {
        Snapshot(segmentCount: 4, completedSegments: 4, activeProgress: 1)
    }

    private static func introSnapshot(questionID: String, engine: MossConversationEngine) -> Snapshot {
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

    private static func numberedSnapshot(questionID: String, engine: MossConversationEngine) -> Snapshot {
        let segmentIndex = numberedQuestionIDs.firstIndex(of: questionID) ?? 0
        let lineID = OnboardingMossChatHelpers.lineID(questionID: questionID, blockIndex: 0)
        return Snapshot(
            segmentCount: numberedQuestionIDs.count,
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
