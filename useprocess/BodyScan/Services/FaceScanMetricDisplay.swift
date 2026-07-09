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
        let delta: Int?
        let arrowSystemName: String
        let value: Int

        var deltaLabel: String {
            guard let delta else { return "—" }
            if delta == 0 { return "0" }
            return delta > 0 ? "+\(delta)" : "\(delta)"
        }
    }

    static func items(for result: FaceScanResult, previous: FaceScanResult? = nil) -> [Item] {
        let trend = previous.map { result.delta(from: $0) }

        return FaceScanIndicators.Kind.allCases.map { kind in
            item(for: kind, result: result, trend: trend, previous: previous)
        }
    }

    static func item(for kind: FaceScanIndicators.Kind, result: FaceScanResult, previous: FaceScanResult? = nil) -> Item {
        let trend = previous.map { result.delta(from: $0) }
        return item(for: kind, result: result, trend: trend, previous: previous)
    }

    static func keyItems(for result: FaceScanResult, previous: FaceScanResult? = nil, limit: Int = 3) -> [Item] {
        let items = items(for: result, previous: previous)
        let changed = items
            .filter { item in
                guard let delta = item.delta else { return false }
                return abs(delta) >= 4
            }
            .sorted { lhs, rhs in
                abs(lhs.delta ?? 0) > abs(rhs.delta ?? 0)
            }

        if !changed.isEmpty {
            return Array(changed.prefix(limit))
        }

        return Array(items.prefix(limit))
    }

    @MainActor
    static func evolutionSentence(
        for result: FaceScanResult,
        previous: FaceScanResult? = nil,
        history: [FaceScanResult] = [],
        context: FaceScanInsightContext? = nil
    ) -> String {
        if !history.isEmpty || context != nil {
            return FaceScanEvolutionEngine.evolutionSentence(
                for: result,
                previous: previous,
                history: history,
                context: context
            )
        }
        return legacyEvolutionSentence(for: result, previous: previous)
    }

    @MainActor
    static func actionSentence(
        for result: FaceScanResult,
        previous: FaceScanResult? = nil,
        history: [FaceScanResult] = [],
        waterLiters: Double? = nil,
        hydrationTargetLiters: Double? = nil
    ) -> String {
        var context = FaceScanInsightContext.fromTodayHealth()
        if let waterLiters { context.waterLiters = waterLiters }
        if let hydrationTargetLiters { context.hydrationTargetLiters = hydrationTargetLiters }

        if !history.isEmpty || waterLiters != nil {
            return FaceScanEvolutionEngine.actionSentence(
                for: result,
                previous: previous,
                history: history,
                context: context
            )
        }
        return legacyActionSentence(for: result, previous: previous, context: context)
    }

    private static func legacyEvolutionSentence(for result: FaceScanResult, previous: FaceScanResult?) -> String {
        let key = keyItems(for: result, previous: previous, limit: 2)
        let changedKey = key.filter { item in
            guard let delta = item.delta else { return false }
            return abs(delta) >= 4
        }
        let retention = item(for: .retention, result: result, previous: previous)
        let retentionLoad = FaceScanIndicators.displayPercent(for: .retention, result: result)

        if result.relativeSignals?.baselineLabel == "Premier scan de référence" {
            return "Premier scan de référence : les prochains scans montreront ce qui monte ou descend."
        }

        if retentionLoad >= 62 {
            if let delta = retention.delta, delta >= 4 {
                return "Tu as encore de la rétention d'eau visible (\(retentionLoad) %) et elle monte vs ta moyenne récente."
            }
            if let delta = retention.delta, delta <= -6 {
                return "La rétention descend (\(retention.deltaLabel)) mais reste encore visible à \(retentionLoad) %."
            }
            return "Tu as encore de la rétention d'eau visible (\(retentionLoad) %) : surveille eau, sodium et potassium alimentaire."
        }

        if let delta = retention.delta, delta <= -6 {
            return "La rétention descend (\(retention.deltaLabel)) : visage moins gonflé que ta référence récente."
        }

        guard !changedKey.isEmpty else {
            return "Évolution stable : continue de comparer tes scans dans les mêmes conditions."
        }

        return changedKey.map { "\($0.title.lowercased()) \($0.deltaLabel)" }.joined(separator: ", ") + " vs référence récente."
    }

    private static func legacyActionSentence(
        for result: FaceScanResult,
        previous: FaceScanResult?,
        context: FaceScanInsightContext
    ) -> String {
        let retention = item(for: .retention, result: result, previous: previous)
        let recovery = item(for: .recovery, result: result, previous: previous)
        let stress = item(for: .stressLoad, result: result, previous: previous)
        let retentionLoad = FaceScanIndicators.displayPercent(for: .retention, result: result)

        let hydrationLow: Bool = {
            guard let waterLiters = context.waterLiters,
                  let hydrationTargetLiters = context.hydrationTargetLiters,
                  hydrationTargetLiters > 0 else { return false }
            return waterLiters < hydrationTargetLiters * 0.60
        }()

        if retentionLoad >= 62 || (retention.delta ?? 0) >= 6 {
            if hydrationLow {
                return "Priorité aujourd'hui : hydratation régulière, sel modéré, aliments riches en potassium au repas."
            }
            return "Priorité aujourd'hui : limiter sodium/processés, garder l'eau régulière, ajouter potassium alimentaire."
        }

        if (recovery.delta ?? 0) >= 6 || (stress.delta ?? 0) >= 6 {
            return "Priorité aujourd'hui : sommeil plus tôt, respiration nasale, pas d'effort intense tardif."
        }

        return "Priorité aujourd'hui : garder l'hydratation et refaire le scan dans les mêmes conditions."
    }

    private static func item(
        for kind: FaceScanIndicators.Kind,
        result: FaceScanResult,
        trend: FaceScanTrend?,
        previous: FaceScanResult?
    ) -> Item {
        let raw = FaceScanIndicators.rawValue(for: kind, result: result)
        let delta = relativeDelta(
            for: kind,
            result: result,
            trend: trend,
            previous: previous
        )
        let isFirstScan = result.relativeSignals?.baselineLabel == "Premier scan de référence"
        let usesBaseline = result.relativeSignals != nil && !isFirstScan
        let (comparison, kind_, arrow) = comparisonPhrase(
            delta: delta,
            higherIsWorse: kind.higherIsWorse,
            previous: previous,
            usesBaseline: usesBaseline,
            isFirstScan: isFirstScan
        )
        return Item(
            id: kind.rawValue,
            title: kind.title,
            subtitle: kind.subtitle,
            status: FaceScanIndicators.status(for: kind, value: raw),
            comparison: comparison,
            comparisonKind: kind_,
            delta: delta,
            arrowSystemName: arrow,
            value: raw
        )
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
        previous: FaceScanResult?,
        usesBaseline: Bool,
        isFirstScan: Bool
    ) -> (String, ComparisonKind, String) {
        if isFirstScan {
            return ("Premier scan", .reference, "flag.fill")
        }

        guard let delta else {
            return (usesBaseline ? "Référence en cours" : "Premier scan", .reference, "flag.fill")
        }

        let signed = delta > 0 ? "+\(delta)" : "\(delta)"
        let suffix = comparisonSuffix(usesBaseline: usesBaseline, previous: previous)

        guard abs(delta) >= 4 else {
            return ("Stable", .stable, "arrow.right")
        }

        if higherIsWorse {
            if delta <= -4 {
                return ("↓ \(signed) \(suffix)", .better, "arrow.down")
            }
            return ("↑ \(signed) \(suffix)", .worse, "arrow.up")
        }

        if delta >= 4 {
            return ("↑ \(signed) \(suffix)", .better, "arrow.up")
        }
        return ("↓ \(signed) \(suffix)", .worse, "arrow.down")
    }

    private static func comparisonSuffix(usesBaseline: Bool, previous: FaceScanResult?) -> String {
        if usesBaseline { return "vs moyenne" }
        guard let previous else { return "vs référence" }

        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: previous.createdAt),
            to: Calendar.current.startOfDay(for: Date())
        ).day ?? 0

        switch days {
        case 0: return "vs aujourd'hui"
        case 1: return "vs hier"
        default: return "vs il y a \(days) j"
        }
    }
}
