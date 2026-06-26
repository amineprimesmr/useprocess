import Foundation

/// Score « visage du jour » (0–100) — plus haut = meilleur état perçu.
enum FaceWellnessScore {
    struct RelativeAssessment: Hashable {
        let score: Int
        let confidence: Int
        let baselineSampleCount: Int
        let signals: FaceScanRelativeSignals?
    }

    enum Tone: Hashable {
        case excellent
        case good
        case moderate
        case elevated
        case stressed
    }

    /// Appréciation globale lisible — remplace le score % dans l’UI scan.
    struct Appreciation: Hashable {
        let headline: String
        let descriptors: [String]
        let tone: Tone

        var displayText: String {
            if descriptors.isEmpty { return headline }
            if descriptors.count == 1 { return descriptors[0] }
            return descriptors.joined(separator: " · ")
        }
    }

    static func appreciation(for result: FaceScanResult) -> Appreciation {
        appreciation(
            markers: result.markers,
            relativeSignals: result.relativeSignals,
            isBaselineScan: result.relativeSignals?.baselineLabel == "Premier scan de référence"
        )
    }

    static func appreciation(
        markers: FaceWellnessMarkers,
        relativeSignals: FaceScanRelativeSignals?,
        isBaselineScan: Bool = false
    ) -> Appreciation {
        if isBaselineScan {
            let absolute = absoluteDescriptors(from: markers)
            return Appreciation(
                headline: "Référence enregistrée",
                descriptors: absolute.isEmpty ? ["Premier scan"] : absolute,
                tone: .good
            )
        }

        let parts = relativeSignals.map { relativeDescriptors(from: $0, markers: markers) }
            ?? absoluteDescriptors(from: markers)

        let tone = tone(for: parts, markers: markers)
        let headline = headline(for: parts, tone: tone)

        return Appreciation(
            headline: headline,
            descriptors: parts,
            tone: tone
        )
    }

    // MARK: - Descripteurs

    private static func absoluteDescriptors(from markers: FaceWellnessMarkers) -> [String] {
        var parts: [String] = []
        if let d = puffinessDescriptor(markers.puffinessScore) { parts.append(d) }
        if let d = fatigueDescriptor(markers.underEyeFatigueScore) { parts.append(d) }
        if let d = jawDescriptor(markers.jawTensionScore) { parts.append(d) }
        if let d = skinDescriptor(markers.skinClarityScore) { parts.append(d) }
        return parts
    }

    private static func relativeDescriptors(
        from signals: FaceScanRelativeSignals,
        markers: FaceWellnessMarkers
    ) -> [String] {
        var parts: [String] = []

        if signals.puffinessDelta >= 10 { parts.append("Très gonflé") }
        else if signals.puffinessDelta >= 5 { parts.append("Gonflé") }
        else if signals.puffinessDelta <= -6 { parts.append("Moins gonflé") }
        else if let d = puffinessDescriptor(markers.puffinessScore) { parts.append(d) }

        if signals.underEyeFatigueDelta >= 10 { parts.append("Très fatigué") }
        else if signals.underEyeFatigueDelta >= 5 { parts.append("Fatigué") }
        else if signals.underEyeFatigueDelta <= -6 { parts.append("Cernes en baisse") }
        else if let d = fatigueDescriptor(markers.underEyeFatigueScore) { parts.append(d) }

        if signals.jawTensionDelta >= 8 { parts.append("Mâchoire tendue") }
        else if let d = jawDescriptor(markers.jawTensionScore) { parts.append(d) }

        if signals.skinClarityDelta <= -8 { parts.append("Peau terne") }
        else if signals.skinClarityDelta >= 6 { parts.append("Peau plus nette") }
        else if let d = skinDescriptor(markers.skinClarityScore) { parts.append(d) }

        return dedupe(parts)
    }

    private static func puffinessDescriptor(_ value: Int) -> String? {
        switch value {
        case 78...: return "Très gonflé"
        case 62..<78: return "Gonflé"
        case 50..<62: return "Léger gonflement"
        default: return nil
        }
    }

    private static func fatigueDescriptor(_ value: Int) -> String? {
        switch value {
        case 78...: return "Très fatigué"
        case 62..<78: return "Fatigué"
        case 52..<62: return "Cernes visibles"
        default: return nil
        }
    }

    private static func jawDescriptor(_ value: Int) -> String? {
        switch value {
        case 72...: return "Mâchoire tendue"
        case 58..<72: return "Tension légère"
        default: return nil
        }
    }

    private static func skinDescriptor(_ value: Int) -> String? {
        switch value {
        case ..<42: return "Peau très terne"
        case 42..<55: return "Teint terne"
        case 55..<68: return "Teint correct"
        default: return nil
        }
    }

    private static func headline(for descriptors: [String], tone: Tone) -> String {
        switch tone {
        case .excellent: return "Visage reposé"
        case .good: return descriptors.isEmpty ? "État stable" : "Globalement ok"
        case .moderate: return "Signaux à surveiller"
        case .elevated: return "Rétention visible"
        case .stressed: return "Visage en tension"
        }
    }

    private static func tone(for descriptors: [String], markers: FaceWellnessMarkers) -> Tone {
        let stressLoad = Double(markers.puffinessScore) * 0.45
            + Double(markers.underEyeFatigueScore) * 0.55
            + Double(markers.jawTensionScore) * 0.08

        if descriptors.isEmpty && stressLoad < 42 && markers.skinClarityScore >= 68 {
            return .excellent
        }
        if descriptors.count <= 1 && stressLoad < 52 {
            return .good
        }
        if descriptors.count >= 2 || stressLoad >= 62 {
            return descriptors.contains(where: { $0.contains("Très") }) ? .stressed : .elevated
        }
        return .moderate
    }

    private static func dedupe(_ parts: [String]) -> [String] {
        var seen = Set<String>()
        return parts.filter { part in
            guard !seen.contains(part) else { return false }
            seen.insert(part)
            return true
        }
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
        appreciation(forScore: score).displayText
    }

    static func appreciation(forScore score: Int) -> Appreciation {
        appreciation(markers: syntheticMarkers(forScore: score), relativeSignals: nil)
    }

    /// Pour readiness / coach quand seul le score est disponible.
    private static func syntheticMarkers(forScore score: Int) -> FaceWellnessMarkers {
        let stress = max(0, min(100, 100 - score))
        return FaceWellnessMarkers(
            puffinessScore: stress,
            underEyeFatigueScore: stress,
            jawTensionScore: max(35, stress - 8),
            facialSymmetryScore: 72,
            skinClarityScore: min(88, score + 6),
            notes: []
        )
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
