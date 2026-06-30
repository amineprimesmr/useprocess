import SwiftUI

/// Session post-capture : animation d'analyse (Claude, HealthKit…) puis écran résultats WHOOP.
struct FaceScanAnalysisFlowView: View {
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
            FaceScanWhoopPalette.canvas.ignoresSafeArea()

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
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
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
        .preferredColorScheme(.dark)
        .task {
            await runAnalysis()
        }
        .onDisappear {
            analysisTask?.cancel()
            elapsedTask?.cancel()
        }
    }

    private var headerBar: some View {
        HStack {
            Button(action: {
                if let result = completedResult {
                    onComplete(result)
                }
                onDismiss()
            }) {
                Image(systemName: completedResult == nil ? "xmark" : "chevron.left")
                    .font(.system(size: completedResult == nil ? 16 : 17, weight: .semibold))
                    .foregroundStyle(FaceScanWhoopPalette.label)
                    .frame(width: 44, height: 44, alignment: .leading)
            }

            Spacer(minLength: 0)

            Text(completedResult == nil ? "ANALYSE DU SCAN" : formattedHeaderDate)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(FaceScanWhoopPalette.label)
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
                .foregroundStyle(FaceScanWhoopPalette.label)
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

        let result = await FaceScanService.recordScan(
            payload: payload,
            markers: markers,
            profile: profile
        )

        FaceScanHistoryStore.shared.reloadForUser(userId: profile?.userId)

        await finishProgressAnimation()
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
                let normalized = min(0.88, elapsed / leadDuration)
                let eased = 1.0 - pow(1.0 - normalized, 2.1)
                let stepIndex = min(steps.count - 1, Int(eased * Double(steps.count)))

                await MainActor.run {
                    analysisProgress = eased
                    analysisDisplayedPercentage = Int((eased * 100).rounded())
                    analysisPhaseIndex = stepIndex
                    analysisPhaseLabel = steps[stepIndex].phaseLabel
                }

                if normalized >= 0.88 { break }
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

    private let heroDiameter: CGFloat = 248

    @State private var resolvedVideoURL: URL?

    var body: some View {
        ZStack {
            mediaLayer
                .frame(width: heroDiameter, height: heroDiameter)
                .clipShape(Circle())

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
