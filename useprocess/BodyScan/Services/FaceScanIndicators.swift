import Foundation

/// Cinq indicateurs Process du scan visage — libellés, scores et comparaisons.
enum FaceScanIndicators {

    enum Kind: String, CaseIterable, Identifiable {
        case retention
        case stressLoad
        case recovery
        case definition
        case skin

        var id: String { rawValue }

        var title: String {
            switch self {
            case .retention: return "Rétention"
            case .recovery: return "Récupération"
            case .skin: return "Peau"
            case .definition: return "Mâchoire"
            case .stressLoad: return "Charge stress"
            }
        }

        var subtitle: String {
            switch self {
            case .retention: return "Rétention d'eau / debloat"
            case .recovery: return "Sommeil & cernes"
            case .skin: return "Régénération cutanée"
            case .definition: return "Mâchoire et pommettes"
            case .stressLoad: return "Cortisol estimé"
            }
        }

        /// Plus haut = signal défavorable (sauf peau et définition).
        var higherIsWorse: Bool {
            switch self {
            case .retention, .recovery, .stressLoad: return true
            case .skin, .definition: return false
            }
        }

        var whoopLabel: String {
            switch self {
            case .retention: return "RÉTENTION D'EAU"
            case .recovery: return "RÉCUPÉRATION"
            case .skin: return "QUALITÉ DE PEAU (BETA)"
            case .definition: return "MÂCHOIRE ET POMMETTES"
            case .stressLoad: return "CORTISOL ESTIMÉ"
            }
        }

        var systemImage: String {
            switch self {
            case .retention: return "drop.fill"
            case .recovery: return "moon.zzz.fill"
            case .skin: return "sparkles"
            case .definition: return "face.smiling"
            case .stressLoad: return "waveform.path.ecg"
            }
        }
    }

    enum WellnessZone: Int, Hashable {
        case insufficient = 0
        case sufficient = 1
        case optimal = 2

        var title: String {
            switch self {
            case .insufficient: return "Insuffisant"
            case .sufficient: return "Suffisant"
            case .optimal: return "Optimal"
            }
        }
    }

    /// Pourcentage « wellness » affiché à droite (100 = état optimal pour cet indicateur).
    static func wellnessPercent(for kind: Kind, result: FaceScanResult) -> Int {
        let raw = rawValue(for: kind, result: result)
        let normalized = kind.higherIsWorse ? (100 - raw) : raw
        return Int(Swift.max(0, Swift.min(100, Double(normalized))))
    }

    static func wellnessZone(for kind: Kind, result: FaceScanResult) -> WellnessZone {
        wellnessZone(forPercent: wellnessPercent(for: kind, result: result))
    }

    static func wellnessZone(forPercent percent: Int) -> WellnessZone {
        switch percent {
        case 70...: return .optimal
        case 45..<70: return .sufficient
        default: return .insufficient
        }
    }

    static func compositeWellnessZone(for result: FaceScanResult) -> WellnessZone {
        wellnessZone(forPercent: compositeWellnessScore(for: result))
    }

    private static let compositeWeights: [Kind: Double] = [
        .retention: 0.22,
        .recovery: 0.22,
        .stressLoad: 0.20,
        .skin: 0.18,
        .definition: 0.18
    ]

    /// Score global affiché dans l'anneau — aligné sur les % des 5 lignes (pas le score relatif baseline).
    static func compositeWellnessScore(for result: FaceScanResult) -> Int {
        let weighted = Kind.allCases.reduce(0.0) { partial, kind in
            let weight = compositeWeights[kind] ?? (1.0 / Double(Kind.allCases.count))
            return partial + Double(wellnessPercent(for: kind, result: result)) * weight
        }
        return Int(Swift.max(0, Swift.min(100, weighted.rounded())))
    }

