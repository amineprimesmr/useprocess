import SwiftUI
import UIKit

/// Session post-capture : animation d'analyse (Claude, HealthKit…) puis écran résultats WHOOP.
struct FaceScanAnalysisFlowView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var creatorMode = ProcessCreatorModeStore.shared

    let payload: FaceScanCapturePayload
    let markers: FaceWellnessMarkers
    var profile: UnifiedUserProfile?
    var showsResultScreen: Bool = true
    var onDismiss: () -> Void
    var onComplete: (FaceScanResult) -> Void

    @State private var baseResult: FaceScanResult?
    @State private var qualityDraft: Double = 0.5
    @State private var framingDraft: FaceScanStudioFraming = .identity
    @State private var analysisProgress: Double = 0
    @State private var analysisDisplayedPercentage = 0
    @State private var analysisPhaseIndex = 0
    @State private var analysisPhaseLabel = OnboardingAnalysisProgressConfig.faceScanAnalysisSteps[0].phaseLabel
    @State private var analysisElapsedSeconds = 0
    @State private var analysisTask: Task<Void, Never>?
    @State private var elapsedTask: Task<Void, Never>?
    @State private var didCompleteAnalysis = false

    private var steps: [OnboardingAnalysisProgressConfig.ProgressStep] {
        OnboardingAnalysisProgressConfig.faceScanAnalysisSteps
    }

    private var showsCreatorControls: Bool {
        creatorMode.isUnlocked && showsResultScreen && baseResult != nil
    }

    private var qualityDraftLabel: String {
        switch qualityDraft {
        case ..<0.2: return "Mauvais"
        case ..<0.4: return "Faible"
        case ..<0.6: return "Réaliste"
        case ..<0.8: return "Bon"
        default: return "Excellent"
        }
    }

    /// Résultat affiché — éventuellement ajusté par le slider studio.
    private var displayResult: FaceScanResult? {
        guard let base = baseResult else { return nil }
        guard showsCreatorControls else { return base }
        return creatorMode.rebuildResult(base, quality: qualityDraft)
    }

    var body: some View {
        GeometryReader { geometry in
            // Toujours prendre le vrai inset fenêtre (évite le chevauchement Dynamic Island).
            let topInset = max(geometry.safeAreaInsets.top, Self.windowSafeAreaTop, 47)

            ZStack {
                analysisBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: baseResult == nil ? 28 : 0) {
                        headerBar
                            .padding(.horizontal, 20)
                            .padding(.top, topInset + 4)
                            .padding(.bottom, baseResult == nil ? 0 : 18)

                        if let result = displayResult, let base = baseResult, showsResultScreen {
                            FaceScanWhoopInlineResults(
                                result: result,
                                history: FaceScanHistoryStore.shared.history,
                                prefersPassedResult: showsCreatorControls,
                                evolutionAnchor: base,
                                animateRevealOnce: true,
                                allowsStudioFraming: showsCreatorControls,
                                studioFraming: framingDraft,
                                onStudioFramingChange: { framing in
                                    framingDraft = framing.clamped()
                                }
                            ) {
                                if showsCreatorControls {
                                    creatorQualitySlider
                                        .padding(.horizontal, 16)
                                        .padding(.top, 28)
                                        .padding(.bottom, 8)
                                }
                            }
                            // Identité stable : ne JAMAIS remonter la page quand le slider bouge.
                            .id(base.id)
                            .transition(.opacity)
                            .padding(.bottom, 120)
                        } else {
                            FaceScanAnalysisHeroView(payload: payload)
                                .padding(.horizontal, 24)

                            OnboardingProfileChatAnalysisPanel(
                                phaseLabel: analysisPhaseLabel,
                                phaseIndex: analysisPhaseIndex,
                                displayedPercentage: analysisDisplayedPercentage,
                                progress: analysisProgress,
                                elapsedSeconds: analysisElapsedSeconds,
                                isVisible: true,
                                steps: steps
                            )
                            .padding(.horizontal, 20)
                            .padding(.bottom, 36)
                        }
                    }
                }
                // Le fond ignore le safe area ; on gère le top manuellement via topInset.
                .ignoresSafeArea(edges: .top)

                if let result = displayResult, showsResultScreen {
                    VStack {
                        Spacer(minLength: 0)
                        FaceIDContinueButton {
                            HapticManager.shared.impact(.medium)
                            complete(with: result)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, max(geometry.safeAreaInsets.bottom, 12) + 12)
                    }
                    .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.28), value: baseResult?.id)
        .task(id: payload.scanId) {
            await runAnalysis()
        }
        .onDisappear {
            guard !didCompleteAnalysis else { return }
            analysisTask?.cancel()
            elapsedTask?.cancel()
        }
    }

    private var creatorQualitySlider: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Rendu résultats")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FaceScanWhoopPalette.secondary)
                Spacer()
                Text(qualityDraftLabel)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(FaceScanWhoopPalette.label)
                    .contentTransition(.opacity)
            }

            Slider(
                value: Binding(
                    get: { qualityDraft },
                    set: { newValue in
                        // Pas d’animations implicites sur toute la page pendant le drag.
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            qualityDraft = newValue
                        }
                    }
                ),
                in: 0...1,
                onEditingChanged: { editing in
                    // Persist uniquement en fin de geste — pas de UserDefaults / @Published à chaque tick.
                    if !editing {
                        creatorMode.resultQuality = qualityDraft
                    }
                }
            )
            .tint(FaceScanWhoopPalette.label)

            HStack {
                Text("Mauvais")
                Spacer()
                Text("Réaliste")
                Spacer()
                Text("Excellent")
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(FaceScanWhoopPalette.secondary)
        }
    }

    @MainActor
    private func complete(with result: FaceScanResult) {
        guard !didCompleteAnalysis else { return }
        didCompleteAnalysis = true

        var final = result
        // Persiste le rendu final (slider + cadrage + photo) — même carte accueil qu’un vrai scan.
        if showsCreatorControls {
            creatorMode.resultQuality = qualityDraft
            final.studioFraming = framingDraft.isIdentity ? nil : framingDraft.clamped()
        }
        // Upsert systématique : import photo / studio doivent bien remplacer le latest.
        FaceScanHistoryStore.shared.upsert(final)
        ProcessDebloatTrajectoryStore.shared.recordScan(final)

        onComplete(final)
        onDismiss()
    }

    private var analysisBackground: Color {
        FaceScanWhoopPalette.canvas
    }

    /// Safe area top depuis la fenêtre UIKit (fiable en fullScreenCover).
    private static var windowSafeAreaTop: CGFloat {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
            ?? scenes.flatMap(\.windows).first
        return window?.safeAreaInsets.top ?? 0
    }

    private var headerForeground: Color {
        FaceScanWhoopPalette.label
    }

    private var headerBar: some View {
        HStack {
            Color.clear
                .frame(width: 44, height: 44)

            Spacer(minLength: 0)

            Text(displayResult == nil ? "ANALYSE DU SCAN" : formattedHeaderDate)
                .font(.system(size: displayResult == nil ? 13 : 15, weight: .semibold))
                .foregroundStyle(headerForeground)
                .tracking(displayResult == nil ? 0.6 : 0)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 0)

            if displayResult != nil, showsResultScreen {
                Button("Terminer") {
                    if let result = displayResult {
                        complete(with: result)
                    }
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(headerForeground)
                .frame(minWidth: 44, alignment: .trailing)
            } else {
                Color.clear
                    .frame(width: 44, height: 44)
            }
        }
    }

    private var formattedHeaderDate: String {
        guard let result = displayResult else { return "" }
        return FaceScanWhoopDateLabel.header(for: result.createdAt)
    }

    @MainActor
    private func runAnalysis() async {
        qualityDraft = creatorMode.resultQuality
        startElapsedTimer()
        startProgressAnimation()

        try? await Task.sleep(for: .milliseconds(250))

        let analysisStartedAt = Date()

        let result = await FaceScanService.recordScan(
            payload: payload,
            markers: markers,
            profile: profile
        )

        FaceScanHistoryStore.shared.reloadForUser(userId: profile?.userId)

        let minimumAnalysisDuration: TimeInterval = 7.5
        let elapsed = Date().timeIntervalSince(analysisStartedAt)
        if elapsed < minimumAnalysisDuration {
            try? await Task.sleep(nanoseconds: UInt64((minimumAnalysisDuration - elapsed) * 1_000_000_000))
        }

        analysisTask?.cancel()
        await finishProgressAnimation()
        elapsedTask?.cancel()
        HapticManager.shared.notification(.success)

        try? await Task.sleep(for: .milliseconds(420))

        if showsResultScreen {
            framingDraft = result.resolvedStudioFraming
            baseResult = result
        } else {
            // Onboarding / flux sans résultats inline : applique le rendu studio si besoin.
            let final = creatorMode.isUnlocked
                ? creatorMode.rebuildResult(result, quality: creatorMode.resultQuality)
                : result
            if creatorMode.isUnlocked {
                FaceScanHistoryStore.shared.update(final)
            }
            complete(with: final)
        }
    }

    private func startElapsedTimer() {
        elapsedTask?.cancel()
        elapsedTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                analysisElapsedSeconds += 1
            }
        }
    }

    private func startProgressAnimation() {
        analysisTask?.cancel()

        let tickInterval = OnboardingAnalysisProgressConfig.tickIntervalNs
        let leadDuration: TimeInterval = 7.5

        analysisTask = Task {
            try? await Task.sleep(nanoseconds: OnboardingAnalysisProgressConfig.startDelayNs)
            guard !Task.isCancelled else { return }

            let startTime = Date()

            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(startTime)
                let normalized = min(0.92, elapsed / leadDuration)
                let eased = 1.0 - pow(1.0 - normalized, 2.1)
                let stepIndex = min(steps.count - 1, Int(eased * Double(steps.count)))

                await MainActor.run {
                    analysisProgress = eased
                    analysisDisplayedPercentage = Int((eased * 100).rounded())
                    analysisPhaseIndex = stepIndex
                    analysisPhaseLabel = steps[stepIndex].phaseLabel
                }

                if normalized >= 0.92 { break }
                try? await Task.sleep(nanoseconds: tickInterval)
            }
        }
    }

    @MainActor
    private func finishProgressAnimation() async {
        analysisTask?.cancel()
        elapsedTask?.cancel()

        let start = analysisProgress
        let stepsCount = 12
        for i in 1...stepsCount {
            let t = Double(i) / Double(stepsCount)
            let eased = 1.0 - pow(1.0 - t, 1.6)
            analysisProgress = start + (1.0 - start) * eased
            analysisDisplayedPercentage = Int((analysisProgress * 100).rounded())
            analysisPhaseIndex = steps.count - 1
            analysisPhaseLabel = steps[steps.count - 1].phaseLabel
            try? await Task.sleep(for: .milliseconds(28))
        }
        analysisProgress = 1
        analysisDisplayedPercentage = 100
    }
}

