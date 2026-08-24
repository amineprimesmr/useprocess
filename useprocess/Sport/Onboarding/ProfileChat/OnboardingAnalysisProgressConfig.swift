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
            case .yesNo: return AppCopy.tSync("Oui", en: "Yes")
            case .healthKit: return AppCopy.tSync("Autoriser", en: "Allow")
            }
        }

        var negativeTitle: String {
            switch kind {
            case .yesNo: return AppCopy.tSync("Non", en: "No")
            case .healthKit: return AppCopy.tSync("Plus tard", en: "Later")
            }
        }
    }

    struct ProgressStep: Identifiable, Equatable, Sendable {
        let id: String
        let phaseLabel: String

        nonisolated init(id: String, phaseLabel: String) {
            self.id = id
            self.phaseLabel = phaseLabel
        }
    }

    nonisolated static var faceScanAnalysisSteps: [ProgressStep] {
        [
            .init(
                id: "face",
                phaseLabel: AppCopy.tSync("Rétention d'eau", en: "Water retention")
            ),
            .init(
                id: "structure",
                phaseLabel: AppCopy.tSync("Visage gonflé", en: "Puffy face")
            ),
            .init(
                id: "summary",
                phaseLabel: AppCopy.tSync("Bilan debloat", en: "Debloat readout")
            )
        ]
    }

    static var progressBarLabels: [String] {
        [
            AppCopy.tSync("Connexion à l'app Santé", en: "Connecting to Health"),
            AppCopy.tSync("Analyse de ton profil", en: "Analyzing your profile"),
            AppCopy.tSync("Génération de ton plan personnalisé", en: "Building your personal plan")
        ]
    }

    static var phases: [String] { progressBarLabels }

    static var phaseEndPopups: [Popup?] {
        [
            .init(
                kind: .healthKit,
                question: AppCopy.tSync(
                    "Connecte l'app Santé pour personnaliser ton plan avec tes vraies données.",
                    en: "Connect Health to personalize your plan with your real data."
                )
            ),
            .init(
                kind: .yesNo,
                question: AppCopy.tSync(
                    "As-tu déjà essayé de dégonfler ton visage ?",
                    en: "Have you already tried to debloat your face?"
                )
            ),
            nil
        ]
    }

    static func phaseEndPopup(for phaseIndex: Int) -> Popup? {
        guard phaseEndPopups.indices.contains(phaseIndex) else { return nil }
        return phaseEndPopups[phaseIndex]
    }

    static let tickIntervalNs: UInt64 = 22_000_000
    static let programCreationStartDelayNs: UInt64 = 180_000_000
}
