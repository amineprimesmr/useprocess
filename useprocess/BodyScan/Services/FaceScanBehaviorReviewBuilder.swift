import Foundation

struct FaceScanBehaviorReviewEvent: Identifiable, Equatable {
    let id: String
    let sortDate: Date
    let timeLabel: String
    let systemImage: String
    let title: String
    let detail: String
    let fix: String?
    let isPositive: Bool
}

struct FaceScanBehaviorReview: Equatable {
    let summary: String
    let primaryFix: String
    let events: [FaceScanBehaviorReviewEvent]
    let showsBaselineSetup: Bool
}

enum FaceScanBehaviorReviewBuilder {

    @MainActor
    static func build(
        for result: FaceScanResult,
        previous: FaceScanResult? = nil,
        history: [FaceScanResult] = [],
        context: FaceScanInsightContext? = nil,
        now: Date = Date()
    ) -> FaceScanBehaviorReview {
        let resolvedContext = context ?? FaceScanInsightContext.fromTodayHealth()
        let insight = FaceScanAIInsightBuilder.insight(
            for: result,
            history: history,
            context: resolvedContext
        )
        let facts = FaceScanEvolutionEngine.build(
            for: result,
            history: history,
            context: resolvedContext
        )

        let isBaseline = previous == nil
            || result.relativeSignals?.baselineLabel == "Premier scan de référence"

        if isBaseline {
            return baselineReview(for: result, now: now)
        }

        var events: [FaceScanBehaviorReviewEvent] = []

        events.append(
            FaceScanBehaviorReviewEvent(
                id: "scan-\(result.id)",
                sortDate: result.createdAt,
                timeLabel: timeLabel(for: result.createdAt, now: now),
                systemImage: insight.primaryCause == .balanced ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                title: insight.title,
                detail: insight.body,
                fix: nil,
                isPositive: insight.primaryCause == .balanced
            )
        )

        appendHealthEvents(to: &events, result: result, context: resolvedContext, now: now)
        appendNutritionEvents(to: &events, facts: facts, now: now)
        appendMetricEvents(to: &events, result: result, previous: previous, now: now)
        appendScanHistoryEvents(to: &events, result: result, previous: previous, now: now)
        appendTrendEvents(to: &events, facts: facts, now: now)
        appendCorrelationEvents(to: &events, facts: facts, now: now)
        appendCheckInEvents(to: &events, now: now)
        appendPlanEvents(to: &events, now: now)

        let sorted = dedupeAndLimit(events.sorted { $0.sortDate > $1.sortDate }, max: 6)
        let primaryFix = FaceScanEvolutionEngine.actionSentence(
            for: result,
            previous: previous,
            history: history,
            context: resolvedContext
        )

        return FaceScanBehaviorReview(
            summary: summaryLine(for: insight),
            primaryFix: primaryFix,
            events: sorted,
            showsBaselineSetup: false
        )
    }

    /// Données studio simulées — pilotées par le curseur qualité (mode Amineprcs).
    @MainActor
    static func buildStudio(
        for result: FaceScanResult,
        quality: Double,
        previous: FaceScanResult? = nil,
        now: Date = Date()
    ) -> FaceScanBehaviorReview {
        let q = min(1, max(0, quality))
        let seed = result.id
        let score = result.displayWellnessScore
        let retention = FaceScanIndicators.displayPercent(for: .retention, result: result)

        var events = studioTimelineEvents(
            quality: q,
            seed: seed,
            score: score,
            retention: retention,
            scanDate: result.createdAt,
            now: now
        )

        if let previous {
            let delta = score - previous.displayWellnessScore
            if delta <= -8 {
                events.insert(
                    FaceScanBehaviorReviewEvent(
                        id: "studio-scan-drop",
                        sortDate: previous.createdAt,
                        timeLabel: timeLabel(for: previous.createdAt, now: now),
                        systemImage: "arrow.down.right.circle.fill",
                        title: AppCopy.tSync("Chute vs scan précédent", en: "Drop vs previous scan"),
                        detail: AppCopy.tSync(
                            "\(previous.displayWellnessScore) % → \(score) % — la routine récente ne tient pas.",
                            en: "\(previous.displayWellnessScore)% → \(score)% — your recent routine isn't holding."
                        ),
                        fix: AppCopy.tSync(
                            "Repars sur eau + repas debloat + marche 48 h.",
                            en: "Reset to water + debloat meals + walking for 48 h."
                        ),
                        isPositive: false
                    ),
                    at: min(2, events.count)
                )
            } else if delta >= 8, q >= 0.65 {
                events.insert(
                    FaceScanBehaviorReviewEvent(
                        id: "studio-scan-rise",
                        sortDate: previous.createdAt,
                        timeLabel: timeLabel(for: previous.createdAt, now: now),
                        systemImage: "arrow.up.right.circle.fill",
                        title: AppCopy.tSync("Progrès vs scan précédent", en: "Progress vs previous scan"),
                        detail: AppCopy.tSync(
                            "\(previous.displayWellnessScore) % → \(score) % — la routine fonctionne.",
                            en: "\(previous.displayWellnessScore)% → \(score)% — the routine is working."
                        ),
                        fix: nil,
                        isPositive: true
                    ),
                    at: min(2, events.count)
                )
            }
        }

        let sorted = dedupeAndLimit(events.sorted { $0.sortDate > $1.sortDate }, max: 6)

        return FaceScanBehaviorReview(
            summary: studioSummary(quality: q, score: score),
            primaryFix: studioPrimaryFix(quality: q, seed: seed, retention: retention),
            events: sorted,
            showsBaselineSetup: false
        )
    }

    // MARK: - Studio (données simulées)

