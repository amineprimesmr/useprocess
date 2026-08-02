import Combine
import Foundation

/// Mode studio secret — débloqué uniquement si le prénom enregistré est « Amineprcs ».
/// Import photo + scans illimités + slider de rendu réaliste sur l’écran résultats.
@MainActor
final class ProcessCreatorModeStore: ObservableObject {
    static let shared = ProcessCreatorModeStore()

    static let unlockFirstName = "Amineprcs"

    private static let unlockedKeyBase = "creator.mode.unlocked"
    private static let qualityKeyBase = "creator.mode.quality"

    /// 0 = mauvais · 0.5 = réaliste (analyse) · 1 = excellent.
    @Published var resultQuality: Double {
        didSet { persistQuality() }
    }

    @Published private(set) var isUnlocked: Bool

    private init() {
        let defaults = UserDefaults.standard
        isUnlocked = defaults.bool(forKey: Self.storageKey(Self.unlockedKeyBase))
        let stored = defaults.double(forKey: Self.storageKey(Self.qualityKeyBase))
        // 0 = jamais écrit → défaut réaliste.
        resultQuality = defaults.object(forKey: Self.storageKey(Self.qualityKeyBase)) == nil
            ? 0.5
            : min(1, max(0, stored))
    }

    static func matchesUnlockName(_ name: String) -> Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare(unlockFirstName) == .orderedSame
    }

    func evaluate(firstName: String?) {
        let unlocked = Self.matchesUnlockName(firstName ?? "")
        guard unlocked != isUnlocked else { return }
        isUnlocked = unlocked
        UserDefaults.standard.set(unlocked, forKey: Self.storageKey(Self.unlockedKeyBase))
        objectWillChange.send()
    }

    func syncFromCurrentProfile() {
        evaluate(firstName: UnifiedProfileService.shared.currentProfile?.firstName)
    }

    var allowsUnlimitedScans: Bool { isUnlocked }
    var allowsPhotoImport: Bool { isUnlocked }

    var qualityLabel: String {
        switch resultQuality {
        case ..<0.2: return "Mauvais"
        case ..<0.4: return "Faible"
        case ..<0.6: return "Réaliste"
        case ..<0.8: return "Bon"
        default: return "Excellent"
        }
    }

    /// Applique le slider sur les markers d’analyse réelle.
    /// `variationSeed` (ex. scan id) fait varier les indicateurs d’un screen à l’autre.
    func applyQuality(
        to base: FaceWellnessMarkers,
        quality: Double? = nil,
        variationSeed: String = ""
    ) -> FaceWellnessMarkers {
        let q = min(1, max(0, quality ?? resultQuality))
        if abs(q - 0.5) < 0.03 { return base }

        let bad = studioBadMarkers(base: base, seed: variationSeed)
        let excellent = studioExcellentMarkers(base: base, seed: variationSeed)

        if q < 0.5 {
            // 0 → mauvais, 0.5 → réel
            return lerp(bad, base, amount: q / 0.5)
        }
        // 0.5 → réel, 1 → excellent (score global peut monter ~90–96 %)
        return lerp(base, excellent, amount: (q - 0.5) / 0.5)
    }

    func rebuildResult(_ result: FaceScanResult, quality: Double? = nil) -> FaceScanResult {
        let q = min(1, max(0, quality ?? resultQuality))
        let markers = applyQuality(
            to: result.markers,
            quality: q,
            variationSeed: result.id
        )
        let dayScore = FaceWellnessScore.dayScore(from: markers)
        // Près du max : neutralise sommeil/HRV pour que le cortisol reste ~10 % (formule markers pure).
        let neutralizeSleepHRV = q >= 0.85
        return FaceScanResult(
            id: result.id,
            userId: result.userId,
            createdAt: result.createdAt,
            markers: markers,
            snapshotFilename: result.snapshotFilename,
            videoFilename: result.videoFilename,
            claudeAnalysis: result.claudeAnalysis,
            aiEnhanced: result.aiEnhanced,
            coachInsightMessage: result.coachInsightMessage,
            coachInsightModel: result.coachInsightModel,
            source: result.source,
            sleepHoursAtScan: neutralizeSleepHRV ? nil : result.sleepHoursAtScan,
            hrvAtScan: neutralizeSleepHRV ? nil : result.hrvAtScan,
            faceDayScore: dayScore,
            relativeFaceDayScore: result.relativeFaceDayScore,
            scanConfidence: result.scanConfidence,
            baselineSampleCount: result.baselineSampleCount,
            relativeSignals: result.relativeSignals,
            studioFraming: result.studioFraming
        )
    }

    /// Cibles « excellent » — quasi parfaites au max du slider.
    /// Affiché : rétention ~5 %, cortisol ~10 %, cernes ~15 %, peau très haute, mâchoire déjà bonne.
    private func studioExcellentMarkers(base: FaceWellnessMarkers, seed: String) -> FaceWellnessMarkers {
        let puffiness = mix(seed, "ex.puff", in: 3...7)       // ~5 %
        let underEye = mix(seed, "ex.eye", in: 12...18)       // ~15 %
        let targetCortisol = mix(seed, "ex.cort", in: 8...12) // ~10 %

        // stressLoad = 0.40·puff + 0.42·eye + 0.18·jaw  → on inverse pour caler le cortisol.
        let rawWithoutJaw = 0.40 * Double(puffiness) + 0.42 * Double(underEye)
        let jawTarget = (Double(targetCortisol) - rawWithoutJaw) / 0.18
        let jawTension = Int(min(22, max(4, jawTarget.rounded())))

        return FaceWellnessMarkers(
            puffinessScore: puffiness,
            underEyeFatigueScore: underEye,
            jawTensionScore: jawTension,
            facialSymmetryScore: mix(seed, "ex.sym", in: 92...98),
            skinClarityScore: mix(seed, "ex.skin", in: 95...99),
            faceDefinitionScore: mix(seed, "ex.def", in: 90...97),
            notes: base.notes
        )
    }

    /// Cibles « mauvais » — aussi variées d’un screen à l’autre.
    private func studioBadMarkers(base: FaceWellnessMarkers, seed: String) -> FaceWellnessMarkers {
        FaceWellnessMarkers(
            puffinessScore: mix(seed, "bad.puff", in: 86...96),
            underEyeFatigueScore: mix(seed, "bad.eye", in: 84...95),
            jawTensionScore: mix(seed, "bad.jaw", in: 72...88),
            facialSymmetryScore: mix(seed, "bad.sym", in: 38...52),
            skinClarityScore: mix(seed, "bad.skin", in: 18...34),
            faceDefinitionScore: mix(seed, "bad.def", in: 18...32),
            notes: base.notes
        )
    }

    /// Hash stable → valeur dans la plage (varie d’un scan à l’autre, stable pour un même id).
    private func mix(_ seed: String, _ salt: String, in range: ClosedRange<Int>) -> Int {
        let raw = seed.isEmpty ? "default" : seed
        let bytes = Array((raw + "#" + salt).utf8)
        var hash: UInt64 = 14695981039346656037
        for byte in bytes {
            hash ^= UInt64(byte)
            hash = hash &* 1099511628211
        }
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(hash % span)
    }

    private func lerp(_ a: FaceWellnessMarkers, _ b: FaceWellnessMarkers, amount t: Double) -> FaceWellnessMarkers {
        let u = min(1, max(0, t))
        func mix(_ x: Int, _ y: Int) -> Int {
            Int((Double(x) + (Double(y) - Double(x)) * u).rounded())
        }
        let defA = a.faceDefinitionScore ?? FaceScanIndicators.definitionScore(from: a)
        let defB = b.faceDefinitionScore ?? FaceScanIndicators.definitionScore(from: b)
        return FaceWellnessMarkers(
            puffinessScore: mix(a.puffinessScore, b.puffinessScore),
            underEyeFatigueScore: mix(a.underEyeFatigueScore, b.underEyeFatigueScore),
            jawTensionScore: mix(a.jawTensionScore, b.jawTensionScore),
            facialSymmetryScore: mix(a.facialSymmetryScore, b.facialSymmetryScore),
            skinClarityScore: mix(a.skinClarityScore, b.skinClarityScore),
            faceDefinitionScore: mix(defA, defB),
            notes: b.notes.isEmpty ? a.notes : b.notes
        )
    }

    private func persistQuality() {
        UserDefaults.standard.set(resultQuality, forKey: Self.storageKey(Self.qualityKeyBase))
    }

    private static func storageKey(_ base: String) -> String {
        UserScopedStorage.key(base)
    }
}
