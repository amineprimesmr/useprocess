import Foundation

/// Analyse structurelle enrichie — réservée au premier scan onboarding (teaser locked).
struct OnboardingFaceDeepAnalysis: Equatable {
    let unlocked: [UnlockedMetric]
    let volumeComposition: FacialVolumeComposition
    let lockedMetrics: [LockedMetric]
    let primaryFlaws: [String]
    let strengths: [String]
    let summary: String

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

    struct LockedMetric: Identifiable, Equatable {
        let kind: Kind
        var id: String { kind.rawValue }
        let percent: Int
        let zone: FaceScanIndicators.WellnessZone
    }

    enum Kind: String, CaseIterable, Identifiable {
        case eyes
        case midFace
        case lowerThird
        case upperThird
        case orbitalDepth
        case underEyeHealth
        case nasolabialFold
        case cheekbones
        case maxillary
        case nose
        case skin
        case harmony
        case symmetry
        case neckWidth
        case boneMass

        var id: String { rawValue }

        @MainActor
        var title: String {
            switch self {
            case .eyes: return OnboardingCopy.t("Yeux", en: "Eyes")
            case .midFace: return OnboardingCopy.t("Milieu du visage", en: "Mid-face")
            case .lowerThird: return "Jawline"
            case .upperThird: return "Jawline"
            case .orbitalDepth: return OnboardingCopy.t("Cernes", en: "Dark circles")
            case .underEyeHealth: return OnboardingCopy.t("Santé sous les yeux", en: "Under-eye health")
            case .nasolabialFold: return OnboardingCopy.t("Ligne nasogénienne", en: "Nasolabial fold")
            case .cheekbones: return OnboardingCopy.t("Pommettes", en: "Cheekbones")
            case .maxillary: return OnboardingCopy.t("Maxillaire", en: "Maxilla")
            case .nose: return OnboardingCopy.t("Nez", en: "Nose")
            case .skin: return OnboardingCopy.t("Peau", en: "Skin")
            case .harmony: return OnboardingCopy.t("Harmonie", en: "Harmony")
            case .symmetry: return OnboardingCopy.t("Symétrie", en: "Symmetry")
            case .neckWidth: return OnboardingCopy.t("Largeur du cou", en: "Neck width")
            case .boneMass: return OnboardingCopy.t("Masse osseuse", en: "Bone mass")
            }
        }

        var systemImage: String {
            switch self {
            case .eyes: return "eye.fill"
            case .midFace: return "circle.grid.cross.fill"
            case .lowerThird: return "arrow.down.to.line"
            case .upperThird: return "arrow.up.to.line"
            case .orbitalDepth: return "circle.dashed"
            case .underEyeHealth: return "moon.haze.fill"
            case .nasolabialFold: return "line.diagonal"
            case .cheekbones: return "triangle.fill"
            case .maxillary: return "square.fill"
            case .nose: return "nose"
            case .skin: return "sparkles"
            case .harmony: return "waveform"
            case .symmetry: return "arrow.left.and.right"
            case .neckWidth: return "rectangle.portrait.fill"
            case .boneMass: return "cube.fill"
            }
        }

        /// Plus haut = signal défavorable (charge). Sinon = qualité.
        var higherIsWorse: Bool {
            switch self {
            case .underEyeHealth, .nasolabialFold:
                return true
            default:
                return false
            }
        }
    }
}
