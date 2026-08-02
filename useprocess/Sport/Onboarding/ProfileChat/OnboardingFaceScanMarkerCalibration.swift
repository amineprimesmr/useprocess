import Foundation

/// Calibre le premier scan onboarding pour sortir des scores « tous au milieu »,
/// afficher au moins 3 indicateurs en zone Médiocre, et plafonner le score global à 40 %.
enum OnboardingFaceScanMarkerCalibration {

    /// Score global affiché (anneau) — jamais au-dessus pour le premier scan onboarding.
    static let maxCompositeWellnessScore = 40

    static func calibrate(
        _ markers: FaceWellnessMarkers,
        sleepHours: Double? = nil,
        hrv: Double? = nil
    ) -> FaceWellnessMarkers {
        var adjusted = markers
        refreshDefinition(on: &adjusted)

        let priority: [FaceScanIndicators.Kind] = [
            .retention,
            .recovery,
            .stressLoad,
            .definition,
            .skin
        ]

        for kind in priority {
            guard mediocreCount(in: adjusted, sleepHours: sleepHours, hrv: hrv) < 3 else { break }
            guard displayZone(for: kind, markers: adjusted, sleepHours: sleepHours, hrv: hrv) != .insufficient else {
                continue
            }

            switch kind {
            case .retention:
                adjusted.puffinessScore = pushAdverseIntoMediocre(adjusted.puffinessScore)
            case .recovery:
                adjusted.underEyeFatigueScore = pushAdverseIntoMediocre(adjusted.underEyeFatigueScore)
            case .stressLoad:
                adjusted.puffinessScore = max(adjusted.puffinessScore, 82)
                adjusted.underEyeFatigueScore = max(adjusted.underEyeFatigueScore, 82)
                adjusted.jawTensionScore = max(adjusted.jawTensionScore, 68)
            case .definition:
                refreshDefinition(on: &adjusted)
                adjusted.faceDefinitionScore = min(adjusted.faceDefinitionScore ?? 36, 36)
                continue
            case .skin:
                adjusted.skinClarityScore = min(adjusted.skinClarityScore, 36)
            }

            refreshDefinition(on: &adjusted)
            if kind == .skin {
                adjusted.faceDefinitionScore = min(adjusted.faceDefinitionScore ?? 36, 36)
            }
        }

        enforceMaxCompositeScore(on: &adjusted, sleepHours: sleepHours, hrv: hrv)
        return adjusted
    }

    // MARK: - Private

    private static func mediocreCount(
        in markers: FaceWellnessMarkers,
        sleepHours: Double?,
        hrv: Double?
    ) -> Int {
        FaceScanIndicators.Kind.allCases.filter {
            displayZone(for: $0, markers: markers, sleepHours: sleepHours, hrv: hrv) == .insufficient
        }.count
    }

    private static func displayZone(
        for kind: FaceScanIndicators.Kind,
        markers: FaceWellnessMarkers,
        sleepHours: Double?,
        hrv: Double?
    ) -> FaceScanIndicators.WellnessZone {
        let provisional = FaceScanResult(
            id: "onboarding-calibration",
            userId: "local",
            markers: markers,
            sleepHoursAtScan: sleepHours,
            hrvAtScan: hrv
        )
        return FaceScanIndicators.displayZone(for: kind, result: provisional)
    }

    private static func compositeScore(
        for markers: FaceWellnessMarkers,
        sleepHours: Double?,
        hrv: Double?
    ) -> Int {
        let provisional = FaceScanResult(
            id: "onboarding-calibration",
            userId: "local",
            markers: markers,
            sleepHoursAtScan: sleepHours,
            hrvAtScan: hrv
        )
        return FaceScanIndicators.compositeWellnessScore(for: provisional)
    }

    /// Pousse les signaux jusqu’à ce que le score global ≤ 40 %.
    private static func enforceMaxCompositeScore(
        on markers: inout FaceWellnessMarkers,
        sleepHours: Double?,
        hrv: Double?
    ) {
        for _ in 0..<12 {
            guard compositeScore(for: markers, sleepHours: sleepHours, hrv: hrv) > maxCompositeWellnessScore else {
                return
            }

            markers.puffinessScore = min(94, markers.puffinessScore + 4)
            markers.underEyeFatigueScore = min(94, markers.underEyeFatigueScore + 4)
            markers.jawTensionScore = min(88, markers.jawTensionScore + 3)
            markers.skinClarityScore = max(28, markers.skinClarityScore - 4)
            refreshDefinition(on: &markers)
            markers.faceDefinitionScore = max(28, (markers.faceDefinitionScore ?? 36) - 4)
        }

        // Dernier filet si encore au-dessus (cas extrême).
        while compositeScore(for: markers, sleepHours: sleepHours, hrv: hrv) > maxCompositeWellnessScore {
            markers.puffinessScore = min(94, markers.puffinessScore + 2)
            markers.underEyeFatigueScore = min(94, markers.underEyeFatigueScore + 2)
            markers.skinClarityScore = max(28, markers.skinClarityScore - 2)
            refreshDefinition(on: &markers)
            markers.faceDefinitionScore = max(28, (markers.faceDefinitionScore ?? 36) - 2)

            if markers.puffinessScore >= 94,
               markers.underEyeFatigueScore >= 94,
               markers.skinClarityScore <= 28,
               (markers.faceDefinitionScore ?? 28) <= 28 {
                break
            }
        }
    }

    /// Signaux coincés en bande « Dégradé » (48–77) → Médiocre (78+), en gardant un écart relatif.
    /// Premier scan onboarding : un signal déjà « optimal » est quand même remonté pour éviter le tout-au-milieu.
    private static func pushAdverseIntoMediocre(_ raw: Int) -> Int {
        if raw >= 78 { return min(raw, 94) }
        if raw < 48 { return 80 }

        let position = Double(raw - 48) / 30.0
        return 78 + Int((position * 10).rounded())
    }

    private static func refreshDefinition(on markers: inout FaceWellnessMarkers) {
        markers.faceDefinitionScore = FaceScanIndicators.computeDefinition(
            puffiness: markers.puffinessScore,
            jawTension: markers.jawTensionScore,
            skinClarity: markers.skinClarityScore,
            mesh: nil
        )
    }
}
