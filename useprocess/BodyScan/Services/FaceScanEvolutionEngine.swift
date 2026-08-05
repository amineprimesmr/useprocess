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
            return AppCopy.tSync(
                "\(name) en hausse sur \(spanDays) j (\(signed(pointDelta)))",
                en: "\(name) rising over \(spanDays)d (\(signed(pointDelta)))"
            )
        case .falling:
            return AppCopy.tSync(
                "\(name) en baisse sur \(spanDays) j (\(signed(pointDelta)))",
                en: "\(name) falling over \(spanDays)d (\(signed(pointDelta)))"
            )
        case .plateau:
            return AppCopy.tSync(
                "\(name) stable depuis \(spanDays) scans",
                en: "\(name) stable for \(spanDays) scans"
            )
        case .stable:
            return AppCopy.tSync(
                "\(name) peu variable sur \(spanDays) j",
                en: "\(name) little change over \(spanDays)d"
            )
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
        context _: FaceScanInsightContext? = nil
    ) -> FaceScanEvolutionFacts {
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

        if result.relativeSignals?.baselineLabel == "Premier scan de référence" || previous == nil {
            return AppCopy.tSync("Point de départ enregistré : tous tes indicateurs sont suivis. Les prochains scans montreront ce qui monte ou descend.", en: "Starting point saved: all your indicators are tracked. Next scans will show what rises or falls.")
        }

        var parts: [String] = []

        if retentionLoad >= 62 {
            if facts.retentionPersistingScans >= 3 {
                parts.append(AppCopy.tSync(
                    "Tu as encore de la rétention d'eau visible (\(retentionLoad) %) — \(facts.retentionPersistingScans) scans d'affilée au-dessus de ta référence.",
                    en: "You still have visible water retention (\(retentionLoad)%) — \(facts.retentionPersistingScans) scans in a row above your baseline."
                ))
            } else if let delta = retention.delta, delta >= 4 {
                parts.append(AppCopy.tSync("Tu as encore de la rétention d'eau visible (\(retentionLoad) %) et elle monte vs ta moyenne récente (\(retention.deltaLabel)).", en: "You still have visible water retention (\(retentionLoad)%) and it's rising vs your recent average (\(retention.deltaLabel))."))
            } else if let delta = retention.delta, delta <= -6 {
                parts.append(AppCopy.tSync("La rétention descend (\(retention.deltaLabel)) mais reste encore visible à \(retentionLoad) %.", en: "Retention is falling (\(retention.deltaLabel)) but still visible at \(retentionLoad)%."))
            } else {
                parts.append(AppCopy.tSync("Tu as encore de la rétention d'eau visible (\(retentionLoad) %) : surveille eau, sodium et potassium alimentaire.", en: "You still have visible water retention (\(retentionLoad)%): watch water, sodium, and dietary potassium."))
            }
        } else if let delta = retention.delta, delta <= -6 {
            parts.append(AppCopy.tSync("La rétention descend (\(retention.deltaLabel)) : visage moins gonflé que ta référence récente.", en: "Retention is falling (\(retention.deltaLabel)): face less puffy than your recent baseline."))
        } else {
            let changed = FaceScanMetricDisplay.keyItems(for: result, previous: previous, limit: 2)
                .filter { abs($0.delta ?? 0) >= 4 }
            if changed.isEmpty {
                parts.append(AppCopy.tSync("Évolution stable vs ta moyenne récente.", en: "Stable trend vs your recent average."))
            } else {
                parts.append(changed.map { "\($0.title.lowercased()) \($0.deltaLabel)" }.joined(separator: ", ") + AppCopy.tSync(" vs référence récente.", en: " vs recent baseline."))
            }
        }

        if let trend = facts.retentionTrend, trend.direction == .rising || trend.direction == .plateau {
            parts.append(trend.label + ".")
        }

        if let month = facts.monthWellnessDelta, abs(month) >= 4 {
            let signedPts = "\(month >= 0 ? "+" : "")\(month)"
            parts.append(
                AppCopy.tSync(
                    "Score global \(month >= 0 ? "au-dessus" : "en dessous") de ta moyenne du mois (\(signedPts) pts).",
                    en: "Overall score \(month >= 0 ? "above" : "below") your monthly average (\(signedPts) pts)."
                )
            )
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
                    AppCopy.tSync("Priorité aujourd'hui : sommeil plus tôt, respiration nasale, pas d'effort intense tardif.", en: "Priority today: earlier sleep, nasal breathing, no late intense effort."),
                    AppCopy.tSync("Priorité aujourd'hui : coucher 30 min plus tôt, lumière douce ce soir, pas de cardio intense.", en: "Priority today: bed 30 min earlier, soft light tonight, no intense cardio."),
                    AppCopy.tSync("Priorité aujourd'hui : pause sans écran, respiration nasale 5 min, réveil régulier demain.", en: "Priority today: screen-free break, 5 min nasal breathing, steady wake tomorrow.")
                ],
                recent: facts.recentSuggestedActions,
                seed: result.id
            )
        }

        if hydrationLow {
            return AppCopy.tSync("Priorité aujourd'hui : rattraper l'hydratation par petites prises régulières, puis rescan demain matin.", en: "Priority today: catch up hydration with small regular sips, then rescan tomorrow morning.")
        }

        return AppCopy.tSync("Priorité aujourd'hui : garder l'hydratation et refaire le scan dans les mêmes conditions.", en: "Priority today: keep hydration and rescan under the same conditions.")
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
            facts.summaryLine = AppCopy.tSync("Hier bon équilibre électrolytes (score \(avgElectrolyte)/100) — garde ce profil.", en: "Good electrolyte balance yesterday (score \(avgElectrolyte)/100) — keep that profile.")
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
            candidates.append(AppCopy.tSync("Priorité aujourd'hui : rattraper l'eau par petites prises, sel modéré, potassium au repas (banane, épinards, patate douce).", en: "Priority today: catch up water with small sips, moderate salt, potassium at meals (banana, spinach, sweet potato)."))
        }

        if facts.nutritionYesterday.isHighSodium || facts.nutritionYesterday.isPoorElectrolyteBalance {
            candidates.append(AppCopy.tSync("Priorité aujourd'hui : moins de sel/processés, repas riches en potassium, 15 min de marche pour relancer le drainage.", en: "Priority today: less salt/processed food, potassium-rich meals, 15-min walk to restart drainage."))
            if let line = facts.nutritionYesterday.summaryLine {
                candidates.append(AppCopy.tSync("Priorité aujourd'hui : \(line) — reproduis un repas du plan plus riche en potassium.", en: "Priority today: \(line) — repeat a plan meal richer in potassium."))
            }
        } else if facts.nutritionYesterday.electrolyteScore ?? 0 >= 76 {
            candidates.append(AppCopy.tSync("Priorité aujourd'hui : garde le profil repas d'hier (bon K/Na), eau régulière, pas de grignotage salé.", en: "Priority today: keep yesterday's meal profile (good K/Na), steady water, no salty snacking."))
        }

        if persisting {
            candidates.append(AppCopy.tSync("Priorité aujourd'hui : rétention qui persiste — eau régulière, sodium modéré, marche 15 min, coucher plus tôt ce soir.", en: "Priority today: lingering retention — steady water, moderate sodium, 15-min walk, earlier bed tonight."))
            candidates.append(AppCopy.tSync("Priorité aujourd'hui : le gonflement persiste — vérifie sel/processés, ajoute légumes potassium, respiration nasale 5 min.", en: "Priority today: puffiness persists — check salt/processed food, add potassium veggies, 5 min nasal breathing."))
        }

        candidates.append(AppCopy.tSync("Priorité aujourd'hui : limiter sodium/processés, garder l'eau régulière, ajouter potassium alimentaire.", en: "Priority today: limit sodium/processed food, keep water steady, add dietary potassium."))
        candidates.append(AppCopy.tSync("Priorité aujourd'hui : hydratation régulière, sel modéré, aliments riches en potassium au repas.", en: "Priority today: steady hydration, moderate salt, potassium-rich foods at meals."))

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
