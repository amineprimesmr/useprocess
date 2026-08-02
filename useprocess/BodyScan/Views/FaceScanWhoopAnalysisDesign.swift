import SwiftUI

// MARK: - Tokens WHOOP

enum FaceScanWhoopPalette {
    static let canvas = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.04, green: 0.04, blue: 0.045, alpha: 1)
            : UIColor(red: 0.968, green: 0.972, blue: 0.988, alpha: 1)
    })

    static let card = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.11, green: 0.11, blue: 0.115, alpha: 1)
            : UIColor.secondarySystemGroupedBackground
    })

    static let ringTrack = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.10)
            : UIColor.label.withAlphaComponent(0.12)
    })

    static let label = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.92)
            : UIColor.label.withAlphaComponent(0.92)
    })

    static let secondary = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.55)
            : UIColor.secondaryLabel.withAlphaComponent(0.88)
    })

    static let segmentIdle = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.14)
            : UIColor.label.withAlphaComponent(0.12)
    })

    static let insufficient = Color(red: 0.93, green: 0.52, blue: 0.28)
    static let sufficient = Color(red: 0.95, green: 0.78, blue: 0.22)
    static let optimal = Color(red: 0.36, green: 0.78, blue: 0.58)

    static func ringColor(for zone: FaceScanIndicators.WellnessZone) -> Color {
        switch zone {
        case .insufficient: return insufficient
        case .sufficient: return sufficient
        case .optimal: return optimal
        }
    }
}

enum FaceScanWhoopDateLabel {
    static func header(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "EEEE d MMMM"
        return formatter.string(from: date)
    }

    static func historyRow(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "EEEE d MMMM · HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Écran principal

struct FaceScanWhoopAnalysisScreen: View {
    let result: FaceScanResult
    var previous: FaceScanResult?
    var history: [FaceScanResult] = []
    var showsDoneButton: Bool = false
    var doneButtonTitle: String = "Terminer"
    var onDone: (() -> Void)?
    var bottomContentInset: CGFloat = 40

    @Environment(\.dismiss) private var dismiss
    @Bindable private var historyStore = FaceScanHistoryStore.shared
    @State private var showsAnalysisInfo = false

    private var displayResult: FaceScanResult {
        historyStore.history.first(where: { $0.id == result.id }) ?? result
    }

    private var resolvedHistory: [FaceScanResult] {
        history.isEmpty ? historyStore.history : history
    }

    private var previousForDisplay: FaceScanResult? {
        resolvedHistory
            .filter { $0.id != displayResult.id && $0.createdAt < displayResult.createdAt }
            .sorted { $0.createdAt > $1.createdAt }
            .first
    }

    private var evolutionHistory: [FaceScanResult] {
        FaceScanWhoopEvolutionHistory.resolve(
            from: resolvedHistory,
            ensuring: displayResult
        )
    }

    var body: some View {
        ZStack {
            FaceScanWhoopPalette.canvas.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    headerBar
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 18)

                    FaceScanWhoopScoreRing(result: displayResult)
                        .padding(.bottom, 22)

                    FaceScanWhoopMetricsCard(result: displayResult, previous: previousForDisplay)
                        .padding(.horizontal, 16)

                    FaceScanWhoopEvolutionSummaryCard(
                        result: displayResult,
                        previous: previousForDisplay,
                        history: evolutionHistory
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                    FaceScanWhoopIndicatorTrendsSection(history: evolutionHistory)
                        .padding(.horizontal, 16)
                        .padding(.top, 28)

                    Spacer(minLength: bottomContentInset)
                }
            }
        }
        .sheet(isPresented: $showsAnalysisInfo) {
            FaceScanWhoopAnalysisInfoSheet(
                result: displayResult,
                history: resolvedHistory
            )
        }
    }

    private var headerBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(FaceScanWhoopPalette.label)
                    .frame(width: 44, height: 44, alignment: .leading)
            }
            .opacity(showsDoneButton ? 0 : 1)
            .disabled(showsDoneButton)

            Spacer()

            Text(formattedHeaderDate)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(FaceScanWhoopPalette.label)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer()

            if showsDoneButton {
                if let onDone, !doneButtonTitle.isEmpty {
                    Button(doneButtonTitle, action: onDone)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(FaceScanWhoopPalette.label)
                        .frame(minWidth: 44, alignment: .trailing)
                } else {
                    Color.clear.frame(width: 44, height: 44)
                }
            } else {
                Button {
                    showsAnalysisInfo = true
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(FaceScanWhoopPalette.label)
                        .frame(width: 44, height: 44, alignment: .trailing)
                }
                .accessibilityLabel("Historique des scans")
            }
        }
    }

    private var formattedHeaderDate: String {
        FaceScanWhoopDateLabel.header(for: result.createdAt)
    }
}

enum FaceScanWhoopResultsStyle {
    case immersive
    case chatThread
}

