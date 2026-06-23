import Foundation

/// Score « visage du jour » (0–100) — plus haut = meilleur état perçu.
enum FaceWellnessScore {
    struct RelativeAssessment: Hashable {
        let score: Int
        let confidence: Int
        let baselineSampleCount: Int
        let signals: FaceScanRelativeSignals?
    }

    static func dayScore(from markers: FaceWellnessMarkers) -> Int {
        let stressLoad = Double(markers.puffinessScore) * 0.45
            + Double(markers.underEyeFatigueScore) * 0.55
        let jawPenalty = Double(markers.jawTensionScore) * 0.12
        let raw = stressLoad + jawPenalty
        return Int(max(0, min(100, (100 - raw).rounded())))
    }

    /// Score V2 : mesure l'état du jour par rapport à la baseline personnelle.
    /// Le premier scan sert de référence et n'est jamais une condamnation morphologique.
    static func relativeAssessment(
        current markers: FaceWellnessMarkers,
        history: [FaceScanResult],
        yawCoverage: Double
    ) -> RelativeAssessment {
        let baseline = personalBaseline(from: history)
        let confidence = confidenceScore(
            current: markers,
            baselineSampleCount: baseline.sampleCount,
            yawCoverage: yawCoverage
        )

        guard let baselineMarkers = baseline.markers else {
            return RelativeAssessment(
                score: baselineReferenceScore(confidence: confidence),
                confidence: confidence,
                baselineSampleCount: 0,
                signals: FaceScanRelativeSignals(
                    puffinessDelta: 0,
                    underEyeFatigueDelta: 0,
                    jawTensionDelta: 0,
                    skinClarityDelta: 0,
                    baselineLabel: "Premier scan de référence"
                )
            )
        }

        let puffinessDelta = markers.puffinessScore - baselineMarkers.puffinessScore
        let fatigueDelta = markers.underEyeFatigueScore - baselineMarkers.underEyeFatigueScore
        let jawDelta = markers.jawTensionScore - baselineMarkers.jawTensionScore
        let clarityDelta = markers.skinClarityScore - baselineMarkers.skinClarityScore

        let stressDelta = Double(puffinessDelta) * 0.42
            + Double(fatigueDelta) * 0.46
            + Double(jawDelta) * 0.10
            - Double(clarityDelta) * 0.20
        let confidencePenalty = Double(max(0, 70 - confidence)) * 0.12
        let score = clampedInt(82 - stressDelta - confidencePenalty, min: 35, max: 96)

        return RelativeAssessment(
            score: score,
            confidence: confidence,
            baselineSampleCount: baseline.sampleCount,
            signals: FaceScanRelativeSignals(
                puffinessDelta: puffinessDelta,
                underEyeFatigueDelta: fatigueDelta,
                jawTensionDelta: jawDelta,
                skinClarityDelta: clarityDelta,
                baselineLabel: baseline.sampleCount >= 4
                    ? "Comparé à ta moyenne récente"
                    : "Comparé à tes premiers scans"
            )
        )
    }

    static func label(for score: Int) -> String {
        switch score {
        case 80...: return "Visage reposé"
        case 60..<80: return "Visage correct"
        case 40..<60: return "Fatigue visible"
        default: return "Récupération visuelle faible"
        }
    }

    static func confidenceLabel(for confidence: Int) -> String {
        switch confidence {
        case 82...: return "Confiance haute"
        case 64..<82: return "Confiance correcte"
        default: return "Confiance limitée"
        }
    }

    private static func personalBaseline(from history: [FaceScanResult]) -> (markers: FaceWellnessMarkers?, sampleCount: Int) {
        let samples = history
            .filter { $0.source == .daily }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(8)

        guard !samples.isEmpty else { return (nil, 0) }
        let count = samples.count
        let puffiness = average(samples.map(\.markers.puffinessScore))
        let fatigue = average(samples.map(\.markers.underEyeFatigueScore))
        let jaw = average(samples.map(\.markers.jawTensionScore))
        let symmetry = average(samples.map(\.markers.facialSymmetryScore))
        let clarity = average(samples.map(\.markers.skinClarityScore))

        return (
            FaceWellnessMarkers(
                puffinessScore: puffiness,
                underEyeFatigueScore: fatigue,
                jawTensionScore: jaw,
                facialSymmetryScore: symmetry,
                skinClarityScore: clarity,
                notes: []
            ),
            count
        )
    }

    private static func confidenceScore(
        current markers: FaceWellnessMarkers,
        baselineSampleCount: Int,
        yawCoverage: Double
    ) -> Int {
        var score = 48
        score += min(24, Int((yawCoverage * 24).rounded()))
        score += min(18, baselineSampleCount * 4)
        score += markers.skinClarityScore >= 62 ? 10 : max(0, (markers.skinClarityScore - 40) / 3)
        return clampedInt(Double(score), min: 35, max: 96)
    }

    private static func baselineReferenceScore(confidence: Int) -> Int {
        clampedInt(76 + Double(confidence - 70) * 0.08, min: 70, max: 82)
    }

    private static func average(_ values: [Int]) -> Int {
        guard !values.isEmpty else { return 0 }
        return Int((Double(values.reduce(0, +)) / Double(values.count)).rounded())
    }

    private static func clampedInt(_ value: Double, min: Int, max: Int) -> Int {
        Int(Swift.min(Double(max), Swift.max(Double(min), value)).rounded())
    }
}
