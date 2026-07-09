import Foundation

// MARK: - Faits nutrition

struct FaceScanNutritionFacts: Equatable {
    var estimatedSodiumMg: Double?
    var estimatedPotassiumMg: Double?
    var electrolyteScore: Int?
    var mealCount: Int = 0
    var summaryLine: String?
    var isHighSodium: Bool = false
    var isLowPotassium: Bool = false
    var isPoorElectrolyteBalance: Bool = false

    static let empty = FaceScanNutritionFacts()
}

// MARK: - Tendance indicateur

struct FaceScanIndicatorTrend: Equatable {
    enum Direction: Equatable {
        case rising
        case falling
        case stable
        case plateau
    }

    let kind: FaceScanIndicators.Kind
    let direction: Direction
    let spanDays: Int
    let pointDelta: Int

    var label: String {
        let name = kind.title.lowercased()
        switch direction {
        case .rising:
            return "\(name) en hausse sur \(spanDays) j (\(signed(pointDelta)))"
        case .falling:
            return "\(name) en baisse sur \(spanDays) j (\(signed(pointDelta)))"
        case .plateau:
            return "\(name) stable depuis \(spanDays) scans"
        case .stable:
            return "\(name) peu variable sur \(spanDays) j"
        }
    }

    private func signed(_ value: Int) -> String {
        value >= 0 ? "+\(value)" : "\(value)"
    }
}

// MARK: - Faits évolution unifiés

struct FaceScanEvolutionFacts: Equatable {
    let scanId: String
    var nutritionYesterday: FaceScanNutritionFacts = .empty
    var correlations: [FaceScanCorrelationInsight] = []
    var retentionTrend: FaceScanIndicatorTrend?
    var recoveryTrend: FaceScanIndicatorTrend?
    var monthWellnessDelta: Int?
    var retentionPersistingScans: Int = 0
    var recentSuggestedActions: [String] = []
    var trajectoryStreak: Int?
    var trajectoryTrendLabel: String?
}

// MARK: - Moteur

enum FaceScanEvolutionEngine {

    @MainActor
    static func build(
        for result: FaceScanResult,
        history: [FaceScanResult],
        context: FaceScanInsightContext? = nil
    ) -> FaceScanEvolutionFacts {
        let resolvedContext = context ?? FaceScanInsightContext.fromTodayHealth()
        let dailyHistory = history.filter { $0.source == .daily }
        let trajectory = ProcessDebloatTrajectoryStore.shared.snapshot

        return FaceScanEvolutionFacts(
            scanId: result.id,
            nutritionYesterday: nutritionFacts(dayOffset: 1),
            correlations: Array(FaceScanCorrelationEngine.insights(from: dailyHistory).prefix(2)),
            retentionTrend: indicatorTrend(for: .retention, history: dailyHistory),
            recoveryTrend: indicatorTrend(for: .recovery, history: dailyHistory),
            monthWellnessDelta: FaceScanIndicators.compositeDeltaVsAverage(for: result, history: dailyHistory),
            retentionPersistingScans: retentionPersistenceCount(for: result, history: dailyHistory),
            recentSuggestedActions: recentActions(from: dailyHistory, excluding: result.id),
            trajectoryStreak: trajectory.currentStreak > 0 ? trajectory.currentStreak : nil,
            trajectoryTrendLabel: trajectory.velocityLabel.isEmpty ? nil : trajectory.velocityLabel
        )
    }