/// Corps résultats WHOOP — réutilisable dans le flux d'analyse inline.
struct FaceScanWhoopInlineResults: View {
    let result: FaceScanResult
    var history: [FaceScanResult] = []
    var showsTrends: Bool = true
    var ringScale: CGFloat = 1
    var style: FaceScanWhoopResultsStyle = .immersive

    @Bindable private var historyStore = FaceScanHistoryStore.shared

    private var displayResult: FaceScanResult {
        historyStore.history.first(where: { $0.id == result.id }) ?? result
    }

    private var resolvedHistory: [FaceScanResult] {
        history.isEmpty ? historyStore.history : history
    }

    private var previousForDisplay: FaceScanResult? {
        resolvedHistory
            .filter { $0.id != displayResult.id && $0.createdAt < displayResult.createdAt }
            .sorted { $0.createdAt > $1.createdAt }
            .first
    }

    private var evolutionHistory: [FaceScanResult] {
        FaceScanWhoopEvolutionHistory.resolve(
            from: resolvedHistory,
            ensuring: displayResult
        )
    }

    private var metricsHorizontalPadding: CGFloat {
        style == .chatThread ? 0 : 16
    }

    var body: some View {
        VStack(spacing: 0) {
            FaceScanWhoopScoreRing(result: displayResult)
                .scaleEffect(ringScale)
                .padding(.bottom, 22 * ringScale)

            FaceScanWhoopMetricsCard(result: displayResult, previous: previousForDisplay, style: style)
                .padding(.horizontal, metricsHorizontalPadding)

            if style == .immersive {
                FaceScanWhoopEvolutionSummaryCard(
                    result: displayResult,
                    previous: previousForDisplay,
                    history: evolutionHistory
                )
                .padding(.horizontal, 16)
                .padding(.top, 14)
            }

            if showsTrends {
                FaceScanWhoopIndicatorTrendsSection(history: evolutionHistory)
                    .padding(.horizontal, 16)
                    .padding(.top, 28)
            }

            Spacer(minLength: showsTrends ? 40 : (style == .chatThread ? 0 : 12))
        }
        .environment(\.faceScanResultsAnimateReveal, true)
    }
}

// MARK: - Anneau + photo

struct FaceScanWhoopScoreRing: View {
    @Environment(\.faceScanResultsAnimateReveal) private var animateReveal

    let result: FaceScanResult

    @State private var animatedProgress: Double = 0
    @State private var displayedScore: Int = 0
    @State private var contentVisible = true
    @State private var scoreCountTask: Task<Void, Never>?

    private let ringSize: CGFloat = 300
    private let strokeWidth: CGFloat = 11

    private var innerDiameter: CGFloat {
        ringSize - strokeWidth * 2
    }

    private var displayScore: Int {
        result.displayWellnessScore
    }

    private var scoreZone: FaceScanIndicators.WellnessZone {
        FaceScanIndicators.compositeWellnessZone(for: result)
    }

    private var progress: Double {
        Double(displayScore) / 100.0
    }

    private var ringProgressColor: Color {
        FaceScanWhoopPalette.ringColor(for: scoreZone)
    }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                ZStack(alignment: .bottom) {
                    FaceScanWhoopCircularPhoto(result: result)
                        .frame(width: innerDiameter, height: innerDiameter)
                        .clipShape(Circle())

                    LinearGradient(
                        colors: [.clear, .black.opacity(0.72)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .clipShape(Circle())

                    VStack(spacing: 2) {
                        Text("\(displayedScore)%")
                            .font(.system(size: 46, weight: .bold))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                            .contentTransition(.numericText())

                        Text("SCORE GLOBAL")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.82))
                            .tracking(1.2)
                    }
                    .padding(.bottom, 22)
                }
                .frame(width: innerDiameter, height: innerDiameter)
                .clipShape(Circle())

                Circle()
                    .stroke(FaceScanWhoopPalette.ringTrack, lineWidth: strokeWidth)
                    .frame(width: ringSize, height: ringSize)

                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(
                        ringProgressColor,
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                    )
                    .frame(width: ringSize, height: ringSize)
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: ringSize, height: ringSize)
            .scaleEffect(contentVisible ? 1 : 0.96)
            .opacity(contentVisible ? 1 : 0)
        }
        .frame(maxWidth: .infinity)
        .onAppear(perform: syncRevealState)
        .onChange(of: result.id) { _, _ in
            syncRevealState()
        }
        .onDisappear {
            scoreCountTask?.cancel()
        }
    }

    private func syncRevealState() {
        scoreCountTask?.cancel()

        guard animateReveal else {
            animatedProgress = progress
            displayedScore = displayScore
            contentVisible = true
            return
        }

        animatedProgress = 0
        displayedScore = 0
        contentVisible = false

        withAnimation(FaceScanWhoopRevealTiming.contentEase) {
            contentVisible = true
        }

        withAnimation(FaceScanWhoopRevealTiming.ringSpring) {
            animatedProgress = progress
        }

        scoreCountTask = Task {
            let target = displayScore
            let steps = max(12, min(28, target / 3 + 8))
            for step in 1...steps {
                try? await Task.sleep(nanoseconds: FaceScanWhoopRevealTiming.scoreStepMs * 1_000_000)
                guard !Task.isCancelled else { return }
                let value = Int((Double(target) * Double(step) / Double(steps)).rounded())
                await MainActor.run {
                    displayedScore = value
                }
            }
            await MainActor.run {
                displayedScore = target
            }
        }
    }
}