// MARK: - Hero média (vidéo / snapshot)

struct FaceScanAnalysisHeroView: View {
    let payload: FaceScanCapturePayload
    var showsAnalysisSweep: Bool = true

    @State private var resolvedVideoURL: URL?

    private let heroDiameter: CGFloat = 240

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.35))
                .frame(width: heroDiameter, height: heroDiameter)
                .overlay {
                    mediaLayer
                        .frame(width: heroDiameter, height: heroDiameter)
                        .clipShape(Circle())
                }
                .overlay {
                    if showsAnalysisSweep {
                        FaceScanAnalysisSweepOverlay(diameter: heroDiameter)
                            .frame(width: heroDiameter, height: heroDiameter)
                            .clipShape(Circle())
                    }
                }
                .overlay {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.16), lineWidth: 1.5)
                }
        }
        .frame(maxWidth: .infinity)
        .task(id: payload.scanId) {
            await resolveVideoWithRetry()
        }
    }

    @ViewBuilder
    private var mediaLayer: some View {
        if let url = resolvedVideoURL {
            FaceScanSilentVideoLoopView(url: url)
                .id(url.absoluteString)
        } else if let snapshot = payload.snapshot {
            Image(uiImage: snapshot)
                .resizable()
                .scaledToFill()
        } else {
            Circle()
                .fill(Color.white.opacity(0.06))
                .overlay {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(FaceScanWhoopPalette.secondary)
                }
        }
    }

    private func resolveVideoWithRetry() async {
        for _ in 0..<30 {
            if let url = FaceScanImageStore.resolvedVideoURL(forScanId: payload.scanId) {
                resolvedVideoURL = url
                return
            }
            try? await Task.sleep(for: .milliseconds(180))
        }
    }
}

