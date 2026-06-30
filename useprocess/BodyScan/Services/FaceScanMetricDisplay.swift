import Foundation

/// Libellés lisibles pour les 5 indicateurs du scan visage.
enum FaceScanMetricDisplay {

    enum ComparisonKind: Hashable {
        case better
        case worse
        case stable
        case reference
    }

    struct Item: Identifiable, Hashable {
        let id: String
        let title: String
        let subtitle: String
        let status: String
        let comparison: String
        let comparisonKind: ComparisonKind
    }

    static func items(for result: FaceScanResult, previous: FaceScanResult? = nil) -> [Item] {
        let markers = result.markers
        let trend = previous.map { result.delta(from: $0) }

        return FaceScanIndicators.Kind.allCases.map { kind in
            let raw = FaceScanIndicators.rawValue(for: kind, result: result)
            let delta = relativeDelta(
                for: kind,
                result: result,
                trend: trend,
                previous: previous
            )
            let isFirstScan = result.relativeSignals?.baselineLabel == "Premier scan de référence"
            let (comparison, kind_) = comparisonPhrase(
                delta: delta,
                higherIsWorse: kind.higherIsWorse,
                vsPrevious: previous != nil && result.relativeSignals == nil,
                isFirstScan: isFirstScan
            )
            return Item(
                id: kind.rawValue,
                title: kind.title,
                subtitle: kind.subtitle,
                status: FaceScanIndicators.status(for: kind, value: raw),
                comparison: comparison,
                comparisonKind: kind_
            )
        }
    }

    private static func relativeDelta(
        for kind: FaceScanIndicators.Kind,
        result: FaceScanResult,
        trend: FaceScanTrend?,
        previous: FaceScanResult?
    ) -> Int? {
        if let signals = result.relativeSignals,
           signals.baselineLabel != "Premier scan de référence" {
            switch kind {
            case .retention: return signals.puffinessDelta
            case .recovery: return signals.underEyeFatigueDelta
            case .skin: return signals.skinClarityDelta
            case .definition: return signals.faceDefinitionDelta
            case .stressLoad: return signals.stressLoadDelta
            }
        }

        guard let previous else { return nil }

        switch kind {
        case .retention: return trend?.puffiness
        case .recovery: return trend?.underEyeFatigue
        case .skin: return trend?.skinClarity
        case .definition:
            return FaceScanIndicators.definitionScore(from: result.markers)
                - FaceScanIndicators.definitionScore(from: previous.markers)
        case .stressLoad:
            return FaceScanIndicators.stressLoad(for: result)
                - FaceScanIndicators.stressLoad(for: previous)
        }
    }

    private static func comparisonPhrase(
        delta: Int?,
        higherIsWorse: Bool,
        vsPrevious: Bool,
        isFirstScan: Bool
    ) -> (String, ComparisonKind) {
        if isFirstScan {
            return ("Premier scan", .reference)
        }

        guard let delta else {
            return (vsPrevious ? "Premier scan" : "Référence en cours", .reference)
        }

        guard abs(delta) >= 4 else {
            return ("Stable", .stable)
        }

        if higherIsWorse {
            if delta <= -4 {
                return (vsPrevious ? "Mieux que hier" : "Mieux que ta moyenne", .better)
            }
            return (vsPrevious ? "Plus marqué qu'hier" : "Au-dessus de ta moyenne", .worse)
        }

        if delta >= 4 {
            return (vsPrevious ? "Mieux qu'hier" : "Mieux que ta moyenne", .better)
        }
        return (vsPrevious ? "En baisse vs hier" : "En baisse vs ta moyenne", .worse)
    }
}