private struct FaceScanWhoopCircularPhoto: View {
    let result: FaceScanResult

    @State private var resolvedVideoURL: URL?
    @State private var snapshot: UIImage?
    @State private var mediaRefreshToken = 0

    var body: some View {
        Group {
            if let url = resolvedVideoURL {
                FaceScanSilentVideoLoopView(url: url)
            } else if let snapshot {
                Image(uiImage: snapshot)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .overlay {
                        Image(systemName: "face.smiling")
                            .font(.system(size: 44, weight: .light))
                            .foregroundStyle(FaceScanWhoopPalette.secondary)
                    }
            }
        }
        .id("\(result.id)-media-\(mediaRefreshToken)")
        .onAppear(perform: refreshMedia)
        .onChange(of: result.id) { _, _ in
            refreshMedia()
        }
        .onChange(of: result.videoFilename) { _, _ in refreshMedia() }
        .onChange(of: result.snapshotFilename) { _, _ in refreshMedia() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            refreshMedia()
        }
        .task(id: result.id) {
            await resolveVideoWithRetry()
        }
    }

    private func refreshMedia() {
        let reconciled = FaceScanImageStore.reconcileMediaMetadata(for: result)
        resolvedVideoURL = FaceScanImageStore.resolvedVideoURL(for: reconciled)
        if let filename = FaceScanImageStore.resolvedSnapshotFilename(for: reconciled) {
            snapshot = FaceScanImageStore.load(filename: filename)
        } else {
            snapshot = nil
        }
        if resolvedVideoURL == nil, snapshot == nil {
            mediaRefreshToken &+= 1
        }
    }

    private func resolveVideoWithRetry() async {
        for _ in 0..<24 {
            let reconciled = FaceScanImageStore.reconcileMediaMetadata(for: result)
            if let url = FaceScanImageStore.resolvedVideoURL(for: reconciled) {
                resolvedVideoURL = url
                return
            }
            try? await Task.sleep(for: .milliseconds(180))
        }
    }
}

// MARK: - Carte métriques

private struct FaceScanWhoopMetricsCard: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.faceScanResultsAnimateReveal) private var animateReveal

    let result: FaceScanResult
    var previous: FaceScanResult?
    var style: FaceScanWhoopResultsStyle = .immersive

    @State private var cardVisible = true
    @State private var revealedMetricCount = FaceScanIndicators.Kind.allCases.count
    @State private var revealTask: Task<Void, Never>?

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
    }

    private var metricKinds: [FaceScanIndicators.Kind] {
        FaceScanIndicators.Kind.allCases
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(metricKinds.enumerated()), id: \.element.id) { index, kind in
                FaceScanWhoopMetricRow(
                    kind: kind,
                    result: result,
                    previous: previous,
                    style: style,
                    isRevealed: !animateReveal || index < revealedMetricCount,
                    animatesCount: animateReveal
                )
                .padding(.horizontal, style == .chatThread ? 0 : 16)
                .padding(.vertical, style == .chatThread ? 11 : 14)
                .opacity(index < revealedMetricCount ? 1 : 0)
                .offset(y: index < revealedMetricCount ? 0 : (style == .chatThread ? 14 : 10))
                .scaleEffect(
                    index < revealedMetricCount ? 1 : (style == .chatThread ? 0.97 : 1),
                    anchor: .leading
                )
                .animation(
                    FaceScanWhoopRevealTiming.contentEase,
                    value: revealedMetricCount
                )

                if index < metricKinds.count - 1 {
                    Divider()
                        .overlay(dividerColor)
                        .padding(.leading, style == .chatThread ? 34 : 52)
                        .opacity(index < revealedMetricCount ? 1 : 0)
                }
            }

            if style == .immersive {
                legend
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 16)
                    .opacity(cardVisible ? 1 : 0)
            }
        }
        .background { metricsBackground }
        .clipShape(RoundedRectangle(cornerRadius: style == .immersive ? 30 : 0, style: .continuous))
        .modifier(FaceScanWhoopMetricsCardChrome(style: style, isDark: theme.isDark))
        .opacity(cardVisible ? 1 : 0)
        .offset(y: cardVisible ? 0 : (style == .chatThread ? 8 : 14))
        .onAppear(perform: syncRevealState)
        .onChange(of: result.id) { _, _ in
            syncRevealState()
        }
        .onDisappear {
            revealTask?.cancel()
        }
    }

    private var dividerColor: Color {
        style == .chatThread
            ? OnboardingTheme.softBorder.opacity(0.35)
            : (theme.isDark ? Color.white.opacity(0.08) : Color.primary.opacity(0.08))
    }

    @ViewBuilder
    private var metricsBackground: some View {
        if style == .immersive {
            cardShape
                .fill(.clear)
                .processGlassEffect(in: cardShape, interactive: false)
        }
    }

    private func syncRevealState() {
        revealTask?.cancel()

        guard animateReveal else {
            cardVisible = true
            revealedMetricCount = metricKinds.count
            return
        }

        cardVisible = false
        revealedMetricCount = 0

        let startDelay = FaceScanWhoopRevealTiming.metricsStartDelay(for: style)
        let stagger = FaceScanWhoopRevealTiming.metricStagger(for: style)

        revealTask = Task {
            try? await Task.sleep(for: .milliseconds(Int(startDelay * 1000)))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                withAnimation(FaceScanWhoopRevealTiming.contentEase) {
                    cardVisible = true
                }
            }

            for index in 1...metricKinds.count {
                try? await Task.sleep(nanoseconds: UInt64(stagger * 1_000_000_000))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    withAnimation(FaceScanWhoopRevealTiming.contentEase) {
                        revealedMetricCount = index
                    }
                }
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 18) {
            legendItem(color: FaceScanWhoopPalette.insufficient, title: FaceScanIndicators.WellnessZone.insufficient.title)
            legendItem(color: FaceScanWhoopPalette.sufficient, title: FaceScanIndicators.WellnessZone.sufficient.title)
            legendItem(color: FaceScanWhoopPalette.optimal, title: FaceScanIndicators.WellnessZone.optimal.title)
            Spacer(minLength: 0)
        }
    }

    private func legendItem(color: Color, title: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(color)
                .frame(width: 12, height: 2)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(FaceScanWhoopPalette.secondary)
        }
    }
}

