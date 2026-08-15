import SwiftUI

// MARK: - Tokens WHOOP

enum FaceScanWhoopPalette {
    /// Même fond que l’onboarding — évite les bandes (scroll / TabView / capture).
    static var canvas: Color { OnboardingTheme.screenBackground }

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

    /// Accent analyse (icônes étapes — remplace le violet onboarding).
    static let accentBlue = Color(red: 0.34, green: 0.72, blue: 1.0)

    static func ringColor(for zone: FaceScanIndicators.WellnessZone) -> Color {
        switch zone {
        case .insufficient: return insufficient
        case .sufficient: return sufficient
        case .optimal: return optimal
        }
    }
}

enum FaceScanWhoopDateLabel {
    @MainActor
    static func header(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = ProcessAppLanguage.shared.locale
        formatter.dateFormat = ProcessAppLanguage.shared.isEnglish ? "EEEE, MMMM d" : "EEEE d MMMM"
        return formatter.string(from: date)
    }

    @MainActor
    static func historyRow(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = ProcessAppLanguage.shared.locale
        formatter.dateFormat = ProcessAppLanguage.shared.isEnglish
            ? "EEEE, MMMM d · h:mm a"
            : "EEEE d MMMM · HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Écran principal

struct FaceScanWhoopAnalysisScreen: View {
    let result: FaceScanResult
    var previous: FaceScanResult?
    var history: [FaceScanResult] = []
    var showsDoneButton: Bool = false
    var doneButtonTitle: String? = nil
    var onDone: (() -> Void)?
    var bottomContentInset: CGFloat = 40

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var creatorMode = ProcessCreatorModeStore.shared
    @Bindable private var historyStore = FaceScanHistoryStore.shared
    @State private var showsAnalysisInfo = false
    @State private var framingDraft: FaceScanStudioFraming = .identity
    @State private var qualityDraft: Double = 0.5
    /// Ancre stable pour le slider (évite de re-lerp un résultat déjà ajusté).
    @State private var studioBaseResult: FaceScanResult?

    private var storedResult: FaceScanResult {
        historyStore.history.first(where: { $0.id == result.id }) ?? result
    }

    private var isCreatorUnlocked: Bool {
        creatorMode.isUnlocked(forFirstName: UnifiedProfileService.shared.currentProfile?.firstName)
    }

    /// Résultat affiché — live via slider studio si débloqué.
    private var displayResult: FaceScanResult {
        guard isCreatorUnlocked, let base = studioBaseResult else {
            return storedResult
        }
        var rebuilt = creatorMode.rebuildResult(base, quality: qualityDraft)
        rebuilt.studioFraming = framingDraft.isIdentity ? nil : framingDraft.clamped()
        return rebuilt
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
            ensuring: studioBaseResult ?? displayResult
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

                    FaceScanWhoopScoreRing(
                        result: displayResult,
                        studioFraming: framingDraft,
                        allowsStudioFraming: isCreatorUnlocked,
                        onStudioFramingChange: { framing in
                            framingDraft = framing.clamped()
                            persistStudioEdits()
                        },
                        showsGlobalScore: !(isCreatorUnlocked && creatorMode.scanResultsLayout == .onboardingDeep)
                    )
                        .padding(.bottom, 22)

                    if isCreatorUnlocked, creatorMode.scanResultsLayout == .onboardingDeep {
                        OnboardingFaceDeepAnalysisView(
                            result: displayResult,
                            ringScale: 1,
                            showsScoreRing: false,
                            showsUnlockTeaser: false
                        )
                        .padding(.horizontal, 16)
                    } else {
                        FaceScanWhoopMetricsCard(
                            result: displayResult,
                            previous: previousForDisplay,
                            hidesComparisons: isCreatorUnlocked,
                            emphasizesLabels: isCreatorUnlocked
                        )
                            .padding(.horizontal, 16)

                        FaceScanWhoopEvolutionSummaryCard(
                            result: displayResult,
                            previous: previousForDisplay,
                            history: evolutionHistory,
                            studioQuality: isCreatorUnlocked ? qualityDraft : nil
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 14)

                        FaceScanWhoopIndicatorTrendsSection(history: evolutionHistory)
                            .padding(.horizontal, 16)
                            .padding(.top, 28)
                    }

                    if isCreatorUnlocked {
                        studioControlsBlock
                    }

                    Spacer(minLength: bottomContentInset)
                }
            }
            .processTransparentScrollSurface()
        }
        .processClearUIKitHostingBackground()
        .background(FaceScanWhoopPalette.canvas)
        .onAppear {
            ProcessCreatorModeStore.shared.syncFromCurrentProfile()
            framingDraft = storedResult.resolvedStudioFraming
            qualityDraft = creatorMode.resultQuality
            if studioBaseResult == nil {
                // Baseline = markers « réalistes » inversés depuis le rendu courant si besoin.
                studioBaseResult = storedResult
            }
        }
        .onChange(of: storedResult.id) { _, _ in
            framingDraft = storedResult.resolvedStudioFraming
            studioBaseResult = storedResult
            qualityDraft = creatorMode.resultQuality
        }
        .animation(.easeInOut(duration: 0.22), value: creatorMode.scanResultsLayout)
        .sheet(isPresented: $showsAnalysisInfo) {
            FaceScanWhoopAnalysisInfoSheet(
                result: displayResult,
                history: resolvedHistory
            )
        }
    }

    private func persistStudioEdits() {
        guard isCreatorUnlocked else { return }
        var updated = displayResult
        updated.studioFraming = framingDraft.isIdentity ? nil : framingDraft.clamped()
        FaceScanHistoryStore.shared.update(updated)
    }

    @ViewBuilder
    private var studioControlsBlock: some View {
        VStack(spacing: 14) {
            FaceScanStudioQualitySlider(quality: $qualityDraft) { value in
                creatorMode.resultQuality = value
                persistStudioEdits()
            }

            FaceScanStudioResultsLayoutPicker(layout: $creatorMode.scanResultsLayout)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
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
                if let onDone {
                    Button(doneButtonTitle ?? AppCopy.done, action: onDone)
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
                .accessibilityLabel(AppCopy.t("Historique des scans", en: "Scan history"))
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
struct FaceScanWhoopInlineResults<BelowMetrics: View>: View {
    let result: FaceScanResult
    var history: [FaceScanResult] = []
    var showsTrends: Bool = true
    var ringScale: CGFloat = 1
    var style: FaceScanWhoopResultsStyle = .immersive
    /// Si true, garde les markers/score passés (slider studio) au lieu d’écraser avec l’historique.
    var prefersPassedResult: Bool = false
    /// Ancre stable pour évolution / tendances (évite de recalculer les charts à chaque tick du slider).
    var evolutionAnchor: FaceScanResult? = nil
    /// Première apparition uniquement — pas de re-reveal à chaque update live.
    var animateRevealOnce: Bool = true
    /// Mode studio : curseur qualité → revue comportementale simulée.
    var studioQuality: Double? = nil
    /// Mode studio : tap sur le visage pour recadrer.
    var allowsStudioFraming: Bool = false
    var studioFraming: FaceScanStudioFraming = .identity
    var onStudioFramingChange: ((FaceScanStudioFraming) -> Void)? = nil
    /// Contenu collé tout en bas du scroll (ex. slider créateur), hors premier viewport.
    @ViewBuilder var bottomAccessory: () -> BelowMetrics

    @Bindable private var historyStore = FaceScanHistoryStore.shared

    init(
        result: FaceScanResult,
        history: [FaceScanResult] = [],
        showsTrends: Bool = true,
        ringScale: CGFloat = 1,
        style: FaceScanWhoopResultsStyle = .immersive,
        prefersPassedResult: Bool = false,
        evolutionAnchor: FaceScanResult? = nil,
        animateRevealOnce: Bool = true,
        allowsStudioFraming: Bool = false,
        studioQuality: Double? = nil,
        studioFraming: FaceScanStudioFraming = .identity,
        onStudioFramingChange: ((FaceScanStudioFraming) -> Void)? = nil,
        @ViewBuilder bottomAccessory: @escaping () -> BelowMetrics = { EmptyView() }
    ) {
        self.result = result
        self.history = history
        self.showsTrends = showsTrends
        self.ringScale = ringScale
        self.style = style
        self.prefersPassedResult = prefersPassedResult
        self.evolutionAnchor = evolutionAnchor
        self.animateRevealOnce = animateRevealOnce
        self.allowsStudioFraming = allowsStudioFraming
        self.studioQuality = studioQuality
        self.studioFraming = studioFraming
        self.onStudioFramingChange = onStudioFramingChange
        self.bottomAccessory = bottomAccessory
    }

    private var displayResult: FaceScanResult {
        guard let stored = historyStore.history.first(where: { $0.id == result.id }) else {
            return result
        }
        guard prefersPassedResult else { return stored }
        // Slider live : markers du résultat passé + éventuel texte IA déjà enrichi.
        return FaceScanResult(
            id: result.id,
            userId: result.userId,
            createdAt: result.createdAt,
            markers: result.markers,
            snapshotFilename: result.snapshotFilename ?? stored.snapshotFilename,
            videoFilename: result.videoFilename ?? stored.videoFilename,
            claudeAnalysis: stored.claudeAnalysis ?? result.claudeAnalysis,
            aiEnhanced: stored.aiEnhanced || result.aiEnhanced,
            coachInsightMessage: stored.coachInsightMessage ?? result.coachInsightMessage,
            coachInsightModel: stored.coachInsightModel ?? result.coachInsightModel,
            source: result.source,
            sleepHoursAtScan: result.sleepHoursAtScan,
            hrvAtScan: result.hrvAtScan,
            faceDayScore: result.faceDayScore,
            relativeFaceDayScore: result.relativeFaceDayScore,
            scanConfidence: result.scanConfidence,
            baselineSampleCount: result.baselineSampleCount,
            relativeSignals: result.relativeSignals,
            studioFraming: result.studioFraming ?? stored.studioFraming
        )
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

    private var evolutionSource: FaceScanResult {
        evolutionAnchor ?? displayResult
    }

    private var evolutionHistory: [FaceScanResult] {
        FaceScanWhoopEvolutionHistory.resolve(
            from: resolvedHistory,
            ensuring: evolutionSource
        )
    }

    private var metricsHorizontalPadding: CGFloat {
        style == .chatThread ? 0 : 16
    }

    var body: some View {
        VStack(spacing: 0) {
            FaceScanWhoopScoreRing(
                result: displayResult,
                studioFraming: studioFraming,
                allowsStudioFraming: allowsStudioFraming,
                onStudioFramingChange: onStudioFramingChange
            )
                .scaleEffect(ringScale)
                .padding(.bottom, 22 * ringScale)

            FaceScanWhoopMetricsCard(
                result: displayResult,
                previous: previousForDisplay,
                style: style,
                hidesComparisons: allowsStudioFraming,
                emphasizesLabels: allowsStudioFraming
            )
                .padding(.horizontal, metricsHorizontalPadding)

            if style == .immersive {
                FaceScanWhoopEvolutionSummaryCard(
                    result: evolutionSource,
                    previous: previousForDisplay,
                    history: evolutionHistory,
                    studioQuality: studioQuality
                )
                .padding(.horizontal, 16)
                .padding(.top, 14)
            }

            if showsTrends {
                FaceScanWhoopIndicatorTrendsSection(history: evolutionHistory)
                    .padding(.horizontal, 16)
                    .padding(.top, 28)
            }

            // Studio : Normal / 1er scan + slider — collés en bas du scroll.
            bottomAccessory()

            Spacer(minLength: showsTrends ? 40 : (style == .chatThread ? 0 : 12))
        }
        .environment(\.faceScanResultsAnimateReveal, animateRevealOnce)
    }
}

// MARK: - Anneau + photo

struct FaceScanWhoopScoreRing: View {
    @Environment(\.faceScanResultsAnimateReveal) private var animateReveal

    let result: FaceScanResult
    var studioFraming: FaceScanStudioFraming = .identity
    var allowsStudioFraming: Bool = false
    var onStudioFramingChange: ((FaceScanStudioFraming) -> Void)? = nil
    /// Temporaire : masquer le % / label « Score global » (garde photo + anneau coloré).
    var showsGlobalScore: Bool = true
    var ringSize: CGFloat = 300

    @State private var animatedProgress: Double = 0
    @State private var displayedScore: Int = 0
    @State private var contentVisible = true
    @State private var hasCompletedReveal = false
    @State private var scoreCountTask: Task<Void, Never>?
    @State private var showsFramingEditor = false

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
                    FaceScanWhoopCircularPhoto(result: result, framing: studioFraming)
                        .frame(width: innerDiameter, height: innerDiameter)
                        .clipShape(Circle())

                    if showsGlobalScore {
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

                            Text(AppCopy.t("SCORE GLOBAL", en: "OVERALL SCORE"))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.82))
                                .tracking(1.2)
                        }
                        .padding(.bottom, 22)
                    }
                }
                .frame(width: innerDiameter, height: innerDiameter)
                .clipShape(Circle())
                .contentShape(Circle())
                .onTapGesture {
                    guard allowsStudioFraming else { return }
                    HapticManager.shared.impact(.light)
                    showsFramingEditor = true
                }

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
                    .allowsHitTesting(false)
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
        .onChange(of: displayScore) { _, newScore in
            // Update live (slider créateur) sans rejouer le reveal / flash.
            guard hasCompletedReveal else { return }
            scoreCountTask?.cancel()
            contentVisible = true
            withAnimation(.easeOut(duration: 0.12)) {
                animatedProgress = Double(newScore) / 100.0
                displayedScore = newScore
            }
        }
        .onDisappear {
            scoreCountTask?.cancel()
        }
        .fullScreenCover(isPresented: $showsFramingEditor) {
            FaceScanStudioFramingEditor(
                result: result,
                initialFraming: studioFraming,
                onCancel: { showsFramingEditor = false },
                onSave: { framing in
                    onStudioFramingChange?(framing)
                    showsFramingEditor = false
                }
            )
        }
    }

    private func syncRevealState() {
        scoreCountTask?.cancel()
        hasCompletedReveal = false

        guard animateReveal else {
            animatedProgress = progress
            displayedScore = displayScore
            contentVisible = true
            hasCompletedReveal = true
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
                hasCompletedReveal = true
            }
        }
    }
}

