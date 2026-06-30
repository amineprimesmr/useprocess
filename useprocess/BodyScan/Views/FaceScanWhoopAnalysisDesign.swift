import SwiftUI

// MARK: - Tokens WHOOP

enum FaceScanWhoopPalette {
    static let canvas = Color(red: 0.04, green: 0.04, blue: 0.045)
    static let card = Color(red: 0.11, green: 0.11, blue: 0.115)
    static let ringTrack = Color.white.opacity(0.10)
    static let label = Color.white.opacity(0.92)
    static let secondary = Color.white.opacity(0.55)
    static let insufficient = Color(red: 0.93, green: 0.52, blue: 0.28)
    static let sufficient = Color(red: 0.42, green: 0.44, blue: 0.47)
    static let optimal = Color(red: 0.36, green: 0.78, blue: 0.58)
    static let segmentIdle = Color.white.opacity(0.14)

    static func ringColor(for zone: FaceScanIndicators.WellnessZone) -> Color {
        switch zone {
        case .insufficient: return insufficient
        case .sufficient: return sufficient
        case .optimal: return optimal
        }
    }
}

// MARK: - Écran principal

struct FaceScanWhoopAnalysisScreen: View {
    let result: FaceScanResult
    var previous: FaceScanResult?
    var history: [FaceScanResult] = []
    var showsDoneButton: Bool = false
    var onDone: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var showsAnalysisInfo = false

    private var analysis: FaceScanAnalysisContent {
        CoachEngine.parsedFaceAnalysis(for: result)
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

                    FaceScanWhoopScoreRing(result: result)
                        .padding(.bottom, 22)

                    FaceScanWhoopMetricsCard(result: result)
                        .padding(.horizontal, 16)

                    if !history.isEmpty {
                        FaceScanWhoopHistorySection(
                            result: result,
                            history: history
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 28)
                    }

                    if analysis.isValid {
                        FaceScanWhoopAnalysisSummary(analysis: analysis)
                            .padding(.horizontal, 16)
                            .padding(.top, 24)
                    }

                    Spacer(minLength: 40)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showsAnalysisInfo) {
            FaceScanWhoopAnalysisInfoSheet(
                result: result,
                analysis: analysis
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
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(FaceScanWhoopPalette.label)
                .textCase(.uppercase)
                .tracking(0.6)

            Spacer()

            if showsDoneButton, let onDone {
                Button("Terminer", action: onDone)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(FaceScanWhoopPalette.label)
                    .frame(minWidth: 44, alignment: .trailing)
            } else {
                Button {
                    showsAnalysisInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(FaceScanWhoopPalette.label)
                        .frame(width: 44, height: 44, alignment: .trailing)
                }
            }
        }
    }

    private var formattedHeaderDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "EEE., d MMM"
        return formatter.string(from: result.createdAt).uppercased()
    }
}

/// Corps résultats WHOOP — réutilisable dans le flux d'analyse inline.
struct FaceScanWhoopInlineResults: View {
    let result: FaceScanResult
    var history: [FaceScanResult] = []

    private var analysis: FaceScanAnalysisContent {
        CoachEngine.parsedFaceAnalysis(for: result)
    }

    var body: some View {
        VStack(spacing: 0) {
            FaceScanWhoopScoreRing(result: result)
                .padding(.bottom, 22)

            FaceScanWhoopMetricsCard(result: result)
                .padding(.horizontal, 16)

            if !history.isEmpty {
                FaceScanWhoopHistorySection(
                    result: result,
                    history: history
                )
                .padding(.horizontal, 16)
                .padding(.top, 28)
            }

            if analysis.isValid {
                FaceScanWhoopAnalysisSummary(analysis: analysis)
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
            }

            Spacer(minLength: 40)
        }
    }
}

// MARK: - Anneau + photo

private struct FaceScanWhoopScoreRing: View {
    let result: FaceScanResult

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
                        Text("\(displayScore)%")
                            .font(.system(size: 46, weight: .bold))
                            .foregroundStyle(.white)
                            .monospacedDigit()

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
                    .trim(from: 0, to: progress)
                    .stroke(
                        ringProgressColor,
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                    )
                    .frame(width: ringSize, height: ringSize)
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: ringSize, height: ringSize)
        }
        .frame(maxWidth: .infinity)
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

    let result: FaceScanResult

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(FaceScanIndicators.Kind.allCases.enumerated()), id: \.element.id) { index, kind in
                FaceScanWhoopMetricRow(
                    kind: kind,
                    result: result
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                if index < FaceScanIndicators.Kind.allCases.count - 1 {
                    Divider()
                        .overlay(Color.white.opacity(0.08))
                        .padding(.leading, 52)
                }
            }

            legend
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 16)
        }
        .background {
            cardShape
                .fill(.clear)
                .processGlassEffect(in: cardShape, interactive: false)
        }
        .clipShape(cardShape)
        .processHomeGlassCardShadow(isDark: theme.isDark)
    }

    private var legend: some View {
        HStack(spacing: 18) {
            legendItem(color: FaceScanWhoopPalette.insufficient, title: "Insuffisant")
            legendItem(color: FaceScanWhoopPalette.sufficient, title: "Suffisant")
            legendItem(color: FaceScanWhoopPalette.optimal, title: "Optimal")
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

private struct FaceScanWhoopMetricRow: View {
    let kind: FaceScanIndicators.Kind
    let result: FaceScanResult

    private var percent: Int {
        FaceScanIndicators.wellnessPercent(for: kind, result: result)
    }

    private var zone: FaceScanIndicators.WellnessZone {
        FaceScanIndicators.wellnessZone(for: kind, result: result)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: kind.systemImage)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(FaceScanWhoopPalette.label.opacity(0.88))
                .frame(width: 22)

            Text(kind.whoopLabel)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(FaceScanWhoopPalette.label.opacity(0.88))
                .tracking(0.3)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity, alignment: .leading)

            FaceScanWhoopZoneBar(activeZone: zone)
                .frame(width: 92)

            Text("\(percent)%")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(FaceScanWhoopPalette.label)
                .monospacedDigit()
                .frame(width: 44, alignment: .trailing)
        }
    }
}

