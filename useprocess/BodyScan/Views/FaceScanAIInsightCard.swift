import SwiftUI

// MARK: - Modèle

enum FaceScanPrimaryCause: String, Equatable {
    case retention
    case cortisol
    case recovery
    case skin
    case definition
    case balanced
    case mixed
}

struct FaceScanInsightContext: Equatable {
    var sleepHours: Double?
    var hrv: Double?
    var steps: Int?
    var waterLiters: Double?
    var stepTarget: Int?
    var hydrationTargetLiters: Double?
    var sleepTargetHours: Double?

    @MainActor
    static func fromTodayHealth() -> FaceScanInsightContext {
        fromTodayHealth(.shared)
    }

    @MainActor
    static func fromTodayHealth(_ healthManager: HealthManager) -> FaceScanInsightContext {
        let targets = WelcomePlanStore.shared.plan?.personalizedTargets ?? .default
        let snap = healthManager.todaySnapshot
        return FaceScanInsightContext(
            sleepHours: snap.sleep.sleepDuration > 0 ? snap.sleep.sleepDuration : nil,
            hrv: snap.vitals.hrv > 0 ? snap.vitals.hrv : nil,
            steps: snap.effort.steps > 0 ? snap.effort.steps : nil,
            waterLiters: snap.nutrition.waterLiters > 0 ? snap.nutrition.waterLiters : nil,
            stepTarget: targets.dailySteps,
            hydrationTargetLiters: Double(targets.hydrationLitersPerDay),
            sleepTargetHours: targets.sleepHours
        )
    }
}

struct FaceScanAIInsight: Equatable {
    let emoji: String
    let title: String
    let body: String
    let accent: Color
    let primaryCause: FaceScanPrimaryCause
    let coachPrompt: String
}

// MARK: - Builder intelligent

enum FaceScanAIInsightBuilder {
    static func insight(
        for result: FaceScanResult,
        context: FaceScanInsightContext = FaceScanInsightContext()
    ) -> FaceScanAIInsight {
        let diagnosis = diagnose(result: result, context: context)
        let accent = accentColor(for: diagnosis.primaryCause, result: result)
        let body = resolvedBody(from: diagnosis, result: result)

        return FaceScanAIInsight(
            emoji: diagnosis.emoji,
            title: diagnosis.title,
            body: body,
            accent: accent,
            primaryCause: diagnosis.primaryCause,
            coachPrompt: diagnosis.coachPrompt
        )
    }

    private static func resolvedBody(from diagnosis: Diagnosis, result: FaceScanResult) -> String {
        if let coachText = result.coachInsightMessage?.trimmingCharacters(in: .whitespacesAndNewlines),
           !coachText.isEmpty {
            let preview = FaceScanCoachInsightService.cardPreview(from: coachText)
            if !preview.isEmpty {
                return preview
            }
        }
        return diagnosis.body
    }

    // MARK: Diagnosis

    private struct Diagnosis {
        let primaryCause: FaceScanPrimaryCause
        let title: String
        let body: String
        let emoji: String
        let coachPrompt: String
    }

    private struct CauseScore {
        let cause: FaceScanPrimaryCause
        let score: Double
    }

    private static func diagnose(
        result: FaceScanResult,
        context: FaceScanInsightContext
    ) -> Diagnosis {
        let scores = rankedCauseScores(for: result)
        let health = healthContext(result: result, context: context)
        let baselineNote = baselineContextNote(for: result)

        if isBalancedDay(result: result, scores: scores) {
            let title = "Visage en forme · \(result.displayWellnessScore)%"
            return Diagnosis(
                primaryCause: .balanced,
                title: title,
                body: balancedBody(health: health),
                emoji: "✨",
                coachPrompt: coachPrompt(
                    for: result,
                    primary: .balanced,
                    secondary: nil,
                    health: health,
                    baselineNote: baselineNote
                )
            )
        }

        let primary = scores[0].cause
        let secondary = closeSecondary(in: scores)
        let title = titledPrimary(primary, result: result)
        let body = narrativeBody(
            primary: primary,
            secondary: secondary,
            result: result,
            health: health
        )
        let emoji = emoji(for: primary)

        return Diagnosis(
            primaryCause: primary,
            title: title,
            body: body,
            emoji: emoji,
            coachPrompt: coachPrompt(
                for: result,
                primary: primary,
                secondary: secondary,
                health: health,
                baselineNote: baselineNote
            )
        )
    }