    @MainActor
    static func evolutionSentence(
        for result: FaceScanResult,
        previous: FaceScanResult? = nil,
        history: [FaceScanResult] = [],
        context: FaceScanInsightContext? = nil
    ) -> String {
        let resolvedContext = context ?? FaceScanInsightContext.fromTodayHealth()
        let facts = build(for: result, history: history, context: resolvedContext)

        let retention = FaceScanMetricDisplay.item(for: .retention, result: result, previous: previous)
        let retentionLoad = FaceScanIndicators.displayPercent(for: .retention, result: result)

        if result.relativeSignals?.baselineLabel == "Premier scan de référence" {
            return "Premier scan de référence : les prochains scans montreront ce qui monte ou descend."
        }

        var parts: [String] = []

        if retentionLoad >= 62 {
            if facts.retentionPersistingScans >= 3 {
                parts.append("Tu as encore de la rétention d'eau visible (\(retentionLoad) %) — \(facts.retentionPersistingScans) scans d'affilée au-dessus de ta référence.")
            } else if let delta = retention.delta, delta >= 4 {
                parts.append("Tu as encore de la rétention d'eau visible (\(retentionLoad) %) et elle monte vs ta moyenne récente (\(retention.deltaLabel)).")
            } else if let delta = retention.delta, delta <= -6 {
                parts.append("La rétention descend (\(retention.deltaLabel)) mais reste encore visible à \(retentionLoad) %.")
            } else {
                parts.append("Tu as encore de la rétention d'eau visible (\(retentionLoad) %) : surveille eau, sodium et potassium alimentaire.")
            }
        } else if let delta = retention.delta, delta <= -6 {
            parts.append("La rétention descend (\(retention.deltaLabel)) : visage moins gonflé que ta référence récente.")
        } else {
            let changed = FaceScanMetricDisplay.keyItems(for: result, previous: previous, limit: 2)
                .filter { abs($0.delta ?? 0) >= 4 }
            if changed.isEmpty {
                parts.append("Évolution stable vs ta moyenne récente.")
            } else {
                parts.append(changed.map { "\($0.title.lowercased()) \($0.deltaLabel)" }.joined(separator: ", ") + " vs référence récente.")
            }
        }

        if let trend = facts.retentionTrend, trend.direction == .rising || trend.direction == .plateau {
            parts.append(trend.label + ".")
        }

        if let month = facts.monthWellnessDelta, abs(month) >= 4 {
            let dir = month >= 0 ? "au-dessus" : "en dessous"
            parts.append("Score global \(dir) de ta moyenne du mois (\(month >= 0 ? "+" : "")\(month) pts).")
        }

        if let nutrition = nutritionContextLine(facts: facts, context: resolvedContext) {
            parts.append(nutrition)
        }

        if let correlation = facts.correlations.first {
            parts.append(correlation.message)
        }

        return parts.joined(separator: " ")
    }

    @MainActor
    static func actionSentence(
        for result: FaceScanResult,
        previous: FaceScanResult? = nil,
        history: [FaceScanResult] = [],
        context: FaceScanInsightContext? = nil
    ) -> String {
        let resolvedContext = context ?? FaceScanInsightContext.fromTodayHealth()
        let facts = build(for: result, history: history, context: resolvedContext)

        let retention = FaceScanMetricDisplay.item(for: .retention, result: result, previous: previous)
        let recovery = FaceScanMetricDisplay.item(for: .recovery, result: result, previous: previous)
        let stress = FaceScanMetricDisplay.item(for: .stressLoad, result: result, previous: previous)
        let retentionLoad = FaceScanIndicators.displayPercent(for: .retention, result: result)

        let hydrationLow: Bool = {
            guard let water = resolvedContext.waterLiters,
                  let target = resolvedContext.hydrationTargetLiters,
                  target > 0 else { return false }
            return water < target * 0.60
        }()

        if retentionLoad >= 62 || (retention.delta ?? 0) >= 6 {
            return retentionAction(
                facts: facts,
                hydrationLow: hydrationLow,
                persisting: facts.retentionPersistingScans >= 2
            )
        }

        if (recovery.delta ?? 0) >= 6 || (stress.delta ?? 0) >= 6 {
            return pickUnused(
                candidates: [
                    "Priorité aujourd'hui : sommeil plus tôt, respiration nasale, pas d'effort intense tardif.",
                    "Priorité aujourd'hui : coucher 30 min plus tôt, lumière douce ce soir, pas de cardio intense.",
                    "Priorité aujourd'hui : pause sans écran, respiration nasale 5 min, réveil régulier demain."
                ],
                recent: facts.recentSuggestedActions,
                seed: result.id
            )
        }

        if hydrationLow {
            return "Priorité aujourd'hui : rattraper l'hydratation par petites prises régulières, puis rescan demain matin."
        }

        return "Priorité aujourd'hui : garder l'hydratation et refaire le scan dans les mêmes conditions."
    }

