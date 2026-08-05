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
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if trimmed.caseInsensitiveCompare(unlockFirstName) == .orderedSame {
            return true
        }
        // Tolère typos / espaces internes (« Amine prcs », « amine-prcs »).
        let compact = trimmed
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
        return compact == unlockFirstName.lowercased()
    }

    /// Unlock live sans dépendre uniquement du flag UserDefaults.
    func isUnlocked(forFirstName firstName: String?) -> Bool {
        if isUnlocked { return true }
        if Self.matchesUnlockName(firstName ?? "") { return true }
        if Self.matchesUnlockName(UnifiedProfileService.shared.currentProfile?.firstName ?? "") {
            return true
        }
        return false
    }

    func evaluate(firstName: String?) {
        // Ne jamais verrouiller tant que le prénom n’est pas connu (profil pas encore hydraté).
        let trimmed = firstName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return }

        let unlocked = Self.matchesUnlockName(trimmed)
        guard unlocked != isUnlocked else { return }
        isUnlocked = unlocked
        UserDefaults.standard.set(unlocked, forKey: Self.storageKey(Self.unlockedKeyBase))
        objectWillChange.send()
    }

    func syncFromCurrentProfile() {
        let firstName = UnifiedProfileService.shared.currentProfile?.firstName
        // Recharge aussi depuis le storage user courant (clé anonymous → uid Firebase).
        reloadFromStorage()
        evaluate(firstName: firstName)
        // Si le prénom match mais le flag storage est faux (wipe), force le déblocage.
        if !isUnlocked, Self.matchesUnlockName(firstName ?? "") {
            isUnlocked = true
            UserDefaults.standard.set(true, forKey: Self.storageKey(Self.unlockedKeyBase))
            objectWillChange.send()
        }
    }

    /// Relit le flag unlock / qualité pour la clé UserDefaults actuelle.
    func reloadFromStorage() {
        let defaults = UserDefaults.standard
        let unlockedKey = Self.storageKey(Self.unlockedKeyBase)
        let qualityKey = Self.storageKey(Self.qualityKeyBase)

        // Migration : si la clé user est vide, récupère l’ancienne clé anonymous/local.
        if defaults.object(forKey: unlockedKey) == nil {
            for legacyUID in ["anonymous", "local-user"] {
                let legacy = UserScopedStorage.key(Self.unlockedKeyBase, userId: legacyUID)
                if defaults.object(forKey: legacy) != nil {
                    defaults.set(defaults.bool(forKey: legacy), forKey: unlockedKey)
                    let legacyQuality = UserScopedStorage.key(Self.qualityKeyBase, userId: legacyUID)
                    if defaults.object(forKey: legacyQuality) != nil {
                        defaults.set(defaults.double(forKey: legacyQuality), forKey: qualityKey)
                    }
                    break
                }
            }
        }

        let unlocked = defaults.bool(forKey: unlockedKey)
        if unlocked != isUnlocked {
            isUnlocked = unlocked
        }
        if defaults.object(forKey: qualityKey) != nil {
            let stored = min(1, max(0, defaults.double(forKey: qualityKey)))
            if abs(stored - resultQuality) > 0.0001 {
                resultQuality = stored
            }
        }
    }

    var allowsUnlimitedScans: Bool { isUnlocked }
    var allowsPhotoImport: Bool { isUnlocked }

    var qualityLabel: String {
        switch resultQuality {
        case ..<0.2: return AppCopy.t("Mauvais", en: "Poor")
        case ..<0.4: return AppCopy.t("Faible", en: "Weak")
        case ..<0.6: return AppCopy.t("Réaliste", en: "Realistic")
        case ..<0.8: return AppCopy.t("Bon", en: "Good")
        default: return AppCopy.t("Excellent", en: "Excellent")
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