    private static func isBalancedDay(result: FaceScanResult, scores: [CauseScore]) -> Bool {
        guard FaceScanIndicators.compositeWellnessZone(for: result) == .optimal else { return false }
        guard let top = scores.first else { return true }
        return top.score < 40
    }

    private static func closeSecondary(in scores: [CauseScore]) -> FaceScanPrimaryCause? {
        guard scores.count >= 2 else { return nil }
        guard scores[0].score >= 42, scores[0].score - scores[1].score < 16 else { return nil }
        return scores[1].cause
    }

    private static func titledPrimary(_ cause: FaceScanPrimaryCause, result: FaceScanResult) -> String {
        let value = metricValue(for: cause, result: result)
        switch cause {
        case .retention: return "Rétention d'eau · \(value)%"
        case .cortisol: return "Cortisol estimé · \(value)%"
        case .recovery: return "Cernes et fatigue · \(value)%"
        case .skin: return "Qualité de peau · \(value)%"
        case .definition: return "Définition faciale · \(value)%"
        case .balanced: return "Visage en forme · \(value)%"
        case .mixed: return "Signaux visage · \(value)%"
        }
    }

    private static func metricValue(for cause: FaceScanPrimaryCause, result: FaceScanResult) -> Int {
        switch cause {
        case .retention:
            return FaceScanIndicators.displayPercent(for: .retention, result: result)
        case .cortisol:
            return FaceScanIndicators.displayPercent(for: .stressLoad, result: result)
        case .recovery:
            return FaceScanIndicators.displayPercent(for: .recovery, result: result)
        case .skin:
            return FaceScanIndicators.displayPercent(for: .skin, result: result)
        case .definition:
            return FaceScanIndicators.displayPercent(for: .definition, result: result)
        case .balanced, .mixed:
            return result.displayWellnessScore
        }
    }

    private static func narrativeBody(
        primary: FaceScanPrimaryCause,
        secondary: FaceScanPrimaryCause?,
        result: FaceScanResult,
        health: HealthContext
    ) -> String {
        let why: String
        let fix: String

        switch primary {
        case .retention:
            why = retentionWhy(health: health, result: result)
            fix = "Pour dégonfler vite : 400–500 ml d'eau maintenant, sel/processés limités au déjeuner, 15 min de marche."
        case .cortisol:
            why = cortisolWhy(health: health, result: result)
            fix = "Pour redescendre : 5 min de respiration nasale, pas de cardio intense ce soir, coucher plus tôt."
        case .recovery:
            why = recoveryWhy(health: health, result: result)
            fix = "Pour récupérer : pause 20 min sans écran, lumière douce ce soir, vise +45 min de sommeil."
        case .skin:
            why = skinWhy(health: health, result: result)
            fix = "Pour retrouver de l'éclat : eau régulière, repas anti-inflammatoires, pas d'alcool ni sucre ajouté."
        case .definition:
            why = definitionWhy(health: health, result: result)
            fix = "Pour retrouver les contours : dégonfle d'abord (eau + sel modéré), mâchoire relâchée, langue au palais."
        case .balanced:
            return balancedBody(health: health)
        case .mixed:
            why = "Plusieurs facteurs se cumulent sur ton visage ce matin — sommeil, stress ou alimentation d'hier."
            fix = "Commence par l'eau, le sel modéré et une vraie plage de sommeil ce soir."
        }

        if let secondary, primary != .mixed {
            let secondaryHint = shortSecondaryHint(secondary)
            return join([why, secondaryHint, fix])
        }

        return join([why, fix])
    }

    private static func retentionWhy(health: HealthContext, result: FaceScanResult) -> String {
        let load = metricValue(for: .retention, result: result)
        let severity = FaceScanIndicators.adverseFacePhrase(for: .retention, load: load)
        if health.sleepWasShort {
            return "Ton visage montre \(severity) — classique après \(health.sleepHoursLabel ?? "une nuit courte"), quand l'aldostérone reste élevée."
        }
        if health.hydrationWasLow {
            return "Gonflement matinal (\(load) % de rétention) : ton corps compense une hydratation basse en stockant l'eau en surface."
        }
        if let delta = delta(for: .retention, result: result), delta >= 6 {
            return "Tu es plus gonflé que d'habitude (\(load) %) — souvent sel, digestion lourde ou manque de sommeil."
        }
        return "Rétention à \(load) % : \(severity.capitalizedFirst) — joues et paupières en premier."
    }

