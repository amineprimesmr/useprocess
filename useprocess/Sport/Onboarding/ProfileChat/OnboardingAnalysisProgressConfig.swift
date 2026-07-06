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

    struct SourcePill: Identifiable, Equatable {
        let id: String
        let imageName: String?
        let systemImage: String?
        let label: String

        init(id: String, imageName: String? = nil, systemImage: String? = nil, label: String) {
            self.id = id
            self.imageName = imageName
            self.systemImage = systemImage
            self.label = label
        }
    }

    struct ProgressStep: Identifiable, Equatable {
        let id: String
        let phaseLabel: String
        let query: String
        let resultCount: Int?
        let sources: [SourcePill]
    }

    static let faceScanAnalysisSteps: [ProgressStep] = [
        .init(
            id: "mesh",
            phaseLabel: "Mesh facial",
            query: "Reconstruction 3D du visage…",
            resultCount: nil,
            sources: [
                .init(id: "faceScan", systemImage: "faceid", label: "Scan visage"),
                .init(id: "arkit", systemImage: "cube.transparent", label: "Mesh ARKit")
            ]
        ),
        .init(
            id: "markers",
            phaseLabel: "Biomarqueurs",
            query: "Calcul des indicateurs faciaux…",
            resultCount: 5,
            sources: [
                .init(id: "process", imageName: "caochiaicon", label: "Process AI"),
                .init(id: "symmetry", systemImage: "person.crop.circle", label: "Symétrie"),
                .init(id: "skin", systemImage: "sparkles", label: "Peau")
            ]
        ),
        .init(
            id: "healthkit",
            phaseLabel: "Données Santé",
            query: "Lecture de tes données dans l’app Santé…",
            resultCount: 4,
            sources: [
                .init(id: "health", imageName: "healthapple", label: "Santé"),
                .init(id: "sleep", systemImage: "bed.double.fill", label: "Sommeil"),
                .init(id: "heart", systemImage: "heart.fill", label: "Fréquence"),
                .init(id: "activity", systemImage: "figure.run", label: "Activité")
            ]
        ),
        .init(
            id: "claude",
            phaseLabel: "Réflexion IA",
            query: "Analyse avec Claude de ton scan…",
            resultCount: nil,
            sources: [
                .init(id: "claude", imageName: "claudeLogo", label: "Claude"),
                .init(id: "coach", imageName: "caochiaicon", label: "Coach Process")
            ]
        )
    ]

    static let answersAnalysisSteps: [ProgressStep] = [
        .init(
            id: "responses",
            phaseLabel: "Tes objectifs",
            query: "Analyse de tes objectifs et de ton ressenti…",
            resultCount: nil,
            sources: [
                .init(id: "profile", systemImage: "person.crop.circle", label: "Objectif"),
                .init(id: "habits", systemImage: "list.bullet.clipboard", label: "Habitudes")
            ]
        ),
        .init(
            id: "healthkit",
            phaseLabel: "Ton équilibre",
            query: "Croisement de tes habitudes et données Santé…",
            resultCount: nil,
            sources: [
                .init(id: "health", imageName: "healthapple", label: "Santé"),
                .init(id: "hydration", systemImage: "drop.fill", label: "Hydratation"),
                .init(id: "sleep", systemImage: "bed.double.fill", label: "Sommeil"),
                .init(id: "activity", systemImage: "figure.walk", label: "Mouvement")
            ]
        ),
        .init(
            id: "debloat",
            phaseLabel: "Phase Debloat",
            query: "Préparation de ta première phase…",
            resultCount: nil,
            sources: [
                .init(id: "nutrition", systemImage: "fork.knife", label: "Nutrition"),
                .init(id: "recovery", systemImage: "moon.zzz.fill", label: "Cernes et fatigue"),
                .init(id: "coach", imageName: "caochiaicon", label: "Process")
            ]
        )
    ]

    static let progressBarLabels = [
        "Connexion à l'app Santé",
        "Analyse de ton profil",
        "Génération de ton plan personnalisé"
    ]

    static let phases = progressBarLabels

    static let steps: [ProgressStep] = [
        .init(
            id: "healthkit",
            phaseLabel: phases[0],
            query: "Lecture de tes données dans l’app Santé…",
            resultCount: 4,
            sources: [
                .init(id: "health", imageName: "healthapple", label: "Santé"),
                .init(id: "activity", systemImage: "figure.run", label: "Activité"),
                .init(id: "sleep", systemImage: "bed.double.fill", label: "Sommeil"),
                .init(id: "heart", systemImage: "heart.fill", label: "Fréquence")
            ]
        ),
        .init(
            id: "claude",
            phaseLabel: phases[1],
            query: "Réflexion avec Claude sur ton profil…",
            resultCount: nil,
            sources: [
                .init(id: "claude", imageName: "claudeLogo", label: "Claude"),
                .init(id: "process", imageName: "caochiaicon", label: "Process AI")
            ]
        ),
        .init(
            id: "program",
            phaseLabel: phases[2],
            query: "Assemblage de ton programme sur mesure…",
            resultCount: nil,
            sources: [
                .init(id: "nutrition", systemImage: "fork.knife", label: "Nutrition"),
                .init(id: "training", systemImage: "dumbbell.fill", label: "Entraînement"),
                .init(id: "recovery", systemImage: "moon.zzz.fill", label: "Cernes et fatigue")
            ]
        )
    ]

    static let phaseEndPopups: [Popup?] = [
        .init(
            kind: .healthKit,
            question: "Connecte l'app Santé pour personnaliser ton plan avec tes vraies données."
        ),
        .init(
            kind: .yesNo,
            question: "As-tu déjà téléchargé une application de tracking personnalisé ?"
        ),
        nil
    ]

    static func phaseEndPopup(for phaseIndex: Int) -> Popup? {
        guard phaseEndPopups.indices.contains(phaseIndex) else { return nil }
        return phaseEndPopups[phaseIndex]
    }

    static let tickIntervalNs: UInt64 = 22_000_000
    static let segmentStep: Double = 0.012
    static let startDelayNs: UInt64 = 150_000_000

    static let programCreationTickIntervalNs: UInt64 = 34_000_000
    static let programCreationSegmentStep: Double = 0.0072
    static let programCreationStartDelayNs: UInt64 = 280_000_000

    static func stepIndex(forPhaseLabel label: String) -> Int? {
        steps.firstIndex { $0.phaseLabel == label }
    }

    static func step(forPhaseIndex index: Int) -> ProgressStep? {
        guard steps.indices.contains(index) else { return nil }
        return steps[index]
    }
}
