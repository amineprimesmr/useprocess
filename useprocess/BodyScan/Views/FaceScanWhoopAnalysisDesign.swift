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

                    FaceScanWhoopIndicatorTrendsSection(history: history)
                        .padding(.horizontal, 16)
                        .padding(.top, 28)

                    Spacer(minLength: 40)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showsAnalysisInfo) {
            FaceScanWhoopAnalysisInfoSheet(
                result: result,
                history: history.isEmpty ? FaceScanHistoryStore.shared.history : history,
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

    var body: some View {
        VStack(spacing: 0) {
            FaceScanWhoopScoreRing(result: result)
                .padding(.bottom, 22)

            FaceScanWhoopMetricsCard(result: result)
                .padding(.horizontal, 16)

            FaceScanWhoopIndicatorTrendsSection(history: history)
                .padding(.horizontal, 16)
                .padding(.top, 28)

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
        FaceScanIndicators.displayPercent(for: kind, result: result)
    }

    private var zone: FaceScanIndicators.WellnessZone {
        FaceScanIndicators.displayZone(for: kind, result: result)
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

// MARK: - Évolution par indicateur

private struct FaceScanWhoopIndicatorTrendsSection: View {
    @Environment(\.appTheme) private var theme

    let history: [FaceScanResult]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Santé visage")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(FaceScanWhoopPalette.label)

                Text("Évolution par rapport aux 7 jours précédents")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(FaceScanWhoopPalette.secondary)
            }

            ForEach(FaceScanIndicators.Kind.allCases) { kind in
                FaceScanWhoopIndicatorTrendCard(
                    kind: kind,
                    history: history,
                    theme: theme
                )
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

                if let latest = daySlots.compactMap(\.value).last {
                    Text("\(latest)%")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(FaceScanWhoopPalette.label)
                        .monospacedDigit()
                }
            }

            if daySlots.compactMap(\.value).count < 2 {
                Text("Au moins 2 scans sur 7 jours pour afficher la courbe.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(FaceScanWhoopPalette.secondary)
                    .frame(maxWidth: .infinity, minHeight: 100, alignment: .center)
            } else {
                FaceScanWhoopLineChart(
                    slots: daySlots,
                    color: kind.trendColor
                )
                .frame(height: 148)
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
    let analysis: FaceScanAnalysisContent

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

                        if analysis.isValid {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("ANALYSE IA")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(FaceScanWhoopPalette.secondary)
                                    .tracking(0.8)

                                Text(analysis.summary)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(FaceScanWhoopPalette.label)
                                    .fixedSize(horizontal: false, vertical: true)

                                ForEach(analysis.signals, id: \.self) { signal in
                                    Text("• \(signal)")
                                        .font(.system(size: 13))
                                        .foregroundStyle(FaceScanWhoopPalette.secondary)
                                }
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background {
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .fill(FaceScanWhoopPalette.card)
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
            .navigationTitle("Détails du scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(FaceScanWhoopPalette.canvas, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }
                        .foregroundStyle(FaceScanWhoopPalette.label)
                }
            }
        }
        .preferredColorScheme(.dark)
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
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "EEE d MMM · HH:mm"
        return formatter.string(from: scan.createdAt).capitalized
    }

    private func loadThumbnail() {
        let reconciled = FaceScanImageStore.reconcileMediaMetadata(for: scan)
        if let filename = FaceScanImageStore.resolvedSnapshotFilename(for: reconciled) {
            thumbnail = FaceScanImageStore.load(filename: filename)
        }
    }
}