    private static func cortisolWhy(health: HealthContext, result: FaceScanResult) -> String {
        let load = metricValue(for: .cortisol, result: result)
        let severity = FaceScanIndicators.adverseFacePhrase(for: .stressLoad, load: load)
        if health.hrvWasLow {
            return "Charge stress haute (\(load) %) : HRV basse, le système nerveux n'a pas totalement récupéré."
        }
        if health.sleepWasShort {
            return "\(severity.capitalizedFirst) — fréquent quand le sommeil est insuffisant ou fragmenté."
        }
        return "Ton visage montre \(severity) : gonflement, cernes ou mâchoire serrée combinés."
    }

    private static func recoveryWhy(health: HealthContext, result: FaceScanResult) -> String {
        let load = metricValue(for: .recovery, result: result)
        let severity = FaceScanIndicators.adverseFacePhrase(for: .recovery, load: load)
        if health.sleepWasShort {
            return "\(severity.capitalizedFirst) : \(health.sleepHoursLabel ?? "peu de sommeil") ne laisse pas le visage se régénérer."
        }
        if health.hrvWasLow {
            return "Récupération incomplète (\(load) %) — le visage trahit un système nerveux encore en alerte."
        }
        return "\(severity.capitalizedFirst) autour des yeux : drainage lymphatique ralenti, teint moins lumineux."
    }

    private static func skinWhy(health: HealthContext, result: FaceScanResult) -> String {
        if health.sleepWasShort {
            return "Peau terne : la régénération cutanée se fait surtout la nuit, et elle a été courte."
        }
        return "Texture moins nette — souvent inflammation légère, stress ou alimentation trop sucrée."
    }

    private static func definitionWhy(health: HealthContext, result: FaceScanResult) -> String {
        if metricValue(for: .retention, result: result) >= 55 {
            return "Mâchoire et pommettes noyées : la rétention masque ta structure faciale."
        }
        return "Contours mous ce matin — rétention, mâchoire tendue ou manque de drainage."
    }

    private static func shortSecondaryHint(_ secondary: FaceScanPrimaryCause) -> String {
        switch secondary {
        case .recovery: return "La fatigue joue aussi."
        case .cortisol: return "Le stress y contribue."
        case .retention: return "La rétention amplifie l'effet."
        case .skin: return "La peau en pâtit aussi."
        case .definition: return "Les contours en souffrent."
        case .balanced, .mixed: return ""
        }
    }

    private static func balancedBody(health: HealthContext) -> String {
        if health.sleepWasGood {
            return "Signaux stables ce matin — sommeil solide, visage reposé. Garde ta routine debloat du jour."
        }
        return "Bon équilibre facial aujourd'hui. Continue hydratation, repas du plan personnalisé et scan demain matin."
    }

    private static func emoji(for cause: FaceScanPrimaryCause) -> String {
        switch cause {
        case .retention: return "💧"
        case .cortisol: return "⚡️"
        case .recovery: return "🌙"
        case .skin: return "✨"
        case .definition: return "🧊"
        case .balanced: return "✨"
        case .mixed: return "📊"
        }
    }

    private static func rankedCauseScores(for result: FaceScanResult) -> [CauseScore] {
        let retention = adverseScore(
            value: FaceScanIndicators.displayPercent(for: .retention, result: result),
            delta: delta(for: .retention, result: result)
        )
        let recovery = adverseScore(
            value: FaceScanIndicators.displayPercent(for: .recovery, result: result),
            delta: delta(for: .recovery, result: result)
        )
        let cortisol = adverseScore(
            value: FaceScanIndicators.displayPercent(for: .stressLoad, result: result),
            delta: delta(for: .stressLoad, result: result)
        )
        let skin = adverseScore(
            value: 100 - FaceScanIndicators.displayPercent(for: .skin, result: result),
            delta: delta(for: .skin, result: result).map { -$0 }
        )
        let definition = adverseScore(
            value: 100 - FaceScanIndicators.displayPercent(for: .definition, result: result),
            delta: delta(for: .definition, result: result).map { -$0 }
        )

        return [
            CauseScore(cause: .retention, score: retention),
            CauseScore(cause: .recovery, score: recovery),
            CauseScore(cause: .cortisol, score: cortisol),
            CauseScore(cause: .skin, score: skin),
            CauseScore(cause: .definition, score: definition)
        ].sorted { $0.score > $1.score }
    }

