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

    struct SourcePill: Identifiable, Equatable, Sendable {
        let id: String
        let imageName: String?
        let systemImage: String?
        let label: String

        nonisolated init(id: String, imageName: String? = nil, systemImage: String? = nil, label: String) {
            self.id = id
            self.imageName = imageName
            self.systemImage = systemImage
            self.label = label
        }
    }

    struct ProgressStep: Identifiable, Equatable, Sendable {
        let id: String
        let phaseLabel: String
        let query: String
        let resultCount: Int?
        let sources: [SourcePill]

        nonisolated init(
            id: String,
            phaseLabel: String,
            query: String,
            resultCount: Int?,
            sources: [SourcePill]
        ) {
            self.id = id
            self.phaseLabel = phaseLabel
            self.query = query
            self.resultCount = resultCount
            self.sources = sources
        }
    }

    nonisolated static var faceScanAnalysisSteps: [ProgressStep] {
        [
            .init(
                id: "mesh",
                phaseLabel: AppCopy.tSync("Scan vidéo", en: "Video scan"),
                query: AppCopy.tSync("Analyse de ta capture vidéo…", en: "Analyzing your video capture…"),
                resultCount: nil,
                sources: [
                    .init(id: "faceScan", systemImage: "faceid", label: AppCopy.tSync("Scan visage", en: "Face scan")),
                    .init(id: "video", systemImage: "video.fill", label: AppCopy.tSync("Vidéo", en: "Video"))
                ]
            ),
            .init(
                id: "markers",
                phaseLabel: AppCopy.tSync("Biomarqueurs", en: "Biomarkers"),
                query: AppCopy.tSync(
                    "Rétention, cortisol et signaux faciaux…",
                    en: "Retention, cortisol, and facial signals…"
                ),
                resultCount: 2,
                sources: [
                    .init(id: "claude", imageName: "claudeLogo", label: "Claude"),
                    .init(id: "retention", systemImage: "drop.fill", label: AppCopy.tSync("Rétention", en: "Retention")),
                    .init(id: "cortisol", systemImage: "waveform.path.ecg", label: "Cortisol")
                ]
            ),
            .init(
                id: "structure",
                phaseLabel: AppCopy.tSync("Structure faciale", en: "Facial structure"),
                query: AppCopy.tSync(
                    "Yeux, jawline, pommettes, maxillaire, harmonie…",
                    en: "Eyes, jawline, cheekbones, maxilla, harmony…"
                ),
                resultCount: 15,
                sources: [
                    .init(id: "claude", imageName: "claudeLogo", label: "Claude"),
                    .init(id: "symmetry", systemImage: "arrow.left.and.right", label: AppCopy.tSync("Symétrie", en: "Symmetry")),
                    .init(id: "bone", systemImage: "cube.fill", label: AppCopy.tSync("Osseux", en: "Bone"))
                ]
            ),
            .init(
                id: "healthkit",
                phaseLabel: AppCopy.tSync("Données Santé", en: "Health data"),
                query: AppCopy.tSync(
                    "Lecture de tes données dans l’app Santé…",
                    en: "Reading your Health app data…"
                ),
                resultCount: 4,
                sources: [
                    .init(id: "health", imageName: "healthapple", label: AppCopy.tSync("Santé", en: "Health")),
                    .init(id: "sleep", systemImage: "bed.double.fill", label: AppCopy.tSync("Sommeil", en: "Sleep")),
                    .init(id: "heart", systemImage: "heart.fill", label: AppCopy.tSync("Fréquence", en: "Heart rate")),
                    .init(id: "activity", systemImage: "figure.run", label: AppCopy.tSync("Activité", en: "Activity"))
                ]
            ),
            .init(
                id: "claude",
                phaseLabel: AppCopy.tSync("Synthèse Claude", en: "Claude summary"),
                query: AppCopy.tSync(
                    "Claude rédige ton résumé personnalisé…",
                    en: "Claude is writing your personal summary…"
                ),
                resultCount: nil,
                sources: [
                    .init(id: "claude", imageName: "claudeLogo", label: "Claude")
                ]
            )
        ]
    }

    nonisolated static var answersAnalysisSteps: [ProgressStep] {
        [
            .init(
                id: "responses",
                phaseLabel: AppCopy.tSync("Tes objectifs", en: "Your goals"),
                query: AppCopy.tSync(
                    "Analyse de tes objectifs et de ton ressenti…",
                    en: "Analyzing your goals and how you feel…"
                ),
                resultCount: nil,
                sources: [
                    .init(id: "profile", systemImage: "person.crop.circle", label: AppCopy.tSync("Objectif", en: "Goal")),
                    .init(id: "habits", systemImage: "list.bullet.clipboard", label: AppCopy.tSync("Habitudes", en: "Habits"))
                ]
            ),
            .init(
                id: "healthkit",
                phaseLabel: AppCopy.tSync("Ton équilibre", en: "Your balance"),
                query: AppCopy.tSync(
                    "Croisement de tes habitudes et données Santé…",
                    en: "Crossing your habits with Health data…"
                ),
                resultCount: nil,
                sources: [
                    .init(id: "health", imageName: "healthapple", label: AppCopy.tSync("Santé", en: "Health")),
                    .init(id: "hydration", systemImage: "drop.fill", label: AppCopy.tSync("Hydratation", en: "Hydration")),
                    .init(id: "sleep", systemImage: "bed.double.fill", label: AppCopy.tSync("Sommeil", en: "Sleep")),
                    .init(id: "activity", systemImage: "figure.walk", label: AppCopy.tSync("Mouvement", en: "Movement"))
                ]
            ),
            .init(
                id: "debloat",
                phaseLabel: AppCopy.tSync("Phase Debloat", en: "Debloat phase"),
                query: AppCopy.tSync(
                    "Préparation de ta première phase…",
                    en: "Preparing your first phase…"
                ),
                resultCount: nil,
                sources: [
                    .init(id: "nutrition", systemImage: "fork.knife", label: AppCopy.tSync("Nutrition", en: "Nutrition")),
                    .init(
                        id: "recovery",
                        systemImage: "moon.zzz.fill",
                        label: AppCopy.tSync("Cernes et fatigue", en: "Under-eyes & fatigue")
                    ),
                    .init(id: "coach", imageName: "caochiaicon", label: "Process")
                ]
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

    static var steps: [ProgressStep] {
        let labels = phases
        return [
            .init(
                id: "healthkit",
                phaseLabel: labels[0],
                query: AppCopy.tSync("Lecture de tes données dans l’app Santé…", en: "Reading your Health app data…"),
                resultCount: 4,
                sources: [
                    .init(id: "health", imageName: "healthapple", label: AppCopy.tSync("Santé", en: "Health")),
                    .init(id: "activity", systemImage: "figure.run", label: AppCopy.tSync("Activité", en: "Activity")),
                    .init(id: "sleep", systemImage: "bed.double.fill", label: AppCopy.tSync("Sommeil", en: "Sleep")),
                    .init(id: "heart", systemImage: "heart.fill", label: AppCopy.tSync("Fréquence", en: "Heart rate"))
                ]
            ),
            .init(
                id: "claude",
                phaseLabel: labels[1],
                query: AppCopy.tSync("Réflexion avec Claude sur ton profil…", en: "Reviewing your profile with Claude…"),
                resultCount: nil,
                sources: [
                    .init(id: "claude", imageName: "claudeLogo", label: "Claude"),
                    .init(id: "process", imageName: "caochiaicon", label: "Process")
                ]
            ),
            .init(
                id: "program",
                phaseLabel: labels[2],
                query: AppCopy.tSync("Assemblage de ton programme sur mesure…", en: "Assembling your custom program…"),
                resultCount: nil,
                sources: [
                    .init(id: "nutrition", systemImage: "fork.knife", label: AppCopy.tSync("Nutrition", en: "Nutrition")),
                    .init(id: "training", systemImage: "dumbbell.fill", label: AppCopy.tSync("Entraînement", en: "Training")),
                    .init(id: "recovery", systemImage: "moon.zzz.fill", label: AppCopy.tSync("Cernes et fatigue", en: "Under-eyes & fatigue"))
                ]
            )
        ]
    }

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