// MARK: - Sweep analyse

struct FaceScanAnalysisSweepOverlay: View {
    @Environment(\.colorScheme) private var colorScheme

    let diameter: CGFloat

    private let cycleDuration: TimeInterval = 2.85
    private let maskBandHeightRatio: CGFloat = 0.26

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let elapsed = context.date.timeIntervalSinceReferenceDate
            let phase = elapsed.truncatingRemainder(dividingBy: cycleDuration) / cycleDuration
            let sweepProgress = smoothPingPong(phase)

            GeometryReader { geometry in
                let width = max(1, geometry.size.width.isFinite ? geometry.size.width : 1)
                let height = max(1, geometry.size.height.isFinite ? geometry.size.height : 1)
                let y = height * sweepProgress
                let maskHeight = max(44, height * maskBandHeightRatio)

                ZStack {
                    Rectangle()
                        .fill(maskGradient)
                        .frame(width: width, height: maskHeight)
                        .blur(radius: 7)
                        .position(x: width * 0.5, y: y)

                    Rectangle()
                        .fill(Color.white.opacity(colorScheme == .dark ? 0.22 : 0.28))
                        .frame(width: width, height: 1.5)
                        .position(x: width * 0.5, y: y)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private var maskGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0),
                Color.white.opacity(colorScheme == .dark ? 0.18 : 0.22),
                Color.white.opacity(0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func smoothPingPong(_ phase: Double) -> Double {
        let x = phase < 0.5 ? phase * 2 : (1 - phase) * 2
        return x * x * (3 - 2 * x)
    }
}