    private static func adverseScore(value: Int, delta: Int?) -> Double {
        var score = Double(value)
        if let delta, delta > 0 {
            score += Double(delta) * 0.45
        }
        if value >= 72 { score += 8 }
        else if value >= 58 { score += 4 }
        return min(100, score)
    }

    private static func delta(for kind: FaceScanIndicators.Kind, result: FaceScanResult) -> Int? {
        guard let signals = result.relativeSignals,
              signals.baselineLabel != "Premier scan de référence" else { return nil }
        switch kind {
        case .retention: return signals.puffinessDelta
        case .recovery: return signals.underEyeFatigueDelta
        case .stressLoad: return signals.stressLoadDelta
        case .skin: return signals.skinClarityDelta
        case .definition: return signals.faceDefinitionDelta
        }
    }

    // MARK: Copy

    private struct HealthContext {
        var sleepHoursLabel: String?
        var sleepWasShort = false
        var sleepWasGood = false
        var hrvWasLow = false
        var hydrationWasLow = false
        var activityWasLow = false
    }

    private static func healthContext(
        result: FaceScanResult,
        context: FaceScanInsightContext
    ) -> HealthContext {
        var health = HealthContext()

        let sleep = result.sleepHoursAtScan ?? context.sleepHours
        let sleepTarget = context.sleepTargetHours ?? 7.5
        if let sleep, sleep > 0 {
            health.sleepHoursLabel = formatHours(sleep)
            health.sleepWasShort = sleep < sleepTarget - 0.5
            health.sleepWasGood = sleep >= sleepTarget
        }

        let hrv = result.hrvAtScan ?? context.hrv
        if let hrv, hrv > 0 {
            health.hrvWasLow = hrv < 40
        }

        if let steps = context.steps, steps > 0, let target = context.stepTarget, target > 0 {
            health.activityWasLow = steps < target / 2
        }

        if let water = context.waterLiters, water > 0,
           let target = context.hydrationTargetLiters, target > 0 {
            health.hydrationWasLow = water < target * 0.55
        }

        return health
    }

    private static func baselineContextNote(for result: FaceScanResult) -> String? {
        guard let count = result.baselineSampleCount, count < 5 else { return nil }
        if count <= 1 { return "Premier scan de référence." }
        return "Baseline en consolidation (\(count) scans)."
    }

