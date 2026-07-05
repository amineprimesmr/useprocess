import SwiftUI

/// Session post-capture : animation d'analyse (Claude, HealthKit…) puis écran résultats WHOOP.
struct FaceScanAnalysisFlowView: View {
    @Environment(\.colorScheme) private var colorScheme

    let payload: FaceScanCapturePayload
    let markers: FaceWellnessMarkers
    var profile: UnifiedUserProfile?
    var showsResultScreen: Bool = true
    var onDismiss: () -> Void
    var onComplete: (FaceScanResult) -> Void

    @State private var completedResult: FaceScanResult?
    @State private var analysisProgress: Double = 0
    @State private var analysisDisplayedPercentage = 0
    @State private var analysisPhaseIndex = 0
    @State private var analysisPhaseLabel = OnboardingAnalysisProgressConfig.faceScanAnalysisSteps[0].phaseLabel
    @State private var analysisElapsedSeconds = 0
    @State private var analysisTask: Task<Void, Never>?
    @State private var elapsedTask: Task<Void, Never>?

    private var steps: [OnboardingAnalysisProgressConfig.ProgressStep] {
        OnboardingAnalysisProgressConfig.faceScanAnalysisSteps
    }

    var body: some View {
        ZStack {
            analysisBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: completedResult == nil ? 28 : 0) {
                    headerBar
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, completedResult == nil ? 0 : 18)

                    if let result = completedResult, showsResultScreen {
                        FaceScanWhoopInlineResults(
                            result: result,
                            history: FaceScanHistoryStore.shared.history
                        )
                        .transition(.opacity)
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
        }
        .animation(.easeInOut(duration: 0.38), value: completedResult?.id)
        .task {
            await runAnalysis()
        }
        .onDisappear {
            analysisTask?.cancel()
            elapsedTask?.cancel()
        }
    }

    private var analysisBackground: Color {
        FaceScanWhoopPalette.canvas
    }

    private var headerForeground: Color {
        FaceScanWhoopPalette.label
    }

    private var headerBar: some View {
        HStack {
            Color.clear
                .frame(width: 44, height: 44)

            Spacer(minLength: 0)

            Text(completedResult == nil ? "ANALYSE DU SCAN" : formattedHeaderDate)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(headerForeground)
                .tracking(0.6)

            Spacer(minLength: 0)

            if completedResult != nil, showsResultScreen {
                Button("Terminer") {
                    if let result = completedResult {
                        onComplete(result)
                    }
                    onDismiss()
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
        guard let result = completedResult else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "EEE., d MMM"
        return formatter.string(from: result.createdAt).uppercased()
    }

    @MainActor
    private func runAnalysis() async {
        startElapsedTimer()
        startProgressAnimation()

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
            completedResult = result
        } else {
            onComplete(result)
            onDismiss()
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
        for step in 1...stepsCount {
            let t = Double(step) / Double(stepsCount)
            let eased = start + (1 - start) * (1 - pow(1 - t, 2))
            analysisProgress = eased
            analysisDisplayedPercentage = Int((eased * 100).rounded())
            analysisPhaseIndex = min(steps.count - 1, Int(eased * Double(steps.count)))
            analysisPhaseLabel = steps[analysisPhaseIndex].phaseLabel
            try? await Task.sleep(for: .milliseconds(45))
        }

        analysisProgress = 1
        analysisDisplayedPercentage = 100
        analysisPhaseIndex = steps.count - 1
        analysisPhaseLabel = steps.last?.phaseLabel ?? analysisPhaseLabel
    }
}

// MARK: - Hero vidéo

struct FaceScanAnalysisHeroView: View {
    let payload: FaceScanCapturePayload
    var showsAnalysisSweep: Bool = true

    private let heroDiameter: CGFloat = 248

    @State private var resolvedVideoURL: URL?

    var body: some View {
        ZStack {
            mediaLayer
                .frame(width: heroDiameter, height: heroDiameter)
                .clipShape(Circle())

            if showsAnalysisSweep {
                FaceScanAnalysisSweepOverlay(diameter: heroDiameter)
                    .frame(width: heroDiameter, height: heroDiameter)
                    .clipShape(Circle())
            }

            Circle()
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 1.5)
                .frame(width: heroDiameter, height: heroDiameter)
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
        guard payload.videoFilename != nil else { return }
        for _ in 0..<24 {
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
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
            let elapsed = context.date.timeIntervalSinceReferenceDate
            let phase = elapsed.truncatingRemainder(dividingBy: cycleDuration) / cycleDuration
            let sweepProgress = smoothPingPong(phase)

            GeometryReader { geometry in
                let width = geometry.size.width
                let height = geometry.size.height
                let y = height * sweepProgress
                let maskHeight = max(44, height * maskBandHeightRatio)

                ZStack {
                    Rectangle()
                        .fill(maskGradient)
                        .frame(width: width, height: maskHeight)
                        .blur(radius: 7)
                        .position(x: width * 0.5, y: y)

                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    lineColor.opacity(0),
                                    lineColor.opacity(colorScheme == .dark ? 0.92 : 0.98),
                                    lineColor.opacity(0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: width * 0.92, height: 1.6)
                        .shadow(color: lineGlow.opacity(0.55), radius: 5, y: 0)
                        .position(x: width * 0.5, y: y)

                    Rectangle()
                        .fill(lineColor.opacity(colorScheme == .dark ? 0.42 : 0.34))
                        .frame(width: width * 0.72, height: 0.8)
                        .blur(radius: 0.4)
                        .position(x: width * 0.5, y: y)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var lineColor: Color {
        colorScheme == .dark
            ? Color(red: 0.78, green: 0.96, blue: 1.0)
            : .white
    }

    private var lineGlow: Color {
        colorScheme == .dark
            ? Color(red: 0.35, green: 0.92, blue: 1.0)
            : Color.white
    }

    private var maskGradient: LinearGradient {
        let peak = colorScheme == .dark ? 0.24 : 0.30
        return LinearGradient(
            colors: [
                lineGlow.opacity(0),
                lineGlow.opacity(peak * 0.45),
                lineGlow.opacity(peak),
                lineGlow.opacity(peak * 0.45),
                lineGlow.opacity(0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func smoothPingPong(_ phase: Double) -> CGFloat {
        let wave = sin((phase * 2 * .pi) - (.pi / 2))
        let normalized = (wave + 1) * 0.5
        let inset = 0.1
        return CGFloat(inset + normalized * (1 - inset * 2))
    }
}
