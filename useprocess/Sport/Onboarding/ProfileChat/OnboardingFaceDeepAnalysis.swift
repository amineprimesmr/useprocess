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
        var id: String { kind.id }
        let percent: Int
        let zone: FaceScanIndicators.WellnessZone
        let phrase: String
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

        var title: String {
            switch self {
            case .eyes: return "Yeux"
            case .midFace: return "Milieu du visage"
            case .lowerThird: return "Jawline"
            case .upperThird: return "Jawline"
            case .orbitalDepth: return "Cernes"
            case .underEyeHealth: return "Santé sous les yeux"
            case .nasolabialFold: return "Ligne nasogénienne"
            case .cheekbones: return "Pommettes"
            case .maxillary: return "Maxillaire"
            case .nose: return "Nez"
            case .skin: return "Peau"
            case .harmony: return "Harmonie"
            case .symmetry: return "Symétrie"
            case .neckWidth: return "Largeur du cou"
            case .boneMass: return "Masse osseuse"
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