    private static func coachPrompt(
        for result: FaceScanResult,
        primary: FaceScanPrimaryCause,
        secondary: FaceScanPrimaryCause?,
        health: HealthContext,
        baselineNote: String?
    ) -> String {
        let cardInsight = narrativeBody(
            primary: primary,
            secondary: secondary,
            result: result,
            health: health
        )
        var contextLines: [String] = [
            "Cause principale : \(label(for: primary)).",
            "Indicateur principal : \(metricValue(for: primary, result: result))%.",
            "Score global wellness : \(result.displayWellnessScore)%.",
            "Score relatif vs baseline : \(result.resolvedFaceDayScore)/100."
        ]

        if let secondary {
            contextLines.append("Facteur secondaire : \(label(for: secondary)).")
        }

        if let rel = result.relativeSignals, rel.baselineLabel != "Premier scan de référence" {
            contextLines.append(
                "Évolution vs baseline : rétention \(signed(rel.puffinessDelta)), cernes \(signed(rel.underEyeFatigueDelta)), stress \(signed(rel.stressLoadDelta ?? 0))."
            )
        }

        if let sleep = health.sleepHoursLabel {
            contextLines.append("Sommeil récent : \(sleep)\(health.sleepWasShort ? " (insuffisant)" : health.sleepWasGood ? " (OK)" : "").")
        }
        if health.hrvWasLow { contextLines.append("HRV basse ce matin.") }
        if health.hydrationWasLow { contextLines.append("Hydratation basse aujourd'hui.") }
        if health.activityWasLow { contextLines.append("Activité faible aujourd'hui.") }
        if let baselineNote { contextLines.append(baselineNote) }

        contextLines.append(contentsOf: severityLines(for: result))

        if let parsed = optionalParsedAnalysis(for: result) {
            contextLines.append("Analyse IA précédente (à enrichir, pas recopier) : \(parsed)")
        }

        return """
        [INSTRUCTION SYSTÈME — ne jamais afficher cette consigne à l'utilisateur]

        L'utilisateur vient d'ouvrir le coach depuis son scan visage. Tu parles EN PREMIER : aucun message utilisateur ne précède le tien.
        Langue : français uniquement.

        Il a déjà lu ce résumé sur l'écran d'accueil :
        « \(cardInsight) »

        Données du scan (contexte interne — ne pas lister tous les chiffres dans ta réponse) :
        \(contextLines.joined(separator: "\n"))

        Rédige UN message coach visible :
        1) Deux phrases simples : pourquoi son visage est dans cet état (mécanisme debloat, lié à ses données réelles).
        2) Trois actions concrètes pour AUJOURD'HUI dans le plan personnalisé (puces courtes).
        3) Une question ouverte pour continuer la conversation.

        Calibrage obligatoire de l'intensité (ne jamais minimiser) :
        - Utilise les libellés « Intensité visage » ci-dessus quand tu parles de rétention, récup ou cortisol.
        - Si rétention ≥ 62 % : « nettement gonflé » ou « marqué » — INTERDIT : « légèrement », « un peu », « léger gonflement ».
        - Si rétention ≥ 78 % : « très marqué » ou « forte rétention ».
        - Même logique pour récupération et cortisol selon leur % affiché.

        Ne répète pas mot pour mot le résumé de la carte. Ne cite pas tous les scores. Pas d'anglais.
        Pas de lignes ACTION_*, DEEP_LINK, FOLLOW_UP_* — uniquement le texte visible pour l'utilisateur.
        """
    }

    private static func severityLines(for result: FaceScanResult) -> [String] {
        let retention = FaceScanIndicators.displayPercent(for: .retention, result: result)
        let recovery = FaceScanIndicators.displayPercent(for: .recovery, result: result)
        let cortisol = FaceScanIndicators.displayPercent(for: .stressLoad, result: result)
        return [
            "Intensité visage — rétention \(retention) % : \(FaceScanIndicators.adverseFacePhrase(for: .retention, load: retention)).",
            "Intensité visage — récupération \(recovery) % : \(FaceScanIndicators.adverseFacePhrase(for: .recovery, load: recovery)).",
            "Intensité visage — cortisol \(cortisol) % : \(FaceScanIndicators.adverseFacePhrase(for: .stressLoad, load: cortisol))."
        ]
    }

