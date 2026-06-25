//
//  OnboardingAnalysisProgressConfig.swift
//  useprocess
//

import Foundation

enum OnboardingAnalysisProgressConfig {
    enum PopupKind {
        case yesNo
        case healthKit
    }

    struct Popup {
        let kind: PopupKind
        let question: String

        var affirmativeTitle: String {
            switch kind {
            case .yesNo: return "Oui"
            case .healthKit: return "Autoriser"
            }
        }

        var negativeTitle: String {
            switch kind {
            case .yesNo: return "Non"
            case .healthKit: return "Plus tard"
            }
        }
    }

    static let phases = [
        "Analyse des habitudes",
        "Objectifs personnalisés",
        "Création du programme"
    ]

    static let popups: [Popup] = [
        .init(kind: .yesNo, question: "Es-tu prêt à terminer ce que tu commences ?"),
        .init(kind: .healthKit, question: "Autorises-tu l'accès à Santé Apple pour analyser tes données ?"),
        .init(kind: .yesNo, question: "As-tu déjà téléchargé une application de tracking personnalisé ?")
    ]

    static let tickIntervalNs: UInt64 = 22_000_000
    static let segmentStep: Double = 0.012
    static let startDelayNs: UInt64 = 150_000_000
}
