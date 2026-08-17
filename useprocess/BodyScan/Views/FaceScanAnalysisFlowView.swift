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
    /// Onboarding Moss funnel: track analysis sub-phases + abandon.
    var tracksOnboardingMossFunnel: Bool = false
    var onDismiss: () -> Void
    var onComplete: (FaceScanResult) -> Void
    /// Mode dev / studio — revient à la capture visage sans enregistrer l’analyse.
    var onRetryScan: (() -> Void)? = nil

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
    @State private var didSaveScan = false
    @State private var lastTrackedMossSubphaseIndex = -1

    private var steps: [OnboardingAnalysisProgressConfig.ProgressStep] {
        OnboardingAnalysisProgressConfig.faceScanAnalysisSteps
    }

    private var isCreatorUnlocked: Bool {
        creatorMode.isUnlocked(forFirstName: profile?.firstName)
    }

    private var showsCreatorControls: Bool {
        isCreatorUnlocked && showsResultScreen && baseResult != nil
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
                            studioResultsBody(result: result, base: base)
                            // Identité stable : ne JAMAIS remonter la page quand le slider bouge.
                            .id(base.id)
                            .transition(.opacity)
                            .padding(.bottom, 120)
                        } else {
                            VStack(spacing: 0) {
                                FaceScanAnalysisHeroView(payload: payload)
                                    .padding(.horizontal, 24)

                                Text(AppCopy.t("Analyse du scan en cours...", en: "Scan analysis in progress..."))
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(FaceScanWhoopPalette.label)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 16)
                                    .padding(.horizontal, 28)

                                FaceScanAnalysisProgressBars(
                                    steps: steps,
                                    progress: analysisProgress
                                )
                                .padding(.horizontal, 28)
                                .padding(.top, 32)
                            }

                            if showsDevRescanButton {
                                Button(action: retryScan) {
                                    Text(AppCopy.t("DEV · Revenir au scan", en: "DEV · Back to scan"))
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(FaceScanWhoopPalette.secondary)
                                        .padding(.vertical, 10)
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.processPlain)
                                .accessibilityLabel(AppCopy.t("Revenir au scan du visage", en: "Back to face scan"))
                                .padding(.horizontal, 20)
                            }

                            Spacer()
                                .frame(height: 36)
                        }
                    }
                }
                .processTransparentScrollSurface()
                // Le fond ignore le safe area ; on gère le top manuellement via topInset.
                .ignoresSafeArea(edges: .top)

            }
        }
        .ignoresSafeArea(edges: .top)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let result = displayResult, showsResultScreen {
                saveScanBar(result: result)
            }
        }
        .processClearUIKitHostingBackground()
        .background(FaceScanWhoopPalette.canvas)
        .animation(.easeInOut(duration: 0.28), value: baseResult?.id)
        .animation(.easeInOut(duration: 0.22), value: creatorMode.scanResultsLayout)
        .interactiveDismissDisabled(showsResultScreen && !didSaveScan)
        .task(id: payload.scanId) {
            ProcessCreatorModeStore.shared.evaluate(firstName: profile?.firstName)
            ProcessCreatorModeStore.shared.syncFromCurrentProfile()
            await runAnalysis()
        }
        .onAppear {
            ProcessCreatorModeStore.shared.evaluate(firstName: profile?.firstName)
            ProcessCreatorModeStore.shared.syncFromCurrentProfile()
        }
        .onDisappear {
            guard !didCompleteAnalysis else { return }
            analysisTask?.cancel()
            elapsedTask?.cancel()
            if tracksOnboardingMossFunnel {
                ProcessAnalytics.trackMossAction(
                    page: .faceScanAnalyzing,
                    action: "abandoned",
                    extra: [
                        "phase_index": analysisPhaseIndex,
                        "progress_pct": analysisDisplayedPercentage
                    ]
                )
            }
        }
    }

    @MainActor
    private func retryScan() {
        HapticManager.shared.impact(.light)
        analysisTask?.cancel()
        elapsedTask?.cancel()
        onRetryScan?()
    }

    @MainActor
    private func complete(with result: FaceScanResult) {
        guard !didCompleteAnalysis else { return }
        didCompleteAnalysis = true

        // Ancre = analyse réelle ; le slider studio ne doit être appliqué qu’une seule fois.
        let base = baseResult ?? result
        var final: FaceScanResult
        if showsCreatorControls {
            creatorMode.resultQuality = qualityDraft
            final = creatorMode.rebuildResult(base, quality: qualityDraft)
            final.studioFraming = framingDraft.isIdentity ? nil : framingDraft.clamped()
        } else {
            final = result
        }
        // Upsert systématique : import photo / studio doivent bien remplacer le latest.
        FaceScanHistoryStore.shared.upsert(final)
        ProcessDebloatTrajectoryStore.shared.recordScan(final)

        onComplete(final)

        guard showsResultScreen else {
            onDismiss()
            return
        }

        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            didSaveScan = true
        }
        HapticManager.shared.notification(.success)

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1200))
            guard !Task.isCancelled else { return }
            onDismiss()
        }
    }

    private func saveScanBar(result: FaceScanResult) -> some View {
        Group {
            if didSaveScan {
                scanSavedConfirmation
            } else {
                OnboardingCreatePlanButton(
                    title: AppCopy.t("Enregistrer le scan", en: "Save the scan")
                ) {
                    HapticManager.shared.impact(.medium)
                    complete(with: result)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 62)
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(FaceScanWhoopPalette.canvas)
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: didSaveScan)
    }

    private var scanSavedConfirmation: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color(red: 0.30, green: 0.82, blue: 0.48))
            Text(AppCopy.t("Scan enregistré", en: "Scan saved"))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(FaceScanWhoopPalette.label)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(AppCopy.t("Scan enregistré", en: "Scan saved"))
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

    private var showsDevRescanButton: Bool {
        guard onRetryScan != nil else { return false }
        #if DEBUG
        return true
        #else
        return isCreatorUnlocked
        #endif
    }

    private var headerBar: some View {
        HStack {
            if showsDevRescanButton, displayResult == nil {
                Button(action: retryScan) {
                    Text(AppCopy.t("DEV", en: "DEV"))
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.4)
                        .foregroundStyle(headerForeground.opacity(0.72))
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background {
                            Capsule()
                                .strokeBorder(headerForeground.opacity(0.22), lineWidth: 1)
                        }
                }
                .buttonStyle(.processPlain)
                .accessibilityLabel(AppCopy.t("Revenir au scan du visage", en: "Back to face scan"))
                .frame(minWidth: 44, alignment: .leading)
            } else {
                Color.clear
                    .frame(width: 44, height: 44)
            }

            Spacer(minLength: 0)

            Text(displayResult == nil ? AppCopy.t("Analyse", en: "Analysis") : formattedHeaderDate)
                .font(.system(size: displayResult == nil ? 17 : 15, weight: .semibold))
                .foregroundStyle(headerForeground)
                .tracking(0)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 0)

            Color.clear
                .frame(width: 44, height: 44)
        }
    }

    @ViewBuilder
    private func studioResultsBody(result: FaceScanResult, base: FaceScanResult) -> some View {
        let usesOnboardingDeep = showsCreatorControls
            && creatorMode.scanResultsLayout == .onboardingDeep

        if usesOnboardingDeep {
            VStack(spacing: 0) {
                FaceScanWhoopScoreRing(
                    result: result,
                    studioFraming: framingDraft,
                    allowsStudioFraming: showsCreatorControls,
                    onStudioFramingChange: { framing in
                        framingDraft = framing.clamped()
                    },
                    showsGlobalScore: false
                )
                .padding(.bottom, 22)

                OnboardingFaceDeepAnalysisView(
                    result: result,
                    ringScale: 1,
                    showsScoreRing: false,
                    showsUnlockTeaser: false
                )
                .padding(.horizontal, 16)

                studioControlsAccessory
            }
        } else {
            FaceScanWhoopInlineResults(
                result: result,
                history: FaceScanHistoryStore.shared.history,
                prefersPassedResult: showsCreatorControls,
                evolutionAnchor: base,
                animateRevealOnce: true,
                allowsStudioFraming: showsCreatorControls,
                studioQuality: showsCreatorControls ? qualityDraft : nil,
                studioFraming: framingDraft,
                onStudioFramingChange: { framing in
                    framingDraft = framing.clamped()
                },
                bottomAccessory: {
                    studioControlsAccessory
                }
            )
        }
    }

    @ViewBuilder
    private var studioControlsAccessory: some View {
        if showsCreatorControls {
            VStack(spacing: 14) {
                FaceScanStudioQualitySlider(quality: $qualityDraft) { value in
                    creatorMode.resultQuality = value
                }

                FaceScanStudioResultsLayoutPicker(layout: $creatorMode.scanResultsLayout)
            }
            .padding(.top, 16)
            .padding(.horizontal, 16)
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

        let analysisStartedAt = Date()

        let result = await FaceScanService.recordScan(
            payload: payload,
            markers: markers,
            profile: profile
        )

        FaceScanHistoryStore.shared.reloadForUser(userId: profile?.userId)

        let minimumAnalysisDuration: TimeInterval = 6.0
        let elapsed = Date().timeIntervalSince(analysisStartedAt)
        if elapsed < minimumAnalysisDuration {
            try? await Task.sleep(nanoseconds: UInt64((minimumAnalysisDuration - elapsed) * 1_000_000_000))
        }

        analysisTask?.cancel()
        await finishProgressAnimation()
        elapsedTask?.cancel()
        HapticManager.shared.notification(.success)

        if showsResultScreen {
            framingDraft = result.resolvedStudioFraming
            baseResult = result
        } else {
            // Onboarding / flux sans résultats inline : applique le rendu studio si besoin.
            let unlocked = isCreatorUnlocked
            let final = unlocked
                ? creatorMode.rebuildResult(result, quality: creatorMode.resultQuality)
                : result
            if unlocked {
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

    @MainActor
    private func trackMossAnalysisSubphaseIfNeeded(stepIndex: Int) {
        guard tracksOnboardingMossFunnel,
              steps.indices.contains(stepIndex),
              stepIndex != lastTrackedMossSubphaseIndex else { return }
        lastTrackedMossSubphaseIndex = stepIndex
        let step = steps[stepIndex]
        ProcessAnalytics.trackMossAction(
            page: .faceScanAnalyzing,
            action: "subphase_reached",
            extra: [
                "subphase_id": step.id,
                "subphase_index": stepIndex,
                "subphase_label": step.phaseLabel
            ]
        )
    }

    private func startProgressAnimation() {
        analysisTask?.cancel()

        let tickInterval = OnboardingAnalysisProgressConfig.tickIntervalNs
        let leadDuration: TimeInterval = 6.0

        analysisTask = Task {
            try? await Task.sleep(nanoseconds: 40_000_000)
            guard !Task.isCancelled else { return }

            let startTime = Date()

            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(startTime)
                let normalized = min(1, elapsed / leadDuration)
                let eased = Self.slowStartProgress(normalized)
                let stepIndex = min(steps.count - 1, Int(eased * Double(max(steps.count, 1))))

                await MainActor.run {
                    analysisProgress = eased
                    analysisDisplayedPercentage = Int((eased * 100).rounded())
                    analysisPhaseIndex = stepIndex
                    analysisPhaseLabel = steps[stepIndex].phaseLabel
                    trackMossAnalysisSubphaseIfNeeded(stepIndex: stepIndex)
                }

                if normalized >= 1 { break }
                try? await Task.sleep(nanoseconds: tickInterval)
            }
        }
    }

    @MainActor
    private func finishProgressAnimation() async {
        analysisTask?.cancel()
        elapsedTask?.cancel()

        let start = analysisProgress
        if start >= 0.995 {
            analysisProgress = 1
            analysisDisplayedPercentage = 100
            return
        }
        let stepsCount = 6
        for i in 1...stepsCount {
            let t = Double(i) / Double(stepsCount)
            analysisProgress = start + (1.0 - start) * t
            analysisDisplayedPercentage = Int((analysisProgress * 100).rounded())
            analysisPhaseIndex = steps.count - 1
            analysisPhaseLabel = steps[steps.count - 1].phaseLabel
            try? await Task.sleep(for: .milliseconds(20))
        }
        analysisProgress = 1
        analysisDisplayedPercentage = 100
    }

    /// Lent au départ, puis ça avance sans freiner à la fin.
    private static func slowStartProgress(_ t: Double) -> Double {
        let x = min(1, max(0, t))
        return x * x * (1.35 - 0.35 * x)
    }
}

// MARK: - 3 barres d’analyse

private struct FaceScanAnalysisProgressBars: View {
    @Environment(\.colorScheme) private var colorScheme

    let steps: [OnboardingAnalysisProgressConfig.ProgressStep]
    let progress: Double

    private let barHeight: CGFloat = 16

    private var fillGradient: LinearGradient {
        PaywallBevelTheme.paywallProTitleGradient(for: colorScheme)
    }

    private var fillGlow: Color {
        PaywallBevelTheme.accentBlueGlow(for: colorScheme)
    }

    private var completeAccent: Color {
        colorScheme == .dark
            ? Color(red: 0.52, green: 0.88, blue: 1.0)
            : Color(red: 0.14, green: 0.50, blue: 0.96)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                let value = barProgress(for: index)
                let isComplete = value >= 0.999
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Text(step.phaseLabel)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(OnboardingProgramCreationPalette.subtitle)

                        if isComplete {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(completeAccent)
                                .transition(.scale.combined(with: .opacity))
                        }

                        Spacer(minLength: 8)

                        Text("\(Int((value * 100).rounded()))%")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(OnboardingProgramCreationPalette.hint)
                            .monospacedDigit()
                    }

                    GeometryReader { geo in
                        let clamped = min(max(value, 0), 1)
                        let fillWidth = max(barHeight, geo.size.width * clamped)

                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(OnboardingProgramCreationPalette.barTrack)

                            Capsule()
                                .fill(fillGradient)
                                .frame(width: fillWidth, height: barHeight)
                                .shadow(
                                    color: fillGlow.opacity(colorScheme == .dark ? 0.45 : 0.55),
                                    radius: 8,
                                    x: 0,
                                    y: 0
                                )
                        }
                    }
                    .frame(height: barHeight)
                }
            }
        }
        .animation(.linear(duration: 0.08), value: progress)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(AppCopy.t("Analyse en cours", en: "Analysis in progress"))
        .accessibilityValue("\(Int((min(1, max(0, progress)) * 100).rounded()))%")
    }

    /// Les 3 barres partent ensemble, avec des courbes différentes pour un remplissage irrégulier.
    private func barProgress(for index: Int) -> Double {
        let t = min(1, max(0, progress))
        guard t > 0 else { return 0 }
        if t >= 0.995 { return 1 }

        switch index {
        case 0:
            return clamp01(pow(t, 1.12) + wobble(t, amplitude: 0.018, waves: 1.5, phase: 0.2))
        case 1:
            return clamp01(pow(t, 1.32) + wobble(t, amplitude: 0.02, waves: 1.7, phase: 0.85))
        default:
            return clamp01(pow(t, 1.22) + wobble(t, amplitude: 0.016, waves: 1.55, phase: 1.6))
        }
    }

    private func wobble(_ t: Double, amplitude: Double, waves: Double, phase: Double) -> Double {
        sin((t * waves + phase) * .pi) * amplitude * (1 - t)
    }

    private func clamp01(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}

// MARK: - Hero média (vidéo / snapshot)

struct FaceScanAnalysisHeroView: View {
    let payload: FaceScanCapturePayload
    var showsAnalysisSweep: Bool = true

    @State private var resolvedVideoURL: URL?

    private let heroDiameter: CGFloat = 200

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
        TimelineView(.animation(minimumInterval: 1.0 / 15.0)) { context in
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