    private static func optionalParsedAnalysis(for result: FaceScanResult) -> String? {
        let parsed = CoachEngine.parsedFaceAnalysis(for: result)
        if parsed.isValid, !parsed.summary.isEmpty {
            return truncated(parsed.summary, max: 140)
        }
        if let raw = result.claudeAnalysis?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
            return truncated(FaceScanAnalysisParser.sanitize(raw), max: 140)
        }
        return nil
    }

    // MARK: Helpers

    private static func accentColor(for cause: FaceScanPrimaryCause, result: FaceScanResult) -> Color {
        switch cause {
        case .balanced:
            return FaceScanWhoopPalette.ringColor(for: .optimal)
        case .mixed:
            return FaceScanWhoopPalette.sufficient
        case .retention:
            return Color.orange.opacity(0.92)
        case .cortisol:
            return Color.red.opacity(0.82)
        case .recovery:
            return Color.purple.opacity(0.82)
        case .skin:
            return Color.mint.opacity(0.88)
        case .definition:
            return Color.cyan.opacity(0.88)
        }
    }

    private static func label(for cause: FaceScanPrimaryCause) -> String {
        switch cause {
        case .retention: return "rétention d'eau"
        case .cortisol: return "charge cortisol"
        case .recovery: return "récupération insuffisante"
        case .skin: return "qualité de peau"
        case .definition: return "définition faciale"
        case .balanced: return "équilibre global"
        case .mixed: return "signaux mixtes"
        }
    }

    private static func signed(_ value: Int) -> String {
        value >= 0 ? "+\(value)" : "\(value)"
    }

    private static func join(_ parts: [String]) -> String {
        truncated(parts.joined(separator: " "), max: 260)
    }

    private static func truncated(_ text: String, max: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > max else { return trimmed }
        let end = trimmed.index(trimmed.startIndex, offsetBy: max)
        return String(trimmed[..<end]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    private static func formatHours(_ hours: Double) -> String {
        let totalMinutes = Int((hours * 60).rounded())
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        return m == 0 ? "\(h) h" : "\(h) h \(String(format: "%02d", m))"
    }

    private static func formatLiters(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}

private extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}

// MARK: - Footer intégré (Plan — style Bevel)

struct FaceScanAIInsightFooter: View {
    @Environment(\.appTheme) private var theme

    let insight: FaceScanAIInsight
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                topGlowLine
                content
            }
            .background(PlanFaceScanChrome.insightFooterFill(isDark: theme.isDark))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(insight.title). \(insight.body)")
        .accessibilityHint("Ouvrir l'analyse du dernier scan")
    }

    private var topGlowLine: some View {
        ZStack {
            LinearGradient(
                colors: [
                    PlanFaceScanChrome.luminousBlue.opacity(0),
                    PlanFaceScanChrome.luminousBlueGlow.opacity(0.82),
                    PlanFaceScanChrome.luminousBlue.opacity(0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 1.5)

        }
        .padding(.horizontal, 28)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(insight.emoji) \(insight.title)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 4)

                Image(systemName: "arrow.up.forward")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.secondaryText.opacity(0.72))
                    .alignmentGuide(.firstTextBaseline) { dimensions in
                        dimensions[.bottom] - 1
                    }
            }

            Text(insight.body)
                .font(.system(size: 13.5, weight: .regular))
                .foregroundStyle(theme.secondaryText)
                .lineSpacing(3)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 14)
    }

}

// MARK: - Carte standalone (écran résultats WHOOP)

struct FaceScanAIInsightCard: View {
    @Environment(\.appTheme) private var theme

    let insight: FaceScanAIInsight
    var style: FaceScanAIInsightStyle = .whoopDark
    var animateReveal: Bool = false
    var onTap: (() -> Void)? = nil

    @State private var isVisible = false

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
    }

    var body: some View {
        Group {
            if let onTap {
                Button(action: onTap) { cardContent }
                    .buttonStyle(.plain)
            } else {
                cardContent
            }
        }
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 8)
        .onAppear(perform: syncVisibility)
    }

    private var cardContent: some View {
        VStack(spacing: 0) {
            topGlowLine
            innerContent
        }
        .background(cardBackground)
        .clipShape(cardShape)
        .processHomeGlassCardShadow(isDark: theme.isDark)
    }

    private var topGlowLine: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [
                        insight.accent.opacity(0),
                        insight.accent.opacity(0.85),
                        insight.accent.opacity(0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 2)
            .padding(.horizontal, 36)
            .padding(.top, 1)
    }

    private var innerContent: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(insight.emoji)
                .font(.system(size: 18))

            VStack(alignment: .leading, spacing: 8) {
                Text(insight.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(titleColor)

                Text(insight.body)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(secondaryColor)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if onTap != nil {
                Image(systemName: "arrow.up.forward")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(secondaryColor.opacity(0.72))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private var cardBackground: some View {
        switch style {
        case .whoopDark:
            if theme.isDark {
                cardShape.fill(FaceScanWhoopPalette.card.opacity(0.92))
            } else {
                cardShape
                    .fill(.clear)
                    .processGlassEffect(in: cardShape, interactive: false)
            }
        }
    }

    private var titleColor: Color {
        switch style {
        case .whoopDark: return FaceScanWhoopPalette.label
        }
    }

    private var secondaryColor: Color {
        switch style {
        case .whoopDark: return FaceScanWhoopPalette.secondary
        }
    }

    private func syncVisibility() {
        guard animateReveal else {
            isVisible = true
            return
        }
        isVisible = false
        Task {
            try? await Task.sleep(for: .milliseconds(320))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.32)) {
                    isVisible = true
                }
            }
        }
    }
}

enum FaceScanAIInsightStyle {
    case whoopDark
}