private struct FaceScanWhoopCircularPhoto: View {
    let result: FaceScanResult
    var framing: FaceScanStudioFraming = .identity

    @State private var resolvedVideoURL: URL?
    @State private var snapshot: UIImage?
    @State private var mediaRefreshToken = 0

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let clamped = framing.clamped()

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
            .frame(width: side, height: side)
            .scaleEffect(clamped.scale)
            .offset(
                x: CGFloat(clamped.offsetX) * side,
                y: CGFloat(clamped.offsetY) * side
            )
            .frame(width: side, height: side)
            .clipped()
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
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
    /// Mode studio : pas de « Stable / +5 vs moyenne », labels plus visibles.
    var hidesComparisons: Bool = false
    var emphasizesLabels: Bool = false

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
                    animatesCount: animateReveal,
                    hidesComparison: hidesComparisons,
                    emphasizesLabel: emphasizesLabels
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

    /// Mode studio : données simulées pilotées par le curseur qualité.
    var studioQuality: Double? = nil

    private var review: FaceScanBehaviorReview {
        if let studioQuality {
            return FaceScanBehaviorReviewBuilder.buildStudio(
                for: result,
                quality: studioQuality,
                previous: previous
            )
        }
        return FaceScanBehaviorReviewBuilder.build(
            for: result,
            previous: previous,
            history: history
        )
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(AppCopy.t("Qu'est-ce que je fais mal ?", en: "What am I doing wrong?"))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(FaceScanWhoopPalette.label)

                Text(review.summary)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(FaceScanWhoopPalette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(review.events.enumerated()), id: \.element.id) { index, event in
                    FaceScanWhoopBehaviorTimelineRow(
                        event: event,
                        isLast: index == review.events.count - 1
                    )
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Label {
                    Text(AppCopy.t("Comment améliorer", en: "How to improve"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(FaceScanWhoopPalette.label.opacity(0.88))
                } icon: {
                    Image(systemName: "arrow.up.right.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(FaceScanWhoopPalette.optimal)
                }

                Text(review.primaryFix)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FaceScanWhoopPalette.label)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(FaceScanWhoopPalette.optimal.opacity(0.10))
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

private struct FaceScanWhoopBehaviorTimelineRow: View {
    let event: FaceScanBehaviorReviewEvent
    let isLast: Bool

    private var tint: Color {
        event.isPositive ? FaceScanWhoopPalette.optimal : FaceScanWhoopPalette.insufficient
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.16))
                        .frame(width: 30, height: 30)

                    Image(systemName: event.systemImage)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(tint)
                }

                if !isLast {
                    Rectangle()
                        .fill(FaceScanWhoopPalette.secondary.opacity(0.22))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                        .padding(.vertical, 4)
                }
            }
            .frame(width: 30)

            VStack(alignment: .leading, spacing: 6) {
                Text(event.timeLabel)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(FaceScanWhoopPalette.secondary)
                    .textCase(.uppercase)

                Text(event.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(FaceScanWhoopPalette.label)
                    .fixedSize(horizontal: false, vertical: true)

                Text(event.detail)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(FaceScanWhoopPalette.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let fix = event.fix {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(FaceScanWhoopPalette.optimal)
                            .padding(.top, 2)

                        Text(fix)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(FaceScanWhoopPalette.label.opacity(0.86))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 2)
                }
            }
            .padding(.bottom, isLast ? 0 : 16)
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
    var hidesComparison: Bool = false
    var emphasizesLabel: Bool = false

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
            : FaceScanWhoopPalette.label.opacity(emphasizesLabel ? 0.95 : 0.88)
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

    private var labelFontSize: CGFloat {
        if emphasizesLabel { return 12.5 }
        return style == .chatThread ? 12 : 11
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: kind.systemImage)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(iconColor)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: hidesComparison ? 0 : 3) {
                Text(kind.whoopLabel)
                    .font(.system(size: labelFontSize, weight: .semibold))
                    .foregroundStyle(labelColor)
                    .tracking(emphasizesLabel ? 0.25 : 0.3)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

                if !hidesComparison {
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
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            FaceScanWhoopZoneBar(
                activeZone: zone,
                higherIsWorse: kind.higherIsWorse,
                style: style
            )
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
        .onChange(of: percent) { _, newValue in
            // Update live (slider) — pas de re-count animé.
            displayedPercent = newValue
            zoneBarProgress = 1
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
    /// Charge / signal défavorable : % élevé = tiret à droite (orange), % bas = à gauche (vert).
    var higherIsWorse: Bool = false
    var style: FaceScanWhoopResultsStyle = .immersive

    private let segmentHeight: CGFloat = 4
    private let spacing: CGFloat = 2

    /// Index du segment actif (0 = gauche, 2 = droite).
    private var activeSegmentIndex: Int {
        let base = activeZone.rawValue
        return higherIsWorse ? (2 - base) : base
    }

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<3, id: \.self) { index in
                segment(at: index)
            }
        }
    }

    @ViewBuilder
    private func segment(at index: Int) -> some View {
        let isActive = index == activeSegmentIndex
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(isActive ? color(for: activeZone) : idleColor)
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
            return AppCopy.t(
                "Point de départ — l’évolution se remplit à chaque nouveau scan (7 jours).",
                en: "Starting point — the trend fills in with each new scan (7 days)."
            )
        }
        return AppCopy.t(
            "Évolution par rapport aux 7 jours précédents",
            en: "Change vs the previous 7 days"
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(AppCopy.t("Santé visage", en: "Face health"))
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
                Text(AppCopy.t(
                    "En attente du premier point de mesure.",
                    en: "Waiting for the first measurement point."
                ))
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
                    Text(AppCopy.t(
                        "Encore quelques scans pour tracer la courbe complète.",
                        en: "A few more scans to complete the curve."
                    ))
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
        formatter.locale = ProcessAppLanguage.shared.locale
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
                                title: AppCopy.t("Score global", en: "Overall score"),
                                value: "\(result.displayWellnessScore)%",
                                detail: AppCopy.t(
                                    "Moyenne des 5 indicateurs du scan",
                                    en: "Average of the scan’s 5 indicators"
                                )
                            )

                            FaceScanDetailInfoCard(
                                title: AppCopy.t("Score relatif", en: "Relative score"),
                                value: "\(result.resolvedFaceDayScore)%",
                                detail: AppCopy.t(
                                    "Variation vs ton historique, pas l’état absolu du jour",
                                    en: "Change vs your history, not today’s absolute state"
                                )
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
                                Text(AppCopy.t("Derniers scans", en: "Recent scans"))
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

                        Text(AppCopy.t(
                            "L’accueil et l’anneau affichent le score global.",
                            en: "Home and the ring show the overall score."
                        ))
                            .font(.system(size: 12))
                            .foregroundStyle(FaceScanWhoopPalette.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle(AppCopy.t("Historique", en: "History"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(FaceScanWhoopPalette.canvas, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppCopy.close) { dismiss() }
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

                    Text(AppCopy.t("CONFIANCE", en: "CONFIDENCE"))
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

                Text(AppCopy.t("Score \(scan.displayWellnessScore) %", en: "Score \(scan.displayWellnessScore)%"))
                    .font(.system(size: 13))
                    .foregroundStyle(FaceScanWhoopPalette.secondary)
            }

            Spacer(minLength: 8)

            if isCurrent {
                Text(AppCopy.t("Actuel", en: "Current"))
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
