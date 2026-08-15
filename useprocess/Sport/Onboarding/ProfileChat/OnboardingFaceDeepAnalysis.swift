import Foundation

/// Analyse premier scan onboarding — rétention visible, notes de zones verrouillées.
struct OnboardingFaceDeepAnalysis: Equatable {
    let unlocked: [UnlockedMetric]
    let volumeComposition: FacialVolumeComposition
    let lockedMetrics: [LockedMetric]
    let priorities: [BloatPriority]
    let triggers: [BloatTrigger]

    /// Part graisse vs rétention / liquide retenu sur le volume facial perçu.
    struct FacialVolumeComposition: Equatable {
        let fatPercent: Int
        let bloatedPercent: Int
        let phrase: String
        let goodNewsPhrase: String
    }

    struct UnlockedMetric: Identifiable, Equatable {
        let kind: FaceScanIndicators.Kind
        let percent: Int
        let zone: FaceScanIndicators.WellnessZone
        let phrase: String
        /// Titre custom (ex. Potentiel) — sinon `kind.whoopLabel`.
        var customTitle: String? = nil
        var customSystemImage: String? = nil
        var customID: String? = nil
        var customHigherIsWorse: Bool? = nil

        var id: String { customID ?? kind.id }

        var higherIsWorse: Bool {
            customHigherIsWorse ?? kind.higherIsWorse
        }

        @MainActor
        var title: String {
            customTitle ?? (kind == .stressLoad
                ? AppCopy.t("CORTISOL ESTIMÉ", en: "ESTIMATED CORTISOL")
                : kind.whoopLabel)
        }

        var systemImage: String {
            customSystemImage ?? kind.systemImage
        }
    }

    /// Zone de gonflement — le nom est visible, la note est teaser.
    struct LockedMetric: Identifiable, Equatable {
        let kind: Kind
        var id: String { kind.rawValue }
        let percent: Int
        let zone: FaceScanIndicators.WellnessZone
    }

    /// Priorité plan — certains titres restent lisibles, d’autres sont teaser.
    struct BloatPriority: Identifiable, Equatable {
        let id: String
        let title: String
        let note: String
        let systemImage: String
        var hidesTitle: Bool = false
    }

    /// Facteur qui déclenche le gonflement.
    struct BloatTrigger: Identifiable, Equatable {
        let id: String
        let title: String
        let note: String
        let systemImage: String
        var hidesTitle: Bool = false
    }

    enum Kind: String, CaseIterable, Identifiable {
        case cheeks
        case underEyes
        case jawline
        case chin
        case neckLymph

        var id: String { rawValue }

        @MainActor
        var title: String {
            switch self {
            case .cheeks: return AppCopy.t("Joues", en: "Cheeks")
            case .underEyes: return AppCopy.t("Sous les yeux", en: "Under-eyes")
            case .jawline: return AppCopy.t("Mâchoire", en: "Jawline")
            case .chin: return AppCopy.t("Menton", en: "Chin")
            case .neckLymph: return AppCopy.t("Cou / lymphe", en: "Neck / lymph")
            }
        }

        var systemImage: String {
            switch self {
            case .cheeks: return "circle.lefthalf.filled"
            case .underEyes: return "eye.fill"
            case .jawline: return "triangle.fill"
            case .chin: return "arrow.down.to.line"
            case .neckLymph: return "water.waves"
            }
        }

        /// Note = charge de gonflement (plus haut = plus marqué).
        var higherIsWorse: Bool { true }

        var hidesName: Bool {
            switch self {
            case .chin, .neckLymph: return true
            default: return false
            }
        }
    }
}