private struct FaceScanWhoopMetricsCardChrome: ViewModifier {
    let style: FaceScanWhoopResultsStyle
    let isDark: Bool

    func body(content: Content) -> some View {
        if style == .immersive {
            content.processHomeGlassCardShadow(isDark: isDark)
        } else {
            content
        }
    }
}

/// Historique pour les blocs d’évolution UI — inclut le scan courant même s’il est onboarding.
private enum FaceScanWhoopEvolutionHistory {
    static func resolve(from history: [FaceScanResult], ensuring current: FaceScanResult) -> [FaceScanResult] {
        var scans = FaceScanEvolutionEngine.dailyHistory(from: history)
        if scans.isEmpty {
            scans = history
        }
        if !scans.contains(where: { $0.id == current.id }) {
            scans.append(current)
        }
        return scans.sorted { $0.createdAt < $1.createdAt }
    }
}

private struct FaceScanWhoopEvolutionSummaryCard: View {
    @Environment(\.appTheme) private var theme

    let result: FaceScanResult
    var previous: FaceScanResult?
    var history: [FaceScanResult] = []

    private var context: FaceScanInsightContext {
        FaceScanInsightContext.fromTodayHealth()
    }

    /// Toutes les métriques — visibles dès le 1er scan pour préparer le suivi.
    private var items: [FaceScanMetricDisplay.Item] {
        FaceScanMetricDisplay.items(for: result, previous: previous)
    }

    private var baselineBadge: String {
        if previous == nil || result.relativeSignals?.baselineLabel == "Premier scan de référence" {
            return "Point de départ"
        }
        return result.relativeSignals?.baselineLabel ?? "Référence en cours"
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Ce qui change")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(FaceScanWhoopPalette.label)

                Spacer()

                Text(baselineBadge)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(FaceScanWhoopPalette.secondary)
                    .lineLimit(1)
            }

            Text(FaceScanMetricDisplay.evolutionSentence(
                for: result,
                previous: previous,
                history: history,
                context: context
            ))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(FaceScanWhoopPalette.secondary)
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ],
                spacing: 8
            ) {
                ForEach(items) { item in
                    FaceScanWhoopEvolutionPill(item: item)
                }
            }

            Text(FaceScanMetricDisplay.actionSentence(
                for: result,
                previous: previous,
                history: history,
                waterLiters: context.waterLiters,
                hydrationTargetLiters: context.hydrationTargetLiters
            ))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(FaceScanWhoopPalette.label.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background {
            cardShape
                .fill(.clear)
                .processGlassEffect(in: cardShape, interactive: false)
        }
        .clipShape(cardShape)
        .processHomeGlassCardShadow(isDark: theme.isDark)
    }
}

private struct FaceScanWhoopEvolutionPill: View {
    let item: FaceScanMetricDisplay.Item