    @MainActor
    static func factsPromptBlock(
        for result: FaceScanResult,
        history: [FaceScanResult],
        context: FaceScanInsightContext? = nil
    ) -> String {
        let resolvedContext = context ?? FaceScanInsightContext.fromTodayHealth()
        let facts = build(for: result, history: history, context: resolvedContext)

        var lines: [String] = ["FAITS ÉVOLUTION (données réelles — base ton analyse dessus) :"]

        if let rel = result.relativeSignals, rel.baselineLabel != "Premier scan de référence" {
            lines.append("- vs baseline : rétention \(signed(rel.puffinessDelta)), cernes \(signed(rel.underEyeFatigueDelta)), stress \(signed(rel.stressLoadDelta ?? 0)), peau \(signed(rel.skinClarityDelta)).")
        }

        if facts.retentionPersistingScans >= 2 {
            lines.append("- Rétention élevée depuis \(facts.retentionPersistingScans) scans consécutifs.")
        }

        if let trend = facts.retentionTrend {
            lines.append("- Tendance rétention : \(trend.label).")
        }
        if let trend = facts.recoveryTrend {
            lines.append("- Tendance récup : \(trend.label).")
        }

        if let month = facts.monthWellnessDelta {
            lines.append("- vs moyenne 30 jours : \(signed(month)) pts score global.")
        }

        if let nutrition = nutritionContextLine(facts: facts, context: resolvedContext) {
            lines.append("- Nutrition : \(nutrition)")
        }

        for correlation in facts.correlations {
            lines.append("- Corrélation : \(correlation.message)")
        }

        if let streak = facts.trajectoryStreak, let trend = facts.trajectoryTrendLabel {
            lines.append("- Trajectoire debloat : streak \(streak), tendance \(trend).")
        }

        if !facts.recentSuggestedActions.isEmpty {
            lines.append("- Actions déjà proposées récemment (proposer autre chose si problème persiste) : \(facts.recentSuggestedActions.joined(separator: " | ")).")
        }

        if let water = resolvedContext.waterLiters, let target = resolvedContext.hydrationTargetLiters, target > 0 {
            lines.append("- Hydratation aujourd'hui : \(String(format: "%.1f", water)) L / \(String(format: "%.1f", target)) L objectif.")
        }

        return lines.joined(separator: "\n")
    }

    static func dailyHistory(from history: [FaceScanResult]) -> [FaceScanResult] {
        history.filter { $0.source == .daily }
    }

    // MARK: - Nutrition

    @MainActor
    private static func nutritionFacts(dayOffset: Int) -> FaceScanNutritionFacts {
        guard let plan = WelcomePlanStore.shared.plan else { return .empty }
        let calendar = Calendar.current
        let targetDate = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) ?? Date()
        let dayIdx = plan.calendar.currentProgramDayIndex(from: targetDate)
        guard let day = plan.calendar.day(globalIndex: dayIdx) else { return .empty }

        let entries = PlanDayMealsProvider.entries(
            plan: plan,
            day: day,
            store: WelcomePlanStore.shared
        )
        guard !entries.isEmpty else { return .empty }

        var sodiumTotal = 0.0
        var potassiumTotal = 0.0
        var electrolyteScores: [Int] = []
        var summaries: [String] = []

        for entry in entries {
            let profile = MealNutritionCatalog.profile(for: entry.meal)
            sodiumTotal += profile.sodiumMg
            potassiumTotal += profile.potassiumMg
            let assessment = entry.assessment
            electrolyteScores.append(assessment.electrolyteScore)
            if assessment.electrolyteScore < 68 {
                summaries.append("\(entry.slot.rawValue) : \(assessment.summary)")
            }
        }

        let mealCount = entries.count
        let avgElectrolyte = electrolyteScores.isEmpty
            ? nil
            : electrolyteScores.reduce(0, +) / electrolyteScores.count
        let ratio = potassiumTotal / max(sodiumTotal, 1)

        var facts = FaceScanNutritionFacts(
            estimatedSodiumMg: sodiumTotal,
            estimatedPotassiumMg: potassiumTotal,
            electrolyteScore: avgElectrolyte,
            mealCount: mealCount,
            isHighSodium: sodiumTotal >= 2_400,
            isLowPotassium: potassiumTotal < 2_000,
            isPoorElectrolyteBalance: ratio < 2.0 || (avgElectrolyte ?? 100) < 62
        )

        if facts.isHighSodium || facts.isPoorElectrolyteBalance {
            let sodiumG = String(format: "%.1f", sodiumTotal / 1_000)
            let potassiumG = String(format: "%.1f", potassiumTotal / 1_000)
            facts.summaryLine = "Hier ~\(sodiumG) g Na / \(potassiumG) g K (ratio \(String(format: "%.1f", ratio)))"
            if let first = summaries.first {
                facts.summaryLine = (facts.summaryLine ?? "") + " — \(first)"
            }
        } else if let avgElectrolyte, avgElectrolyte >= 76 {
            facts.summaryLine = "Hier bon équilibre électrolytes (score \(avgElectrolyte)/100) — garde ce profil."
        }