    /// Écart vs la moyenne récente des scans (même échelle que le score global).
    static func compositeDeltaVsAverage(for result: FaceScanResult, history: [FaceScanResult]) -> Int? {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -30, to: result.createdAt) ?? result.createdAt
        let prior = history.filter { $0.createdAt >= cutoff && $0.createdAt < result.createdAt && $0.id != result.id }
        guard !prior.isEmpty else { return nil }
        let average = prior.reduce(0) { $0 + compositeWellnessScore(for: $1) } / prior.count
        return compositeWellnessScore(for: result) - average
    }

    struct MeshContext {
        var cheekHollowness: Double
        var jawWidthRatio: Double
    }

    // MARK: - Scores

    static func definitionScore(
        from markers: FaceWellnessMarkers,
        mesh: MeshContext? = nil
    ) -> Int {
        if let stored = markers.faceDefinitionScore {
            return stored
        }
        return computeDefinition(
            puffiness: markers.puffinessScore,
            jawTension: markers.jawTensionScore,
            skinClarity: markers.skinClarityScore,
            mesh: mesh
        )
    }

    static func computeDefinition(
        puffiness: Int,
        jawTension: Int,
        skinClarity: Int,
        mesh: MeshContext?
    ) -> Int {
        let debloat = Double(100 - puffiness) * 0.38

        let structure: Double
        if let meshContext = mesh {
            let cheekTarget = 0.46
            let cheekScore = Swift.max(0.0, 100.0 - abs(meshContext.cheekHollowness - cheekTarget) * 130.0)
            let jawLine = Swift.min(100.0, meshContext.jawWidthRatio * 58.0)
            let relaxedJaw = Double(100 - jawTension) * 0.22
            structure = cheekScore * 0.34 + jawLine * 0.28 + relaxedJaw
        } else {
            let jawProxy = Swift.max(0.0, 72.0 - Double(jawTension) * 0.35)
            let debloatStructure = Double(100 - puffiness) * 0.18
            structure = jawProxy + debloatStructure
        }

        let skinBoost = Double(skinClarity) * 0.14
        let raw = debloat + structure + skinBoost
        return Int(Swift.max(28.0, Swift.min(96.0, raw.rounded())))
    }

    /// Charge stress / cortisol estimé — signaux visage + sommeil/HRV si dispo.
    static func stressLoad(
        from markers: FaceWellnessMarkers,
        sleepHours: Double? = nil,
        hrv: Double? = nil
    ) -> Int {
        var load = Double(markers.puffinessScore) * 0.40
            + Double(markers.underEyeFatigueScore) * 0.42
            + Double(markers.jawTensionScore) * 0.18

        if let sleepHours, sleepHours > 0 {
            if sleepHours < 6 { load += 7 }
            else if sleepHours >= 7.5 { load -= 5 }
        }

        if let hrv, hrv > 0 {
            if hrv < 35 { load += 5 }
            else if hrv >= 55 { load -= 4 }
        }

        return Int(Swift.max(0.0, Swift.min(100.0, load.rounded())))
    }

    static func stressLoad(for result: FaceScanResult) -> Int {
        stressLoad(
            from: result.markers,
            sleepHours: result.sleepHoursAtScan,
            hrv: result.hrvAtScan
        )
    }

    static func rawValue(for kind: Kind, result: FaceScanResult) -> Int {
        switch kind {
        case .retention: return result.markers.puffinessScore
        case .recovery: return result.markers.underEyeFatigueScore
        case .skin: return result.markers.skinClarityScore
        case .definition: return definitionScore(from: result.markers)
        case .stressLoad: return stressLoad(for: result)
        }
    }

    static func rawValue(for kind: Kind, markers: FaceWellnessMarkers, sleepHours: Double? = nil, hrv: Double? = nil) -> Int {
        switch kind {
        case .retention: return markers.puffinessScore
        case .recovery: return markers.underEyeFatigueScore
        case .skin: return markers.skinClarityScore
        case .definition: return definitionScore(from: markers)
        case .stressLoad: return stressLoad(from: markers, sleepHours: sleepHours, hrv: hrv)
        }
    }

    static func delta(
        for kind: Kind,
        current: FaceScanResult,
        baselineMarkers: FaceWellnessMarkers,
        baselineSleep: Double? = nil,
        baselineHRV: Double? = nil
    ) -> Int {
        let currentValue = rawValue(for: kind, result: current)
        let baselineValue = rawValue(
            for: kind,
            markers: baselineMarkers,
            sleepHours: baselineSleep,
            hrv: baselineHRV
        )
        return currentValue - baselineValue
    }

    static func status(for kind: Kind, value: Int) -> String {
        switch kind {
        case .retention:
            switch value {
            case 78...: return "Très marquée"
            case 62..<78: return "Marquée"
            case 50..<62: return "Légère"
            default: return "Faible"
            }
        case .recovery:
            switch value {
            case 78...: return "Très fatigué"
            case 62..<78: return "Fatigué"
            case 52..<62: return "Cernes visibles"
            default: return "Reposé"
            }
        case .skin:
            switch value {
            case 72...: return "Nette"
            case 55..<72: return "Correcte"
            case 42..<55: return "Terne"
            default: return "Très terne"
            }
        case .definition:
            switch value {
            case 74...: return "Bien définie"
            case 58..<74: return "Correcte"
            case 45..<58: return "Peu marquée"
            default: return "Plate / bouffie"
            }
        case .stressLoad:
            switch value {
            case 72...: return "Élevée"
            case 58..<72: return "Modérée"
            case 45..<58: return "Légère"
            default: return "Basse"
            }
        }
    }
}