    private var tint: Color {
        switch item.comparisonKind {
        case .better: return FaceScanWhoopPalette.optimal
        case .worse: return FaceScanWhoopPalette.insufficient
        case .stable, .reference: return FaceScanWhoopPalette.secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Image(systemName: item.arrowSystemName)
                    .font(.system(size: 10, weight: .bold))
                Text(item.deltaLabel)
                    .font(.system(size: 12, weight: .bold))
                    .monospacedDigit()
            }
            .foregroundStyle(tint)

            Text(item.title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(FaceScanWhoopPalette.label.opacity(0.82))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(0.13))
        }
    }
}

private struct FaceScanWhoopMetricRow: View {
    let kind: FaceScanIndicators.Kind
    let result: FaceScanResult
    var previous: FaceScanResult?
    var style: FaceScanWhoopResultsStyle = .immersive
    var isRevealed: Bool = true
    var animatesCount: Bool = false

    @State private var displayedPercent: Int = 0
    @State private var zoneBarProgress: Double = 1
    @State private var didAnimateRow = false

    private var percent: Int {
        FaceScanIndicators.displayPercent(for: kind, result: result)
    }

    private var zone: FaceScanIndicators.WellnessZone {
        FaceScanIndicators.displayZone(for: kind, result: result)
    }

    private var displayItem: FaceScanMetricDisplay.Item {
        FaceScanMetricDisplay.item(for: kind, result: result, previous: previous)
    }

    private var iconColor: Color {
        style == .chatThread
            ? OnboardingTheme.primaryText.opacity(0.78)
            : FaceScanWhoopPalette.label.opacity(0.88)
    }

    private var labelColor: Color {
        style == .chatThread
            ? OnboardingTheme.primaryText
            : FaceScanWhoopPalette.label.opacity(0.88)
    }

    private var valueColor: Color {
        if style == .chatThread {
            return FaceScanWhoopPalette.ringColor(for: zone)
        }
        return FaceScanWhoopPalette.label
    }

    private var comparisonColor: Color {
        switch displayItem.comparisonKind {
        case .better: return FaceScanWhoopPalette.optimal
        case .worse: return FaceScanWhoopPalette.insufficient
        case .stable, .reference: return FaceScanWhoopPalette.secondary
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: kind.systemImage)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(iconColor)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(kind.whoopLabel)
                    .font(.system(size: style == .chatThread ? 12 : 11, weight: .semibold))
                    .foregroundStyle(labelColor)
                    .tracking(0.3)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

                HStack(spacing: 4) {
                    Image(systemName: displayItem.arrowSystemName)
                        .font(.system(size: 9, weight: .bold))
                    Text(displayItem.comparison)
                        .font(.system(size: 10, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                }
                .foregroundStyle(comparisonColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            FaceScanWhoopZoneBar(activeZone: zone, style: style)
                .frame(width: 92)
                .opacity(zoneBarProgress)

            Text("\(displayedPercent)%")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(valueColor)
                .monospacedDigit()
                .contentTransition(.numericText())
                .frame(width: 44, alignment: .trailing)
        }
        .onAppear(perform: syncDisplayedValues)
        .onChange(of: isRevealed) { _, revealed in
            guard revealed else { return }
            syncDisplayedValues()
        }
        .onChange(of: result.id) { _, _ in
            didAnimateRow = false
            syncDisplayedValues()
        }
    }

    private func syncDisplayedValues() {
        guard isRevealed else {
            displayedPercent = 0
            zoneBarProgress = 0.35
            return
        }

        guard animatesCount, !didAnimateRow else {
            displayedPercent = percent
            zoneBarProgress = 1
            return
        }

        didAnimateRow = true
        displayedPercent = 0
        zoneBarProgress = 0.35

        withAnimation(FaceScanWhoopRevealTiming.contentEase) {
            zoneBarProgress = 1
        }

        let target = percent
        Task {
            let steps = 10
            for step in 1...steps {
                try? await Task.sleep(nanoseconds: 18_000_000)
                let value = Int((Double(target) * Double(step) / Double(steps)).rounded())
                await MainActor.run {
                    displayedPercent = value
                }
            }
            await MainActor.run {
                displayedPercent = target
            }
        }
    }
}

struct FaceScanWhoopZoneBar: View {
    let activeZone: FaceScanIndicators.WellnessZone
    var style: FaceScanWhoopResultsStyle = .immersive

    private let segmentHeight: CGFloat = 4
    private let spacing: CGFloat = 2

    var body: some View {
        HStack(spacing: spacing) {
            segment(for: .insufficient)
            segment(for: .sufficient)
            segment(for: .optimal)
        }
    }

    @ViewBuilder
    private func segment(for zone: FaceScanIndicators.WellnessZone) -> some View {
        let isActive = zone == activeZone
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(isActive ? color(for: zone) : idleColor)
            .frame(height: isActive ? segmentHeight + 1 : segmentHeight)
            .frame(maxWidth: .infinity)
    }

    private var idleColor: Color {
        style == .chatThread
            ? OnboardingTheme.softBorder.opacity(0.35)
            : FaceScanWhoopPalette.segmentIdle
    }

    private func color(for zone: FaceScanIndicators.WellnessZone) -> Color {
        switch zone {
        case .insufficient: return FaceScanWhoopPalette.insufficient
        case .sufficient: return FaceScanWhoopPalette.sufficient
        case .optimal: return FaceScanWhoopPalette.optimal
        }
    }
}

// MARK: - Évolution par indicateur

private struct FaceScanWhoopIndicatorTrendsSection: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.faceScanResultsAnimateReveal) private var animateReveal

