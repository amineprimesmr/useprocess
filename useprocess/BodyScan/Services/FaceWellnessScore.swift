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
                headline: AppCopy.tSync("Référence enregistrée", en: "Baseline saved"),
                descriptors: absolute.isEmpty
                    ? [AppCopy.tSync("Premier scan", en: "First scan")]
                    : absolute,
                tone: .good
            )
        }

        let parts = relativeSignals.map { relativeDescriptors(from: $0, markers: markers) }
            ?? absoluteDescriptors(from: markers)

        let tone = tone(for: parts, markers: markers, relativeSignals: relativeSignals)
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

        if signals.puffinessDelta >= 10 { parts.append(AppCopy.tSync("Très gonflé", en: "Very puffy")) }
        else if signals.puffinessDelta >= 5 { parts.append(AppCopy.tSync("Gonflé", en: "Puffy")) }
        else if signals.puffinessDelta <= -6 { parts.append(AppCopy.tSync("Moins gonflé", en: "Less puffy")) }
        else if let d = puffinessDescriptor(markers.puffinessScore) { parts.append(d) }

        if signals.underEyeFatigueDelta >= 10 { parts.append(AppCopy.tSync("Très fatigué", en: "Very tired")) }
        else if signals.underEyeFatigueDelta >= 5 { parts.append(AppCopy.tSync("Fatigué", en: "Tired")) }
        else if signals.underEyeFatigueDelta <= -6 { parts.append(AppCopy.tSync("Cernes en baisse", en: "Under-eyes improving")) }
        else if let d = fatigueDescriptor(markers.underEyeFatigueScore) { parts.append(d) }

        if signals.jawTensionDelta >= 8 { parts.append(AppCopy.tSync("Mâchoire tendue", en: "Jaw tension")) }
        else if let d = jawDescriptor(markers.jawTensionScore) { parts.append(d) }

        if signals.skinClarityDelta <= -8 { parts.append(AppCopy.tSync("Peau terne", en: "Dull skin")) }
        else if signals.skinClarityDelta >= 6 { parts.append(AppCopy.tSync("Peau plus nette", en: "Clearer skin")) }
        else if let d = skinDescriptor(markers.skinClarityScore) { parts.append(d) }

        return dedupe(parts)
    }

    private static func puffinessDescriptor(_ value: Int) -> String? {
        switch value {
        case 78...: return AppCopy.tSync("Très gonflé", en: "Very puffy")
        case 62..<78: return AppCopy.tSync("Nettement gonflé", en: "Clearly puffy")
        case 50..<62: return AppCopy.tSync("Gonflement modéré", en: "Moderate puffiness")
        default: return nil
        }
    }

    private static func fatigueDescriptor(_ value: Int) -> String? {
        switch value {
        case 78...: return AppCopy.tSync("Très fatigué", en: "Very tired")
        case 62..<78: return AppCopy.tSync("Fatigué", en: "Tired")
        case 52..<62: return AppCopy.tSync("Cernes visibles", en: "Visible under-eyes")
        default: return nil
        }
    }

    private static func jawDescriptor(_ value: Int) -> String? {
        switch value {
        case 72...: return AppCopy.tSync("Mâchoire tendue", en: "Jaw tension")
        case 58..<72: return AppCopy.tSync("Tension légère", en: "Mild tension")
        default: return nil
        }
    }

    private static func skinDescriptor(_ value: Int) -> String? {
        switch value {
        case ..<42: return AppCopy.tSync("Peau très terne", en: "Very dull skin")
        case 42..<55: return AppCopy.tSync("Teint terne", en: "Dull complexion")
        case 55..<68: return AppCopy.tSync("Teint correct", en: "Fair complexion")
        default: return nil
        }
    }

    private static func headline(for descriptors: [String], tone: Tone) -> String {
        switch tone {
        case .excellent: return AppCopy.tSync("Visage reposé", en: "Rested face")
        case .good: return descriptors.isEmpty
            ? AppCopy.tSync("État stable", en: "Stable state")
            : AppCopy.tSync("Globalement ok", en: "Looking good overall")
        case .moderate: return AppCopy.tSync("Signaux à surveiller", en: "Signals to watch")
        case .elevated: return AppCopy.tSync("Rétention visible", en: "Visible retention")
        case .stressed: return AppCopy.tSync("Visage en tension", en: "Face under stress")
        }
    }

    private static func tone(
        for descriptors: [String],
        markers: FaceWellnessMarkers,
        relativeSignals: FaceScanRelativeSignals?
    ) -> Tone {
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
            let severeRelative = relativeSignals.map {
                $0.puffinessDelta >= 10 || $0.underEyeFatigueDelta >= 10
            } ?? false
            let severeAbsolute = markers.puffinessScore >= 78 || markers.underEyeFatigueScore >= 78
            return (severeRelative || severeAbsolute) ? .stressed : .elevated
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
                score: 100,
                confidence: confidence,
                baselineSampleCount: 0,
                signals: FaceScanRelativeSignals(
                    puffinessDelta: 0,
                    underEyeFatigueDelta: 0,
                    jawTensionDelta: 0,
                    skinClarityDelta: 0,
                    faceDefinitionDelta: 0,
                    stressLoadDelta: 0,
                    baselineLabel: "Premier scan de référence"
                )
            )
        }

        let puffinessDelta = markers.puffinessScore - baselineMarkers.puffinessScore
        let fatigueDelta = markers.underEyeFatigueScore - baselineMarkers.underEyeFatigueScore
        let jawDelta = markers.jawTensionScore - baselineMarkers.jawTensionScore
        let clarityDelta = markers.skinClarityScore - baselineMarkers.skinClarityScore
        let definitionDelta = FaceScanIndicators.definitionScore(from: markers)
            - FaceScanIndicators.definitionScore(from: baselineMarkers)
        let stressDelta = FaceScanIndicators.stressLoad(from: markers)
            - FaceScanIndicators.stressLoad(from: baselineMarkers)

        let stressShift = Double(puffinessDelta) * 0.40
            + Double(fatigueDelta) * 0.42
            + Double(jawDelta) * 0.12
        let clarityBonus = Double(clarityDelta) * 0.22
        let definitionBonus = Double(definitionDelta) * 0.12
        let wellnessShift = -stressShift + clarityBonus + definitionBonus
        let score = clampedInt(100.0 + wellnessShift, min: 0, max: 100)

        return RelativeAssessment(
            score: score,
            confidence: confidence,
            baselineSampleCount: baseline.sampleCount,
            signals: FaceScanRelativeSignals(
                puffinessDelta: puffinessDelta,
                underEyeFatigueDelta: fatigueDelta,
                jawTensionDelta: jawDelta,
                skinClarityDelta: clarityDelta,
                faceDefinitionDelta: definitionDelta,
                stressLoadDelta: stressDelta,
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

    /// Pour le coach / résumé santé quand seul le score est disponible.
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

    @MainActor
    static func confidenceLabel(for confidence: Int) -> String {
        switch confidence {
        case 82...: return AppCopy.t("Confiance haute", en: "High confidence")
        case 64..<82: return AppCopy.t("Confiance correcte", en: "Fair confidence")
        default: return AppCopy.t("Confiance limitée", en: "Limited confidence")
        }
    }

    private static func personalBaseline(from history: [FaceScanResult]) -> (markers: FaceWellnessMarkers?, sampleCount: Int) {
        let samples = history
            .filter { $0.source == .daily }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(14)

        guard !samples.isEmpty else { return (nil, 0) }
        let count = samples.count

        var weightSum = 0.0
        var puffiness = 0.0
        var fatigue = 0.0
        var jaw = 0.0
        var symmetry = 0.0
        var clarity = 0.0
        var definition = 0.0

        for (index, scan) in samples.enumerated() {
            let weight = pow(0.82, Double(index))
            weightSum += weight
            puffiness += Double(scan.markers.puffinessScore) * weight
            fatigue += Double(scan.markers.underEyeFatigueScore) * weight
            jaw += Double(scan.markers.jawTensionScore) * weight
            symmetry += Double(scan.markers.facialSymmetryScore) * weight
            clarity += Double(scan.markers.skinClarityScore) * weight
            definition += Double(FaceScanIndicators.definitionScore(from: scan.markers)) * weight
        }

        guard weightSum > 0 else { return (nil, 0) }

        return (
            FaceWellnessMarkers(
                puffinessScore: Int((puffiness / weightSum).rounded()),
                underEyeFatigueScore: Int((fatigue / weightSum).rounded()),
                jawTensionScore: Int((jaw / weightSum).rounded()),
                facialSymmetryScore: Int((symmetry / weightSum).rounded()),
                skinClarityScore: Int((clarity / weightSum).rounded()),
                faceDefinitionScore: Int((definition / weightSum).rounded()),
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
        return clampedInt(Double(score), min: 0, max: 100)
    }

    /// Recalcule les scores stockés (échelle 0–100, plus haut = mieux).
    static func reconcileStoredScores(_ history: [FaceScanResult]) -> [FaceScanResult] {
        let chronological = history.sorted { $0.createdAt < $1.createdAt }
        var priorDaily: [FaceScanResult] = []

        let reconciled = chronological.map { scan -> FaceScanResult in
            guard scan.source == .daily else { return scan }

            let assessment = relativeAssessment(
                current: scan.markers,
                history: priorDaily,
                yawCoverage: estimatedYawCoverage(from: scan)
            )
            var updated = scan
            updated.faceDayScore = dayScore(from: scan.markers)
            updated.relativeFaceDayScore = assessment.score
            updated.scanConfidence = assessment.confidence
            updated.baselineSampleCount = assessment.baselineSampleCount
            updated.relativeSignals = assessment.signals
            priorDaily.append(updated)
            return updated
        }

        return reconciled.sorted { $0.createdAt > $1.createdAt }
    }

    private static func estimatedYawCoverage(from scan: FaceScanResult) -> Double {
        for note in scan.markers.notes {
            if let percent = note.split(separator: " ").compactMap({ Int($0) }).first,
               note.contains("%") {
                return min(1, max(0, Double(percent) / 100))
            }
        }
        return 0.72
    }

    private static func average(_ values: [Int]) -> Int {
        guard !values.isEmpty else { return 0 }
        return Int((Double(values.reduce(0, +)) / Double(values.count)).rounded())
    }

    private static func clampedInt(_ value: Double, min: Int, max: Int) -> Int {
        Int(Swift.min(Double(max), Swift.max(Double(min), value)).rounded())
    }
}