    @MainActor
    private static func studioTimelineEvents(
        quality: Double,
        seed: String,
        score: Int,
        retention: Int,
        scanDate: Date,
        now: Date
    ) -> [FaceScanBehaviorReviewEvent] {
        var events: [FaceScanBehaviorReviewEvent] = []

        let scanTitle: String
        let scanDetail: String
        let scanPositive: Bool

        switch quality {
        case 0.8...:
            scanTitle = AppCopy.tSync("Visage en forme · \(score) %", en: "Face looking good · \(score)%")
            scanDetail = AppCopy.tSync(
                "Peu de signaux négatifs — rétention \(retention) %, récupération solide.",
                en: "Few negative signals — retention \(retention)%, solid recovery."
            )
            scanPositive = true
        case 0.6..<0.8:
            scanTitle = AppCopy.tSync("Léger décalage · \(score) %", en: "Slight drift · \(score)%")
            scanDetail = AppCopy.tSync(
                "Un ou deux leviers à corriger — rétention \(retention) % encore un peu haute.",
                en: "One or two levers to fix — retention \(retention)% still a bit high."
            )
            scanPositive = false
        case 0.4..<0.6:
            scanTitle = AppCopy.tSync("Rétention visible · \(retention) %", en: "Visible retention · \(retention)%")
            scanDetail = AppCopy.tSync(
                "Score \(score) % — plusieurs habitudes récentes ne sont pas alignées.",
                en: "Score \(score)% — several recent habits aren't aligned."
            )
            scanPositive = false
        case 0.2..<0.4:
            scanTitle = AppCopy.tSync("Gonflement marqué · \(retention) %", en: "Marked puffiness · \(retention)%")
            scanDetail = AppCopy.tSync(
                "Score \(score) % — sommeil, sel ou hydratation ont clairement joué.",
                en: "Score \(score)% — sleep, salt, or hydration clearly played a role."
            )
            scanPositive = false
        default:
            scanTitle = AppCopy.tSync("Rétention forte · \(retention) %", en: "Heavy retention · \(retention)%")
            scanDetail = AppCopy.tSync(
                "Score \(score) % — cumul d'erreurs sur les derniers jours.",
                en: "Score \(score)% — stacked mistakes over the last few days."
            )
            scanPositive = false
        }

        events.append(
            FaceScanBehaviorReviewEvent(
                id: "studio-scan",
                sortDate: scanDate,
                timeLabel: timeLabel(for: scanDate, now: now),
                systemImage: scanPositive ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                title: scanTitle,
                detail: scanDetail,
                fix: nil,
                isPositive: scanPositive
            )
        )

        let sleepHours = studioSleepHours(quality: quality, seed: seed)
        if quality < 0.72 {
            events.append(
                FaceScanBehaviorReviewEvent(
                    id: "studio-sleep",
                    sortDate: calendar.startOfDay(for: now),
                    timeLabel: AppCopy.tSync("Cette nuit", en: "Last night"),
                    systemImage: "moon.zzz.fill",
                    title: AppCopy.tSync("Sommeil insuffisant", en: "Insufficient sleep"),
                    detail: AppCopy.tSync(
                        "\(formatHours(sleepHours)) enregistré — trop court pour dégonfler correctement.",
                        en: "\(formatHours(sleepHours)) logged — too short to debloat properly."
                    ),
                    fix: AppCopy.tSync(
                        "Coucher 45 min plus tôt ce soir.",
                        en: "Bed 45 min earlier tonight."
                    ),
                    isPositive: false
                )
            )
        } else {
            events.append(
                FaceScanBehaviorReviewEvent(
                    id: "studio-sleep-ok",
                    sortDate: calendar.startOfDay(for: now),
                    timeLabel: AppCopy.tSync("Cette nuit", en: "Last night"),
                    systemImage: "moon.stars.fill",
                    title: AppCopy.tSync("Sommeil solide", en: "Solid sleep"),
                    detail: AppCopy.tSync(
                        "\(formatHours(sleepHours)) — bonne base pour la récupération faciale.",
                        en: "\(formatHours(sleepHours)) — good base for facial recovery."
                    ),
                    fix: nil,
                    isPositive: true
                )
            )
        }

        let waterLiters = studioWaterLiters(quality: quality, seed: seed)
        let waterTarget = 2.5
        if quality < 0.68 {
            let gap = max(0, waterTarget - waterLiters)
            events.append(
                FaceScanBehaviorReviewEvent(
                    id: "studio-water",
                    sortDate: now,
                    timeLabel: AppCopy.tSync("Aujourd'hui", en: "Today"),
                    systemImage: "drop.fill",
                    title: AppCopy.tSync("Hydratation en retard", en: "Hydration behind"),
                    detail: AppCopy.tSync(
                        "\(String(format: "%.1f", waterLiters)) L sur \(Int(waterTarget)) L — encore \(String(format: "%.1f", gap)) L.",
                        en: "\(String(format: "%.1f", waterLiters)) L of \(Int(waterTarget)) L — \(String(format: "%.1f", gap)) L left."
                    ),
                    fix: AppCopy.tSync(
                        "Boire maintenant par petites prises.",
                        en: "Sip steadily starting now."
                    ),
                    isPositive: false
                )
            )
        }

        if quality < 0.55 {
            let sodium = studioSodiumGrams(quality: quality, seed: seed)
            let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)) ?? now
            events.append(
                FaceScanBehaviorReviewEvent(
                    id: "studio-sodium",
                    sortDate: yesterday,
                    timeLabel: AppCopy.tSync("Hier", en: "Yesterday"),
                    systemImage: "takeoutbag.and.cup.and.straw.fill",
                    title: AppCopy.tSync("Sodium trop élevé hier", en: "Sodium too high yesterday"),
                    detail: AppCopy.tSync(
                        "Environ \(String(format: "%.1f", sodium)) g — repas tardif / ultra-transformés probables.",
                        en: "About \(String(format: "%.1f", sodium)) g — likely late meal / ultra-processed food."
                    ),
                    fix: AppCopy.tSync(
                        "Repas maison ce soir, sel modéré.",
                        en: "Home cooking tonight, moderate salt."
                    ),
                    isPositive: false
                )
            )
        }

        if quality < 0.45 {
            let missedDays = studioMix(seed, "studio.miss", in: 2...4)
            let checkInDate = calendar.date(byAdding: .day, value: -missedDays, to: calendar.startOfDay(for: now)) ?? now
            events.append(
                FaceScanBehaviorReviewEvent(
                    id: "studio-meal-miss",
                    sortDate: checkInDate,
                    timeLabel: timeLabel(for: checkInDate, now: now),
                    systemImage: "fork.knife.circle",
                    title: AppCopy.tSync("Repas debloat manqué", en: "Debloat meal missed"),
                    detail: AppCopy.tSync(
                        "Check-in du soir non validé — repas anti-gonflement sauté.",
                        en: "Evening check-in failed — anti-puff meal skipped."
                    ),
                    fix: AppCopy.tSync(
                        "Prévois le repas debloat à l'avance demain.",
                        en: "Prep tomorrow's debloat meal ahead of time."
                    ),
                    isPositive: false
                )
            )
        }

        if quality < 0.35 {
            let cardioMisses = studioMix(seed, "studio.cardio", in: 2...5)
            let cardioDate = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)) ?? now
            events.append(
                FaceScanBehaviorReviewEvent(
                    id: "studio-cardio",
                    sortDate: cardioDate,
                    timeLabel: AppCopy.tSync("Il y a \(cardioMisses) j", en: "\(cardioMisses) days ago"),
                    systemImage: "figure.run.circle",
                    title: AppCopy.tSync("Cardio manqué plusieurs jours", en: "Cardio missed several days"),
                    detail: AppCopy.tSync(
                        "\(cardioMisses) jours sans marche/cardio — drainage lymphatique faible.",
                        en: "\(cardioMisses) days without walk/cardio — weak lymph drainage."
                    ),
                    fix: AppCopy.tSync(
                        "15 min de marche après le déjeuner.",
                        en: "15-min walk after lunch."
                    ),
                    isPositive: false
                )
            )
        }

        if quality < 0.25 {
            let span = studioMix(seed, "studio.retention", in: 4...7)
            events.append(
                FaceScanBehaviorReviewEvent(
                    id: "studio-retention-trend",
                    sortDate: now,
                    timeLabel: AppCopy.tSync("\(span) j", en: "\(span)d"),
                    systemImage: "chart.line.uptrend.xyaxis",
                    title: AppCopy.tSync("Rétention persistante", en: "Persistent retention"),
                    detail: AppCopy.tSync(
                        "Gonflement au-dessus de ta référence depuis \(span) scans d'affilée.",
                        en: "Puffiness above your baseline for \(span) scans in a row."
                    ),
                    fix: AppCopy.tSync(
                        "Audit sel + eau strict 48 h.",
                        en: "Strict salt + water audit for 48 h."
                    ),
                    isPositive: false
                )
            )
        }

        if quality >= 0.82 {
            events.append(
                FaceScanBehaviorReviewEvent(
                    id: "studio-streak",
                    sortDate: now,
                    timeLabel: AppCopy.tSync("Cette semaine", en: "This week"),
                    systemImage: "flame.fill",
                    title: AppCopy.tSync("Routine cohérente", en: "Consistent routine"),
                    detail: AppCopy.tSync(
                        "Eau, repas plan et scan quotidien alignés — continue comme ça.",
                        en: "Water, plan meals, and daily scan aligned — keep it up."
                    ),
                    fix: nil,
                    isPositive: true
                )
            )
        }

        return events
    }

    @MainActor
    private static func studioSummary(quality: Double, score: Int) -> String {
        switch quality {
        case 0.8...:
            return AppCopy.tSync(
                "Peu d'erreurs détectées — surtout continuer la routine.",
                en: "Few mistakes detected — mostly keep the routine going."
            )
        case 0.6..<0.8:
            return AppCopy.tSync(
                "Quelques écarts récents — corrigeable aujourd'hui.",
                en: "A few recent gaps — fixable today."
            )
        case 0.4..<0.6:
            return AppCopy.tSync(
                "Plusieurs habitudes récentes tirent le visage vers le bas.",
                en: "Several recent habits are pulling your face down."
            )
        default:
            return AppCopy.tSync(
                "Cumul d'erreurs récentes — priorité debloat sur 48 h.",
                en: "Stacked recent mistakes — debloat priority for 48 h."
            )
        }
    }

    @MainActor
    private static func studioPrimaryFix(quality: Double, seed: String, retention: Int) -> String {
        switch quality {
        case 0.8...:
            return AppCopy.tSync(
                "Garde hydratation, repas plan et scan demain dans les mêmes conditions.",
                en: "Keep hydration, plan meals, and tomorrow's scan under the same conditions."
            )
        case 0.6..<0.8:
            return AppCopy.tSync(
                "Priorité : finir l'eau + repas debloat ce soir.",
                en: "Priority: finish water + debloat meal tonight."
            )
        case 0.4..<0.6:
            return AppCopy.tSync(
                "Priorité : sel modéré, eau régulière, marche 15 min.",
                en: "Priority: moderate salt, steady water, 15-min walk."
            )
        case 0.2..<0.4:
            return AppCopy.tSync(
                "Priorité : coucher tôt, zéro ultra-transformé, potassium au repas.",
                en: "Priority: early bed, no ultra-processed food, potassium at meals."
            )
        default:
            let variant = studioMix(seed, "studio.fix", in: 0...1)
            if variant == 0 {
                return AppCopy.tSync(
                    "Reset 48 h : eau, repas plan strict, pas d'alcool, scan demain matin.",
                    en: "48 h reset: water, strict plan meals, no alcohol, scan tomorrow morning."
                )
            }
            return AppCopy.tSync(
                "Priorité absolue : hydratation + sel bas + cardio léger — rétention \(retention) %.",
                en: "Top priority: hydration + low salt + light cardio — retention \(retention)%."
            )
        }
    }

    private static func studioSleepHours(quality: Double, seed: String) -> Double {
        switch quality {
        case 0.8...: return Double(studioMix(seed, "studio.sleep.good", in: 430...510)) / 60.0
        case 0.6..<0.8: return Double(studioMix(seed, "studio.sleep.mid", in: 380...430)) / 60.0
        case 0.4..<0.6: return Double(studioMix(seed, "studio.sleep.low", in: 330...390)) / 60.0
        default: return Double(studioMix(seed, "studio.sleep.bad", in: 270...330)) / 60.0
        }
    }

    private static func studioWaterLiters(quality: Double, seed: String) -> Double {
        switch quality {
        case 0.8...: return Double(studioMix(seed, "studio.water.good", in: 22...28)) / 10.0
        case 0.6..<0.8: return Double(studioMix(seed, "studio.water.mid", in: 16...22)) / 10.0
        case 0.4..<0.6: return Double(studioMix(seed, "studio.water.low", in: 10...16)) / 10.0
        default: return Double(studioMix(seed, "studio.water.bad", in: 4...10)) / 10.0
        }
    }

    private static func studioSodiumGrams(quality: Double, seed: String) -> Double {
        Double(studioMix(seed, "studio.sodium", in: 28...45)) / 10.0
    }

    private static func studioMix(_ seed: String, _ salt: String, in range: ClosedRange<Int>) -> Int {
        let raw = seed.isEmpty ? "studio-default" : seed
        let bytes = Array((raw + "#" + salt).utf8)
        var hash: UInt64 = 14695981039346656037
        for byte in bytes {
            hash ^= UInt64(byte)
            hash = hash &* 1099511628211
        }
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(hash % span)
    }

    // MARK: - Baseline

    @MainActor
    private static func baselineReview(for result: FaceScanResult, now: Date) -> FaceScanBehaviorReview {
        let events: [FaceScanBehaviorReviewEvent] = [
            FaceScanBehaviorReviewEvent(
                id: "baseline-scan",
                sortDate: result.createdAt,
                timeLabel: timeLabel(for: result.createdAt, now: now),
                systemImage: "flag.checkered",
                title: AppCopy.tSync("Premier point de référence", en: "First baseline point"),
                detail: AppCopy.tSync(
                    "Scan enregistré — on compare désormais chaque matin dans les mêmes conditions.",
                    en: "Scan saved — we'll compare each morning under the same conditions from here."
                ),
                fix: AppCopy.tSync(
                    "Demain : même lumière, même heure, avant le petit-déj.",
                    en: "Tomorrow: same light, same time, before breakfast."
                ),
                isPositive: true
            ),
            FaceScanBehaviorReviewEvent(
                id: "baseline-hydration",
                sortDate: now,
                timeLabel: AppCopy.tSync("Aujourd'hui", en: "Today"),
                systemImage: "drop.fill",
                title: AppCopy.tSync("Hydratation à verrouiller", en: "Lock in hydration"),
                detail: AppCopy.tSync(
                    "Sans assez d'eau régulière, le visage gonfle le lendemain — c'est le premier levier.",
                    en: "Without steady water, your face puffs up the next day — that's the first lever."
                ),
                fix: AppCopy.tSync(
                    "Vise ta cible d'eau avant 18 h.",
                    en: "Hit your water target before 6 p.m."
                ),
                isPositive: false
            ),
            FaceScanBehaviorReviewEvent(
                id: "baseline-meals",
                sortDate: now,
                timeLabel: AppCopy.tSync("Cette semaine", en: "This week"),
                systemImage: "fork.knife",
                title: AppCopy.tSync("Repas debloat du plan", en: "Plan debloat meals"),
                detail: AppCopy.tSync(
                    "Sel, ultra-transformés et repas tardifs faussent les prochains scans.",
                    en: "Salt, ultra-processed food, and late meals skew your next scans."
                ),
                fix: AppCopy.tSync(
                    "Suis les repas du plan au moins 5 j/7.",
                    en: "Follow plan meals at least 5 days a week."
                ),
                isPositive: false
            )
        ]

        return FaceScanBehaviorReview(
            summary: AppCopy.tSync(
                "Pas encore assez d'historique pour pointer une erreur précise — installe la routine d'abord.",
                en: "Not enough history yet to pinpoint a specific mistake — set up the routine first."
            ),
            primaryFix: AppCopy.tSync(
                "Priorité : scan demain matin + eau régulière + repas debloat ce soir.",
                en: "Priority: scan tomorrow morning + steady water + debloat meal tonight."
            ),
            events: events,
            showsBaselineSetup: true
        )
    }

    // MARK: - Event builders

    @MainActor
    private static func appendHealthEvents(
        to events: inout [FaceScanBehaviorReviewEvent],
        result: FaceScanResult,
        context: FaceScanInsightContext,
        now: Date
    ) {
        let sleep = result.sleepHoursAtScan ?? context.sleepHours
        let sleepTarget = context.sleepTargetHours ?? 7.5
        if let sleep, sleep > 0, sleep < sleepTarget - 0.5 {
            let hours = formatHours(sleep)
            events.append(
                FaceScanBehaviorReviewEvent(
                    id: "health-sleep",
                    sortDate: calendar.startOfDay(for: now),
                    timeLabel: AppCopy.tSync("Cette nuit", en: "Last night"),
                    systemImage: "moon.zzz.fill",
                    title: AppCopy.tSync("Pas assez de sommeil", en: "Not enough sleep"),
                    detail: AppCopy.tSync(
                        "\(hours) enregistré — le visage gonfle et les cernes reviennent vite sous ta cible.",
                        en: "\(hours) logged — puffiness and under-eyes come back fast below your target."
                    ),
                    fix: AppCopy.tSync(
                        "Ce soir : coucher 45 min plus tôt, pas d'écran 1 h avant.",
                        en: "Tonight: bed 45 min earlier, no screens 1 h before."
                    ),
                    isPositive: false
                )
            )
        }

        if let hrv = result.hrvAtScan ?? context.hrv, hrv > 0, hrv < 40 {
            events.append(
                FaceScanBehaviorReviewEvent(
                    id: "health-hrv",
                    sortDate: calendar.startOfDay(for: now),
                    timeLabel: AppCopy.tSync("Ce matin", en: "This morning"),
                    systemImage: "waveform.path.ecg",
                    title: AppCopy.tSync("Récupération nerveuse basse", en: "Low nervous-system recovery"),
                    detail: AppCopy.tSync(
                        "HRV basse (\(Int(hrv))) — stress ou effort tardif d'hier encore présent.",
                        en: "Low HRV (\(Int(hrv))) — yesterday's stress or late effort is still showing."
                    ),
                    fix: AppCopy.tSync(
                        "Marche douce 15 min + respiration nasale 5 min, pas de HIIT ce soir.",
                        en: "Easy 15-min walk + 5 min nasal breathing, no HIIT tonight."
                    ),
                    isPositive: false
                )
            )
        }

        if let water = context.waterLiters,
           let target = context.hydrationTargetLiters,
           target > 0,
           water < target * 0.55 {
            let gap = max(0, target - water)
            let gapLabel = String(format: "%.1f", gap)
            events.append(
                FaceScanBehaviorReviewEvent(
                    id: "health-water",
                    sortDate: now,
                    timeLabel: AppCopy.tSync("Aujourd'hui", en: "Today"),
                    systemImage: "drop.fill",
                    title: AppCopy.tSync("Hydratation en retard", en: "Hydration behind"),
                    detail: AppCopy.tSync(
                        "\(String(format: "%.1f", water)) L sur \(Int(target)) L — encore \(gapLabel) L à rattraper.",
                        en: "\(String(format: "%.1f", water)) L of \(Int(target)) L — \(gapLabel) L left to catch up."
                    ),
                    fix: AppCopy.tSync(
                        "Boire par petites prises maintenant, pas tout d'un coup ce soir.",
                        en: "Sip steadily now, don't chug it all tonight."
                    ),
                    isPositive: false
                )
            )
        }

        if let steps = context.steps,
           let target = context.stepTarget,
           target > 0,
           steps < target / 2 {
            events.append(
                FaceScanBehaviorReviewEvent(
                    id: "health-steps",
                    sortDate: now,
                    timeLabel: AppCopy.tSync("Aujourd'hui", en: "Today"),
                    systemImage: "figure.walk",
                    title: AppCopy.tSync("Peu de mouvement", en: "Low movement"),
                    detail: AppCopy.tSync(
                        "\(formattedSteps(steps)) pas — la lympho stagne et la rétention d'eau reste.",
                        en: "\(formattedSteps(steps)) steps — lymph flow stalls and water retention lingers."
                    ),
                    fix: AppCopy.tSync(
                        "Marche 15–20 min après le prochain repas.",
                        en: "Walk 15–20 min after your next meal."
                    ),
                    isPositive: false
                )
            )
        }
    }

    @MainActor
    private static func appendNutritionEvents(
        to events: inout [FaceScanBehaviorReviewEvent],
        facts: FaceScanEvolutionFacts,
        now: Date
    ) {
        let nutrition = facts.nutritionYesterday
        guard nutrition.mealCount > 0 || nutrition.summaryLine != nil else { return }

        let sortDate = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)) ?? now

        if nutrition.isHighSodium {
            let sodium = String(format: "%.1f", (nutrition.estimatedSodiumMg ?? 0) / 1_000)
            events.append(
                FaceScanBehaviorReviewEvent(
                    id: "nutrition-sodium",
                    sortDate: sortDate,
                    timeLabel: AppCopy.tSync("Hier", en: "Yesterday"),
                    systemImage: "takeoutbag.and.cup.and.straw.fill",
                    title: AppCopy.tSync("Sodium trop élevé hier", en: "Sodium too high yesterday"),
                    detail: nutrition.summaryLine ?? AppCopy.tSync(
                        "Environ \(sodium) g de sodium — classique pour gonfler au réveil.",
                        en: "About \(sodium) g sodium — classic for morning puffiness."
                    ),
                    fix: AppCopy.tSync(
                        "Repas maison, sel modéré, potassium (légumes verts, banane).",
                        en: "Home cooking, moderate salt, potassium (greens, banana)."
                    ),
                    isPositive: false
                )
            )
        } else if nutrition.isPoorElectrolyteBalance, let summary = nutrition.summaryLine {
            events.append(
                FaceScanBehaviorReviewEvent(
                    id: "nutrition-electrolytes",
                    sortDate: sortDate,
                    timeLabel: AppCopy.tSync("Hier", en: "Yesterday"),
                    systemImage: "leaf.fill",
                    title: AppCopy.tSync("Équilibre alimentaire faible", en: "Weak food balance"),
                    detail: summary,
                    fix: AppCopy.tSync(
                        "Repas debloat du plan ce soir + eau régulière.",
                        en: "Plan debloat meal tonight + steady water."
                    ),
                    isPositive: false
                )
            )
        }
    }

    @MainActor
    private static func appendMetricEvents(
        to events: inout [FaceScanBehaviorReviewEvent],
        result: FaceScanResult,
        previous: FaceScanResult?,
        now: Date
    ) {
        let worsening = FaceScanMetricDisplay.items(for: result, previous: previous)
            .filter { $0.comparisonKind == .worse && abs($0.delta ?? 0) >= 4 }

        for item in worsening.prefix(2) {
            events.append(
                FaceScanBehaviorReviewEvent(
                    id: "metric-\(item.id)",
                    sortDate: result.createdAt,
                    timeLabel: AppCopy.tSync("Ce scan", en: "This scan"),
                    systemImage: item.arrowSystemName,
                    title: metricRisingTitle(for: item.id),
                    detail: metricRisingDetail(for: item),
                    fix: metricFix(for: item.id),
                    isPositive: false
                )
            )
        }
    }

    @MainActor
    private static func metricRisingTitle(for metricID: String) -> String {
        switch metricID {
        case FaceScanIndicators.Kind.retention.id:
            return AppCopy.tSync("Rétention en hausse", en: "Retention rising")
        case FaceScanIndicators.Kind.recovery.id:
            return AppCopy.tSync("Fatigue visuelle en hausse", en: "Visual fatigue rising")
        case FaceScanIndicators.Kind.stressLoad.id:
            return AppCopy.tSync("Charge stress en hausse", en: "Stress load rising")
        case FaceScanIndicators.Kind.skin.id:
            return AppCopy.tSync("Peau en baisse", en: "Skin quality dropping")
        case FaceScanIndicators.Kind.definition.id:
            return AppCopy.tSync("Contours qui s'adoucissent", en: "Contours softening")
        default:
            return AppCopy.tSync("Signal en hausse", en: "Signal rising")
        }
    }

    @MainActor
    private static func metricRisingDetail(for item: FaceScanMetricDisplay.Item) -> String {
        let baseline = AppCopy.tSync("référence", en: "baseline")
        return "\(item.subtitle) — \(item.comparison) (\(item.deltaLabel) vs \(baseline))."
    }

    @MainActor
    private static func appendScanHistoryEvents(
        to events: inout [FaceScanBehaviorReviewEvent],
        result: FaceScanResult,
        previous: FaceScanResult?,
        now: Date
    ) {
        guard let previous else { return }

        let delta = result.displayWellnessScore - previous.displayWellnessScore
        if delta <= -5 {
            events.append(
                FaceScanBehaviorReviewEvent(
                    id: "scan-drop-\(previous.id)",
                    sortDate: previous.createdAt,
                    timeLabel: timeLabel(for: previous.createdAt, now: now),
                    systemImage: "arrow.down.right.circle.fill",
                    title: AppCopy.tSync("Score en baisse vs scan précédent", en: "Score down vs previous scan"),
                    detail: AppCopy.tSync(
                        "\(previous.displayWellnessScore) % → \(result.displayWellnessScore) % (\(delta)) — quelque chose dans ta routine récente ne passe pas.",
                        en: "\(previous.displayWellnessScore)% → \(result.displayWellnessScore)% (\(delta)) — something in your recent routine isn't landing."
                    ),
                    fix: AppCopy.tSync(
                        "Compare sommeil, sel et hydratation entre les deux jours.",
                        en: "Compare sleep, salt, and hydration between the two days."
                    ),
                    isPositive: false
                )
            )
        }
    }

    @MainActor
    private static func appendTrendEvents(
        to events: inout [FaceScanBehaviorReviewEvent],
        facts: FaceScanEvolutionFacts,
        now: Date
    ) {
        if facts.retentionPersistingScans >= 3 {
            events.append(
                FaceScanBehaviorReviewEvent(
                    id: "trend-retention-persist",
                    sortDate: now,
                    timeLabel: AppCopy.tSync("Sur \(facts.retentionPersistingScans) scans", en: "Over \(facts.retentionPersistingScans) scans"),
                    systemImage: "chart.line.uptrend.xyaxis",
                    title: AppCopy.tSync("Rétention qui dure", en: "Retention sticking around"),
                    detail: AppCopy.tSync(
                        "Gonflement au-dessus de ta référence depuis \(facts.retentionPersistingScans) scans d'affilée.",
                        en: "Puffiness above your baseline for \(facts.retentionPersistingScans) scans in a row."
                    ),
                    fix: AppCopy.tSync(
                        "Audit sel + eau sur 48 h, marche quotidienne, repas debloat stricts.",
                        en: "Audit salt + water for 48 h, daily walk, strict debloat meals."
                    ),
                    isPositive: false
                )
            )
        }

        if let trend = facts.retentionTrend, trend.direction == .rising {
            events.append(
                FaceScanBehaviorReviewEvent(
                    id: "trend-\(trend.kind.id)",
                    sortDate: now,
                    timeLabel: AppCopy.tSync("\(trend.spanDays) j", en: "\(trend.spanDays)d"),
                    systemImage: "arrow.up.forward",
                    title: trendRisingTitle(for: trend.kind),
                    detail: trend.label,
                    fix: AppCopy.tSync(
                        "Corrige l'hydratation avant de chercher ailleurs.",
                        en: "Fix hydration before looking elsewhere."
                    ),
                    isPositive: false
                )
            )
        }
    }

    @MainActor
    private static func trendRisingTitle(for kind: FaceScanIndicators.Kind) -> String {
        switch kind {
        case .retention:
            return AppCopy.tSync("Rétention qui monte", en: "Retention trending up")
        case .recovery:
            return AppCopy.tSync("Fatigue qui monte", en: "Fatigue trending up")
        case .stressLoad:
            return AppCopy.tSync("Stress qui monte", en: "Stress trending up")
        case .skin:
            return AppCopy.tSync("Peau qui se dégrade", en: "Skin trending down")
        case .definition:
            return AppCopy.tSync("Contours qui s'effacent", en: "Contours fading")
        }
    }

    @MainActor
    private static func appendCorrelationEvents(
        to events: inout [FaceScanBehaviorReviewEvent],
        facts: FaceScanEvolutionFacts,
        now: Date
    ) {
        for correlation in facts.correlations.prefix(2) {
            events.append(
                FaceScanBehaviorReviewEvent(
                    id: "correlation-\(correlation.id)",
                    sortDate: now,
                    timeLabel: AppCopy.tSync("Historique récent", en: "Recent history"),
                    systemImage: correlation.icon,
                    title: AppCopy.tSync("Pattern détecté", en: "Pattern detected"),
                    detail: correlation.message,
                    fix: AppCopy.tSync(
                        "Quand ce signal revient, applique la routine debloat complète.",
                        en: "When this signal returns, run the full debloat routine."
                    ),
                    isPositive: false
                )
            )
        }
    }

    @MainActor
    private static func appendCheckInEvents(
        to events: inout [FaceScanBehaviorReviewEvent],
        now: Date
    ) {
        let records = ProcessDebloatTrajectoryStore.shared.allRecordsByDay
        let sortedKeys = records.keys.sorted().suffix(6)

        for key in sortedKeys.reversed() {
            guard let record = records[key], record.checkInSubmitted else { continue }
            guard let date = dateFromDayKey(key) else { continue }
            let label = timeLabel(for: date, now: now)

            if record.water == false {
                events.append(
                    FaceScanBehaviorReviewEvent(
                        id: "checkin-water-\(key)",
                        sortDate: date,
                        timeLabel: label,
                        systemImage: "drop.triangle.fill",
                        title: AppCopy.tSync("Eau non validée", en: "Water not checked off"),
                        detail: AppCopy.tSync(
                            "Check-in du soir : tu n'as pas atteint ta cible d'hydratation ce jour-là.",
                            en: "Evening check-in: you didn't hit your hydration target that day."
                        ),
                        fix: AppCopy.tSync(
                            "Programme des rappels eau dans la matinée.",
                            en: "Schedule water reminders in the morning."
                        ),
                        isPositive: false
                    )
                )
            }

            if record.debloatMeal == false {
                events.append(
                    FaceScanBehaviorReviewEvent(
                        id: "checkin-meal-\(key)",
                        sortDate: date,
                        timeLabel: label,
                        systemImage: "fork.knife.circle",
                        title: AppCopy.tSync("Repas debloat manqué", en: "Debloat meal missed"),
                        detail: AppCopy.tSync(
                            "Le repas anti-gonflement du plan n'a pas été suivi — sodium et inflammation remontent vite.",
                            en: "You skipped the plan's anti-puff meal — sodium and inflammation bounce back fast."
                        ),
                        fix: AppCopy.tSync(
                            "Prépare le repas debloat à l'avance ou choisis l'option la plus simple du plan.",
                            en: "Prep the debloat meal ahead or pick the plan's simplest option."
                        ),
                        isPositive: false
                    )
                )
            }

            if record.cardio == false {
                events.append(
                    FaceScanBehaviorReviewEvent(
                        id: "checkin-cardio-\(key)",
                        sortDate: date,
                        timeLabel: label,
                        systemImage: "figure.run.circle",
                        title: AppCopy.tSync("Cardio / marche manquée", en: "Cardio / walk missed"),
                        detail: AppCopy.tSync(
                            "Peu de drainage ce jour-là — la rétention d'eau a plus de chances de rester.",
                            en: "Low drainage that day — water retention is more likely to stick."
                        ),
                        fix: AppCopy.tSync(
                            "10–15 min de marche après le repas du midi suffisent.",
                            en: "10–15 min walking after lunch is enough."
                        ),
                        isPositive: false
                    )
                )
            }

            if record.verdict == .regression || record.verdict == .missed {
                events.append(
                    FaceScanBehaviorReviewEvent(
                        id: "checkin-verdict-\(key)",
                        sortDate: date,
                        timeLabel: label,
                        systemImage: "arrow.uturn.backward.circle.fill",
                        title: record.verdict.shortLabel,
                        detail: record.aiSummary ?? AppCopy.tSync(
                            "Journée en dessous de ta trajectoire debloat.",
                            en: "Day below your debloat trajectory."
                        ),
                        fix: AppCopy.tSync(
                            "Reviens aux bases : eau, repas plan, marche, scan demain.",
                            en: "Back to basics: water, plan meals, walk, scan tomorrow."
                        ),
                        isPositive: false
                    )
                )
            }
        }
    }

    @MainActor
    private static func appendPlanEvents(
        to events: inout [FaceScanBehaviorReviewEvent],
        now: Date
    ) {
        let negativeReasons: Set<PlanDurationEvolutionReason> = [
            .consecutiveMisses,
            .cardioConsecutiveMisses,
            .cardioWeeklyDeficit,
            .regressionPattern
        ]

        for event in ProcessPlanProgressStore.shared.recentEvolutionEvents.prefix(4) {
            guard negativeReasons.contains(event.reason) else { continue }
            events.append(
                FaceScanBehaviorReviewEvent(
                    id: "plan-\(event.id)",
                    sortDate: event.createdAt,
                    timeLabel: timeLabel(for: event.createdAt, now: now),
                    systemImage: event.reason.systemImage,
                    title: planEventTitle(for: event.reason),
                    detail: event.message,
                    fix: planEventFix(for: event.reason),
                    isPositive: false
                )
            )
        }
    }

    // MARK: - Helpers

    private static var calendar: Calendar { Calendar.current }

    @MainActor
    private static func summaryLine(for insight: FaceScanAIInsight) -> String {
        if insight.primaryCause == .balanced {
            return AppCopy.tSync(
                "Peu d'erreurs visibles — continue la routine qui fonctionne.",
                en: "Few visible mistakes — keep the routine that's working."
            )
        }
        return AppCopy.tSync(
            "Voici ce qui coince, du plus récent au contexte des derniers jours.",
            en: "Here's what's off, from most recent back through the last few days."
        )
    }

    @MainActor
    private static func metricFix(for metricID: String) -> String {
        switch metricID {
        case FaceScanIndicators.Kind.retention.id:
            return AppCopy.tSync("Eau régulière + sel modéré aujourd'hui.", en: "Steady water + moderate salt today.")
        case FaceScanIndicators.Kind.recovery.id:
            return AppCopy.tSync("Sommeil plus tôt ce soir.", en: "Earlier sleep tonight.")
        case FaceScanIndicators.Kind.stressLoad.id:
            return AppCopy.tSync("Respiration nasale + marche douce.", en: "Nasal breathing + easy walk.")
        case FaceScanIndicators.Kind.skin.id:
            return AppCopy.tSync("Repas anti-inflammatoires, pas d'alcool.", en: "Anti-inflammatory meals, no alcohol.")
        case FaceScanIndicators.Kind.definition.id:
            return AppCopy.tSync("Drainage + mâchoire relâchée.", en: "Drainage + relaxed jaw.")
        default:
            return AppCopy.tSync("Reviens aux bases du plan aujourd'hui.", en: "Back to plan basics today.")
        }
    }

    @MainActor
    private static func planEventTitle(for reason: PlanDurationEvolutionReason) -> String {
        switch reason {
        case .consecutiveMisses:
            return AppCopy.tSync("Jours manqués d'affilée", en: "Consecutive missed days")
        case .cardioConsecutiveMisses:
            return AppCopy.tSync("Cardio manqué plusieurs jours", en: "Cardio missed several days")
        case .cardioWeeklyDeficit:
            return AppCopy.tSync("Cardio hebdo insuffisant", en: "Weekly cardio shortfall")
        case .regressionPattern:
            return AppCopy.tSync("Régression détectée", en: "Regression detected")
        default:
            return AppCopy.tSync("Ajustement du plan", en: "Plan adjustment")
        }
    }

    @MainActor
    private static func planEventFix(for reason: PlanDurationEvolutionReason) -> String {
        switch reason {
        case .consecutiveMisses:
            return AppCopy.tSync("Valide au minimum eau + repas ce soir.", en: "At minimum, check off water + meal tonight.")
        case .cardioConsecutiveMisses, .cardioWeeklyDeficit:
            return AppCopy.tSync("15 min de marche aujourd'hui, même fractionnées.", en: "15 min walking today, even split up.")
        case .regressionPattern:
            return AppCopy.tSync("Reprends le plan strict 3 jours.", en: "Run the plan strictly for 3 days.")
        default:
            return AppCopy.tSync("Suis la checklist du soir.", en: "Follow tonight's checklist.")
        }
    }

    private static func dedupeAndLimit(
        _ events: [FaceScanBehaviorReviewEvent],
        max: Int
    ) -> [FaceScanBehaviorReviewEvent] {
        var seen = Set<String>()
        var output: [FaceScanBehaviorReviewEvent] = []
        for event in events {
            let key = event.title.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            output.append(event)
            if output.count >= max { break }
        }
        return output
    }

    private static func timeLabel(for date: Date, now: Date) -> String {
        if calendar.isDateInToday(date) {
            let hour = calendar.component(.hour, from: date)
            if hour < 12 {
                return AppCopy.tSync("Ce matin", en: "This morning")
            }
            return date.formatted(date: .omitted, time: .shortened)
        }
        if calendar.isDateInYesterday(date) {
            return AppCopy.tSync("Hier", en: "Yesterday")
        }
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: calendar.startOfDay(for: now)
        ).day ?? 0
        if days <= 7 {
            return AppCopy.tSync("Il y a \(days) j", en: "\(days) days ago")
        }
        let formatter = DateFormatter()
        formatter.locale = ProcessAppLanguage.shared.locale
        formatter.setLocalizedDateFormatFromTemplate("d MMM")
        return formatter.string(from: date)
    }

    private static func dateFromDayKey(_ key: String) -> Date? {
        let parts = key.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else { return nil }
        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    private static func formatHours(_ value: Double) -> String {
        let hours = Int(value)
        let minutes = Int((value - Double(hours)) * 60)
        if minutes <= 0 { return AppCopy.tSync("\(hours) h", en: "\(hours) h") }
        return AppCopy.tSync("\(hours) h \(minutes)", en: "\(hours) h \(minutes)")
    }

    private static func formattedSteps(_ value: Int) -> String {
        let nf = NumberFormatter()
        nf.locale = ProcessAppLanguage.shared.locale
        nf.numberStyle = .decimal
        return nf.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