    let history: [FaceScanResult]

    @State private var sectionVisible = true

    private var plottedScanCount: Int {
        Set(history.map { Calendar.current.startOfDay(for: $0.createdAt) }).count
    }

    private var sectionSubtitle: String {
        if plottedScanCount < 2 {
            return "Point de départ — l’évolution se remplit à chaque nouveau scan (7 jours)."
        }
        return "Évolution par rapport aux 7 jours précédents"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Santé visage")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(FaceScanWhoopPalette.label)

                Text(sectionSubtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(FaceScanWhoopPalette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(Array(FaceScanIndicators.Kind.allCases.enumerated()), id: \.element.id) { index, kind in
                FaceScanWhoopIndicatorTrendCard(
                    kind: kind,
                    history: history,
                    theme: theme
                )
                .opacity(sectionVisible ? 1 : 0)
                .offset(y: sectionVisible ? 0 : 12)
                .animation(
                    FaceScanWhoopRevealTiming.contentEase.delay(Double(index) * 0.04),
                    value: sectionVisible
                )
            }
        }
        .onAppear(perform: syncRevealState)
    }

    private func syncRevealState() {
        guard animateReveal else {
            sectionVisible = true
            return
        }

        sectionVisible = false
        Task {
            try? await Task.sleep(for: .milliseconds(Int(FaceScanWhoopRevealTiming.trendsStartDelay * 1000)))
            await MainActor.run {
                withAnimation(FaceScanWhoopRevealTiming.contentEase) {
                    sectionVisible = true
                }
            }
        }
    }
}

private struct FaceScanWhoopIndicatorTrendCard: View {
    let kind: FaceScanIndicators.Kind
    let history: [FaceScanResult]
    let theme: AppTheme

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
    }

    private var daySlots: [FaceScanWhoopChartDaySlot] {
        FaceScanWhoopChartDaySlot.build(history: history) {
            FaceScanIndicators.displayPercent(for: kind, result: $0)
        }
    }

    private var latestScan: FaceScanResult? {
        history.sorted { $0.createdAt > $1.createdAt }.first
    }

    private var previousScan: FaceScanResult? {
        guard let latestScan else { return nil }
        return history
            .filter { $0.id != latestScan.id && $0.createdAt < latestScan.createdAt }
            .sorted { $0.createdAt > $1.createdAt }
            .first
    }

    private var trendItem: FaceScanMetricDisplay.Item? {
        latestScan.map { FaceScanMetricDisplay.item(for: kind, result: $0, previous: previousScan) }
    }

    private var trendTint: Color {
        guard let trendItem else { return FaceScanWhoopPalette.secondary }
        switch trendItem.comparisonKind {
        case .better: return FaceScanWhoopPalette.optimal
        case .worse: return FaceScanWhoopPalette.insufficient
        case .stable, .reference: return FaceScanWhoopPalette.secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: kind.systemImage)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(FaceScanWhoopPalette.label.opacity(0.88))
                    .frame(width: 20)

                Text(kind.whoopLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(FaceScanWhoopPalette.label.opacity(0.88))
                    .tracking(0.3)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: 8)

                if let trendItem {
                    HStack(spacing: 5) {
                        Image(systemName: trendItem.arrowSystemName)
                            .font(.system(size: 10, weight: .bold))
                        Text(trendItem.deltaLabel)
                            .font(.system(size: 12, weight: .bold))
                            .monospacedDigit()
                    }
                    .foregroundStyle(trendTint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background {
                        Capsule(style: .continuous)
                            .fill(trendTint.opacity(0.13))
                    }
                } else if let latest = daySlots.compactMap(\.value).last {
                    Text("\(latest)%")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(FaceScanWhoopPalette.label)
                        .monospacedDigit()
                }
            }

            if daySlots.compactMap(\.value).isEmpty {
                Text("En attente du premier point de mesure.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(FaceScanWhoopPalette.secondary)
                    .frame(maxWidth: .infinity, minHeight: 100, alignment: .center)
            } else {
                FaceScanWhoopLineChart(
                    slots: daySlots,
                    color: kind.trendColor
                )
                .frame(height: 148)

                if daySlots.compactMap(\.value).count < 2 {
                    Text("Encore quelques scans pour tracer la courbe complète.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(FaceScanWhoopPalette.secondary)
                }
            }
        }
        .padding(16)
        .background {
            cardShape
                .fill(.clear)
                .processGlassEffect(in: cardShape, interactive: false)
        }
        .clipShape(cardShape)
        .processHomeGlassCardShadow(isDark: theme.isDark)
    }
}

private struct FaceScanWhoopChartDaySlot: Identifiable {
    let day: Date
    let value: Int?