        return facts
    }

    private static func nutritionContextLine(
        facts: FaceScanEvolutionFacts,
        context: FaceScanInsightContext
    ) -> String? {
        var parts: [String] = []

        if let line = facts.nutritionYesterday.summaryLine {
            parts.append(line)
        }

        if let water = context.waterLiters,
           let target = context.hydrationTargetLiters,
           target > 0,
           water < target * 0.55 {
            parts.append("Hydratation basse ce matin (\(String(format: "%.1f", water)) L).")
        }

        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    private static func retentionAction(
        facts: FaceScanEvolutionFacts,
        hydrationLow: Bool,
        persisting: Bool
    ) -> String {
        var candidates: [String] = []

        if hydrationLow {
            candidates.append("Priorité aujourd'hui : rattraper l'eau par petites prises, sel modéré, potassium au repas (banane, épinards, patate douce).")
        }

        if facts.nutritionYesterday.isHighSodium || facts.nutritionYesterday.isPoorElectrolyteBalance {
            candidates.append("Priorité aujourd'hui : moins de sel/processés, repas riches en potassium, 15 min de marche pour relancer le drainage.")
            if let line = facts.nutritionYesterday.summaryLine {
                candidates.append("Priorité aujourd'hui : \(line) — reproduis un repas du plan plus riche en potassium.")
            }
        } else if facts.nutritionYesterday.electrolyteScore ?? 0 >= 76 {
            candidates.append("Priorité aujourd'hui : garde le profil repas d'hier (bon K/Na), eau régulière, pas de grignotage salé.")
        }

        if persisting {
            candidates.append("Priorité aujourd'hui : rétention qui persiste — eau régulière, sodium modéré, marche 15 min, coucher plus tôt ce soir.")
            candidates.append("Priorité aujourd'hui : le gonflement persiste — vérifie sel/processés, ajoute légumes potassium, respiration nasale 5 min.")
        }

        candidates.append("Priorité aujourd'hui : limiter sodium/processés, garder l'eau régulière, ajouter potassium alimentaire.")
        candidates.append("Priorité aujourd'hui : hydratation régulière, sel modéré, aliments riches en potassium au repas.")

        return pickUnused(
            candidates: candidates,
            recent: facts.recentSuggestedActions,
            seed: facts.scanId
        )
    }

    // MARK: - Tendances

    private static func indicatorTrend(
        for kind: FaceScanIndicators.Kind,
        history: [FaceScanResult]
    ) -> FaceScanIndicatorTrend? {
        let samples = history
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(14)
            .map { FaceScanIndicators.displayPercent(for: kind, result: $0) }

        guard samples.count >= 4 else { return nil }

        let values = Array(samples.reversed())
        let first = values.first ?? 0
        let last = values.last ?? 0
        let delta = last - first
        let span = min(14, values.count)

        let variance = values.map { abs($0 - values.last!) }
        let avgVariance = variance.reduce(0, +) / max(variance.count, 1)

        let direction: FaceScanIndicatorTrend.Direction
        if avgVariance <= 3, abs(delta) <= 4 {
            direction = .plateau
        } else if delta >= 5 {
            direction = .rising
        } else if delta <= -5 {
            direction = .falling
        } else {
            direction = .stable
        }

        return FaceScanIndicatorTrend(
            kind: kind,
            direction: direction,
            spanDays: span,
            pointDelta: delta
        )
    }

    // MARK: - Persistance & mémoire

    private static func retentionPersistenceCount(
        for result: FaceScanResult,
        history: [FaceScanResult]
    ) -> Int {
        let ordered = ([result] + history.filter { $0.id != result.id })
            .sorted { $0.createdAt > $1.createdAt }

        var count = 0
        for scan in ordered {
            let load = FaceScanIndicators.displayPercent(for: .retention, result: scan)
            let elevated = load >= 58 || (scan.relativeSignals?.puffinessDelta ?? 0) >= 3
            guard elevated else { break }
            count += 1
        }
        return count
    }

    private static func recentActions(
        from history: [FaceScanResult],
        excluding scanId: String
    ) -> [String] {
        history
            .filter { $0.id != scanId }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(3)
            .compactMap { scan -> String? in
                if let analysis = scan.claudeAnalysis {
                    let parsed = FaceScanAnalysisParser.parse(analysis)
                    if let tip = parsed.tips.first { return tip }
                }
                if let coach = scan.coachInsightMessage {
                    let preview = FaceScanCoachInsightService.cardPreview(from: coach)
                    if !preview.isEmpty { return String(preview.prefix(80)) }
                }
                return nil
            }
    }

    private static func pickUnused(
        candidates: [String],
        recent: [String],
        seed: String
    ) -> String {
        let normalizedRecent = Set(recent.map { $0.lowercased() })
        let fresh = candidates.filter { candidate in
            !normalizedRecent.contains(where: { recent in
                candidate.lowercased().contains(recent.prefix(24).lowercased())
                    || recent.lowercased().contains(candidate.prefix(24).lowercased())
            })
        }

        let pool = fresh.isEmpty ? candidates : fresh
        let hash = abs(seed.hashValue)
        return pool[hash % pool.count]
    }

    private static func signed(_ value: Int) -> String {
        value >= 0 ? "+\(value)" : "\(value)"
    }
}