private struct FaceScanWhoopZoneBar: View {
    let activeZone: FaceScanIndicators.WellnessZone

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
            .fill(isActive ? color(for: zone) : FaceScanWhoopPalette.segmentIdle)
            .frame(height: segmentHeight)
            .frame(maxWidth: .infinity)
    }

    private func color(for zone: FaceScanIndicators.WellnessZone) -> Color {
        switch zone {
        case .insufficient: return FaceScanWhoopPalette.insufficient
        case .sufficient: return FaceScanWhoopPalette.sufficient
        case .optimal: return FaceScanWhoopPalette.optimal
        }
    }
}

// MARK: - Historique

private struct FaceScanWhoopHistorySection: View {
    let result: FaceScanResult
    let history: [FaceScanResult]

    private var displayScore: Int {
        result.displayWellnessScore
    }

    private var deltaVsAverage: Int? {
        FaceScanIndicators.compositeDeltaVsAverage(for: result, history: history)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Scans des derniers jours")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(FaceScanWhoopPalette.label)

                Spacer()

                Label("Historique", systemImage: "pencil")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FaceScanWhoopPalette.secondary)
                    .labelStyle(.titleAndIcon)
            }

            Text(historySubtitle)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(FaceScanWhoopPalette.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("SCORE VISAGE")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(FaceScanWhoopPalette.secondary)
                    .tracking(0.5)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(displayScore)%")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(FaceScanWhoopPalette.label)
                        .monospacedDigit()

                    if let delta = deltaVsAverage {
                        HStack(spacing: 3) {
                            Image(systemName: delta >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                                .font(.system(size: 8))
                            Text("\(abs(delta))%")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(delta >= 0 ? FaceScanWhoopPalette.optimal : FaceScanWhoopPalette.insufficient)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var historySubtitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "EEE., d MMM"
        let day = formatter.string(from: result.createdAt)
        return "\(day.capitalized) par rapport aux 30 jours précédents"
    }
}

// MARK: - Résumé analyse

private struct FaceScanWhoopAnalysisSummary: View {
    @Environment(\.appTheme) private var theme

    let analysis: FaceScanAnalysisContent

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ANALYSE")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(FaceScanWhoopPalette.secondary)
                .tracking(0.8)

            Text(analysis.summary)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(FaceScanWhoopPalette.label)
                .fixedSize(horizontal: false, vertical: true)

            if !analysis.evolution.isEmpty {
                Text(analysis.evolution)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(FaceScanWhoopPalette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            cardShape
                .fill(.clear)
                .processGlassEffect(in: cardShape, interactive: false)
        }
        .clipShape(cardShape)
        .processHomeGlassCardShadow(isDark: theme.isDark)
    }
}

// MARK: - Info sheet

private struct FaceScanWhoopAnalysisInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    let result: FaceScanResult
    let analysis: FaceScanAnalysisContent

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let confidence = result.scanConfidence {
                        infoRow(
                            title: "Confiance",
                            value: FaceWellnessScore.confidenceLabel(for: confidence)
                        )
                    }

                    if let label = result.relativeSignals?.baselineLabel {
                        infoRow(title: "Baseline", value: label)
                    }

                    infoRow(
                        title: "Score global affiché",
                        value: "\(result.displayWellnessScore)% — moyenne des 5 indicateurs wellness"
                    )

                    infoRow(
                        title: "Score relatif baseline",
                        value: "\(result.resolvedFaceDayScore)% — variation vs ton historique, pas l’état absolu du jour"
                    )

                    Text("L’accueil, l’historique et l’anneau utilisent le score global wellness.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if analysis.isValid {
                        Divider()
                        Text(analysis.summary)
                            .font(.body)
                        ForEach(analysis.signals, id: \.self) { signal in
                            Text("• \(signal)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Détails du scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func infoRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.medium))
        }
    }
}