    var id: Date { day }

    var isToday: Bool {
        Calendar.current.isDateInToday(day)
    }

    static func build(
        history: [FaceScanResult],
        value: (FaceScanResult) -> Int
    ) -> [FaceScanWhoopChartDaySlot] {
        let dayCount = 7
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let start = calendar.date(byAdding: .day, value: -(dayCount - 1), to: today) else {
            return []
        }

        var latestByDay: [Date: FaceScanResult] = [:]
        for scan in history {
            let day = calendar.startOfDay(for: scan.createdAt)
            guard day >= start, day <= today else { continue }
            if let existing = latestByDay[day], existing.createdAt > scan.createdAt { continue }
            latestByDay[day] = scan
        }

        var slots: [FaceScanWhoopChartDaySlot] = []
        var cursor = start
        while cursor <= today {
            let scan = latestByDay[cursor]
            slots.append(FaceScanWhoopChartDaySlot(day: cursor, value: scan.map(value)))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return slots
    }
}

private struct FaceScanWhoopLineChart: View {
    let slots: [FaceScanWhoopChartDaySlot]
    let color: Color

    private let axisLabelHeight: CGFloat = 20
    private let valueLabelHeight: CGFloat = 18

    private var plottedPoints: [(index: Int, value: Int)] {
        slots.enumerated().compactMap { index, slot in
            guard let value = slot.value else { return nil }
            return (index, value)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let plotHeight = geo.size.height - axisLabelHeight
            let values = plottedPoints.map { Double($0.value) }
            let minV = (values.min() ?? 0) - 5
            let maxV = (values.max() ?? 100) + 5
            let range = max(maxV - minV, 1)
            let columnWidth = width / CGFloat(max(slots.count, 1))

            ZStack {
                ForEach(0..<4, id: \.self) { i in
                    let y = (plotHeight - valueLabelHeight) * CGFloat(i) / 3 + valueLabelHeight
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                }

                ForEach(Array(slots.enumerated()), id: \.element.id) { index, slot in
                    if slot.isToday {
                        let x = xPosition(for: index, width: width)
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.white.opacity(0.07))
                            .frame(width: max(columnWidth * 0.72, 18), height: plotHeight)
                            .position(x: x, y: plotHeight / 2)
                    }
                }

                Path { path in
                    for (pointIndex, point) in plottedPoints.enumerated() {
                        let x = xPosition(for: point.index, width: width)
                        let normalized = (Double(point.value) - minV) / range
                        let y = plotY(for: normalized, plotHeight: plotHeight)
                        if pointIndex == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                ForEach(plottedPoints, id: \.index) { point in
                    let x = xPosition(for: point.index, width: width)
                    let normalized = (Double(point.value) - minV) / range
                    let y = plotY(for: normalized, plotHeight: plotHeight)

                    Text("\(point.value)%")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(FaceScanWhoopPalette.label.opacity(0.9))
                        .monospacedDigit()
                        .position(x: x, y: max(10, y - 14))

                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                        .position(x: x, y: y)
                }

                ForEach(Array(slots.enumerated()), id: \.element.id) { index, slot in
                    let x = xPosition(for: index, width: width)
                    Text(axisLabel(for: slot.day))
                        .font(.system(size: 10, weight: slot.isToday ? .bold : .medium))
                        .foregroundStyle(
                            slot.isToday
                                ? FaceScanWhoopPalette.label
                                : FaceScanWhoopPalette.secondary
                        )
                        .position(x: x, y: plotHeight + axisLabelHeight / 2)
                }
            }
        }
    }

    private func xPosition(for index: Int, width: CGFloat) -> CGFloat {
        let count = max(slots.count, 1)
        return width * (CGFloat(index) + 0.5) / CGFloat(count)
    }

    private func plotY(for normalized: Double, plotHeight: CGFloat) -> CGFloat {
        let drawableHeight = plotHeight - valueLabelHeight
        return valueLabelHeight + drawableHeight - drawableHeight * CGFloat(normalized)
    }

    private func axisLabel(for day: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "EEE"
        return formatter.string(from: day)
            .lowercased()
            .replacingOccurrences(of: ".", with: "")
    }
}

private extension FaceScanIndicators.Kind {
    var trendColor: Color {
        switch self {
        case .retention: return FaceScanWhoopPalette.insufficient
        case .recovery: return Color.purple.opacity(0.85)
        case .skin: return Color.mint
        case .definition: return Color.cyan
        case .stressLoad: return Color.red.opacity(0.85)
        }
    }
}

// MARK: - Détails du scan

private struct FaceScanWhoopAnalysisInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    let result: FaceScanResult
    let history: [FaceScanResult]

