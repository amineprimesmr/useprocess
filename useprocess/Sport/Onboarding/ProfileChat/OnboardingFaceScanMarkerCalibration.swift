import Foundation

/// Calibre le premier scan onboarding pour sortir des scores « tous au milieu »
/// et afficher au moins 3 indicateurs en zone Médiocre (potentiel Debloat).
enum OnboardingFaceScanMarkerCalibration {

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
                adjusted.faceDefinitionScore = min(
                    adjusted.faceDefinitionScore ?? FaceScanIndicators.definitionScore(from: adjusted),
                    36
                )
            case .skin:
                adjusted.skinClarityScore = min(adjusted.skinClarityScore, 36)
            }

            refreshDefinition(on: &adjusted)
        }

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

    /// Signaux coincés en bande « Dégradé » (48–77) → Médiocre (78+), en gardant un écart relatif.
    /// Premier scan onboarding : un signal déjà « optimal » est quand même remonté pour éviter le tout-au-milieu.
    private static func pushAdverseIntoMediocre(_ raw: Int) -> Int {
        if raw >= 78 { return min(raw, 94) }
        if raw < 48 { return 80 }

        let position = Double(raw - 48) / 30.0
        return 78 + Int((position * 10).rounded())
    }

    private static func refreshDefinition(on markers: inout FaceWellnessMarkers) {
        markers.faceDefinitionScore = FaceScanIndicators.definitionScore(from: markers)
    }
}