    private var recentScans: [FaceScanResult] {
        Array(history.sorted { $0.createdAt > $1.createdAt }.prefix(12))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FaceScanWhoopPalette.canvas.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        if let confidence = result.scanConfidence {
                            FaceScanDetailConfidenceRing(confidence: confidence)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 8)
                        }

                        VStack(spacing: 12) {
                            FaceScanDetailInfoCard(
                                title: "Score global",
                                value: "\(result.displayWellnessScore)%",
                                detail: "Moyenne des 5 indicateurs du scan"
                            )

                            FaceScanDetailInfoCard(
                                title: "Score relatif",
                                value: "\(result.resolvedFaceDayScore)%",
                                detail: "Variation vs ton historique, pas l’état absolu du jour"
                            )

                            if let label = result.relativeSignals?.baselineLabel {
                                FaceScanDetailInfoCard(
                                    title: "Baseline",
                                    value: label,
                                    detail: nil
                                )
                            }
                        }

                        if !recentScans.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Derniers scans")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(FaceScanWhoopPalette.label)

                                VStack(spacing: 0) {
                                    ForEach(Array(recentScans.enumerated()), id: \.element.id) { index, scan in
                                        FaceScanDetailHistoryRow(
                                            scan: scan,
                                            isCurrent: scan.id == result.id
                                        )

                                        if index < recentScans.count - 1 {
                                            Divider()
                                                .overlay(Color.white.opacity(0.08))
                                                .padding(.leading, 56)
                                        }
                                    }
                                }
                                .background {
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .fill(FaceScanWhoopPalette.card)
                                }
                            }
                        }

                        Text("L’accueil et l’anneau affichent le score global.")
                            .font(.system(size: 12))
                            .foregroundStyle(FaceScanWhoopPalette.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Historique")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(FaceScanWhoopPalette.canvas, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }
                        .foregroundStyle(FaceScanWhoopPalette.label)
                }
            }
        }
    }
}

private struct FaceScanDetailConfidenceRing: View {
    let confidence: Int

    private let ringSize: CGFloat = 112
    private let strokeWidth: CGFloat = 9

    private var progress: Double {
        Double(confidence) / 100.0
    }

    private var ringColor: Color {
        switch confidence {
        case 82...: return FaceScanWhoopPalette.optimal
        case 64..<82: return FaceScanWhoopPalette.sufficient
        default: return FaceScanWhoopPalette.insufficient
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(FaceScanWhoopPalette.ringTrack, lineWidth: strokeWidth)
                    .frame(width: ringSize, height: ringSize)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        ringColor,
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                    )
                    .frame(width: ringSize, height: ringSize)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(confidence)%")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(FaceScanWhoopPalette.label)
                        .monospacedDigit()

                    Text("CONFIANCE")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(FaceScanWhoopPalette.secondary)
                        .tracking(1.1)
                }
            }

            Text(FaceWellnessScore.confidenceLabel(for: confidence))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(FaceScanWhoopPalette.secondary)
        }
    }
}

private struct FaceScanDetailInfoCard: View {
    let title: String
    let value: String
    let detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(FaceScanWhoopPalette.secondary)
                .tracking(0.5)

            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(FaceScanWhoopPalette.label)
                .monospacedDigit()

            if let detail {
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(FaceScanWhoopPalette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(FaceScanWhoopPalette.card)
        }
    }
}

private struct FaceScanDetailHistoryRow: View {
    let scan: FaceScanResult
    let isCurrent: Bool

    @State private var thumbnail: UIImage?

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .overlay {
                            Image(systemName: "face.smiling")
                                .font(.system(size: 16, weight: .light))
                                .foregroundStyle(FaceScanWhoopPalette.secondary)
                        }
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(formattedDate)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(FaceScanWhoopPalette.label)

                Text("Score \(scan.displayWellnessScore)%")
                    .font(.system(size: 13))
                    .foregroundStyle(FaceScanWhoopPalette.secondary)
            }

            Spacer(minLength: 8)

            if isCurrent {
                Text("Actuel")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(FaceScanWhoopPalette.optimal)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background {
                        Capsule()
                            .fill(FaceScanWhoopPalette.optimal.opacity(0.15))
                    }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .onAppear(perform: loadThumbnail)
    }

    private var formattedDate: String {
        FaceScanWhoopDateLabel.historyRow(for: scan.createdAt)
    }

    private func loadThumbnail() {
        let reconciled = FaceScanImageStore.reconcileMediaMetadata(for: scan)
        if let filename = FaceScanImageStore.resolvedSnapshotFilename(for: reconciled) {
            thumbnail = FaceScanImageStore.load(filename: filename)
        }
    }
}
