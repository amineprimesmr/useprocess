import SwiftUI

/// Profil — évolution du score debloat (scans visage), style Recap.
struct ProfileDebloatScoreSection: View {
    var isOnboardingPreview: Bool = false

    @Environment(\.appTheme) private var theme
    @Environment(\.scenePhase) private var scenePhase
    @Bindable private var scanStore = FaceScanHistoryStore.shared
    @Bindable private var calibration = ProcessCalibrationMode.shared

    @State private var selectedRange: RangeKind = .week

    private var isCalibrationLocked: Bool {
        calibration.isLocked(forcePreview: isOnboardingPreview)
    }

    private var calibrationRemainingDays: Int {
        calibration.displayedRemainingDays(forcePreview: isOnboardingPreview)
    }

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = ProcessAppLanguage.shared.locale
        cal.firstWeekday = 2
        return cal
    }

    private var today: Date {
        calendar.startOfDay(for: Date())
    }

    private var realPoints: [DayScore] {
        series(for: selectedRange)
    }

    private var usesDemoCurve: Bool {
        realPoints.count < 2
    }

    private var points: [DayScore] {
        usesDemoCurve ? demoSeries(for: selectedRange) : realPoints
    }

    private var latestScore: Int? {
        scanStore.latestResult.map(\.displayWellnessScore)
    }

    private var scoreDelta: Int? {
        guard !usesDemoCurve, realPoints.count >= 2,
              let first = realPoints.first,
              let last = realPoints.last else { return nil }
        return Int(last.score.rounded()) - Int(first.score.rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            heroBlock
                .padding(.bottom, 18)

            rangeChips
                .padding(.bottom, 22)

            ProfileDebloatScoreChart(
                points: points,
                theme: theme,
                isDemo: usesDemoCurve
            )
            .frame(height: 236)
            .processCalibrationLocked(
                isCalibrationLocked,
                remainingDays: calibrationRemainingDays,
                surface: .progressChart,
                cornerRadius: 18
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 18)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
        .onAppear { calibration.refresh() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            calibration.refresh()
        }
    }

    private var heroBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(formattedScore)
                .font(.system(size: 42, weight: .bold, design: .default))
                .foregroundStyle(theme.primaryText)
                .tracking(-0.8)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .monospacedDigit()

            Text(AppCopy.t("ÉVOLUTION DU SCORE DEBLOAT", en: "DEBLOAT SCORE EVOLUTION"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.secondaryText.opacity(0.78))
                .tracking(0.7)

            insightLine
                .padding(.top, 6)
        }
    }

    private var insightLine: some View {
        let mint = ProfileDebloatScorePalette.mint
        let loss = Color(red: 0.95, green: 0.45, blue: 0.38)

        return Group {
            if isCalibrationLocked {
                Text(ProcessCalibrationCopy.progressInsight)
                    .foregroundStyle(theme.primaryText.opacity(0.92))
            } else if usesDemoCurve {
                Text(AppCopy.t(
                    "Scanne ton visage pour remplacer cette courbe d’exemple par ta vraie évolution.",
                    en: "Scan your face to replace this sample curve with your real evolution."
                ))
                .foregroundStyle(theme.primaryText.opacity(0.92))
            } else if let delta = scoreDelta, delta > 0 {
                Text(AppCopy.t(
                    "Ton score a gagné ",
                    en: "Your score is up "
                ))
                .foregroundStyle(theme.primaryText.opacity(0.92))
                + Text(AppCopy.t("+\(delta) pts", en: "+\(delta) pts"))
                    .foregroundStyle(mint)
                + Text(AppCopy.t(" sur cette période.", en: " over this period."))
                    .foregroundStyle(theme.primaryText.opacity(0.92))
            } else if let delta = scoreDelta, delta < 0 {
                Text(AppCopy.t(
                    "Ton score a perdu ",
                    en: "Your score is down "
                ))
                .foregroundStyle(theme.primaryText.opacity(0.92))
                + Text(AppCopy.t("\(delta) pts", en: "\(delta) pts"))
                    .foregroundStyle(loss)
                + Text(AppCopy.t(" sur cette période.", en: " over this period."))
                    .foregroundStyle(theme.primaryText.opacity(0.92))
            } else {
                Text(AppCopy.t(
                    "Score stable sur cette période.",
                    en: "Score is stable over this period."
                ))
                .foregroundStyle(theme.primaryText.opacity(0.92))
            }
        }
        .font(.system(size: 16, weight: .regular))
        .fixedSize(horizontal: false, vertical: true)
    }

    private var rangeChips: some View {
        HStack(spacing: 8) {
            ForEach(RangeKind.allCases) { range in
                Button {
                    HapticManager.shared.selection()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedRange = range
                    }
                } label: {
                    Text(range.title)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(theme.primaryText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .overlay {
                            Capsule(style: .continuous)
                                .strokeBorder(
                                    theme.primaryText.opacity(selectedRange == range ? 0.92 : 0.28),
                                    lineWidth: 1
                                )
                        }
                }
                .buttonStyle(.processPlain)
            }
        }
        .disabled(isCalibrationLocked)
        .opacity(isCalibrationLocked ? 0.45 : 1)
        .allowsHitTesting(!isCalibrationLocked)
    }

    private var formattedScore: String {
        guard let latestScore else { return "—" }
        return "\(latestScore)%"
    }

    private var accessibilityLabel: String {
        AppCopy.t(
            "\(formattedScore), évolution du score debloat",
            en: "\(formattedScore), debloat score evolution"
        )
    }

    private func series(for range: RangeKind) -> [DayScore] {
        let start: Date
        switch range {
        case .week:
            start = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        case .month:
            start = calendar.date(byAdding: .day, value: -29, to: today) ?? today
        case .all:
            start = calendar.date(byAdding: .day, value: -89, to: today) ?? today
        }

        var latestByDay: [Date: FaceScanResult] = [:]
        for scan in scanStore.history {
            let day = calendar.startOfDay(for: scan.createdAt)
            guard day >= start, day <= today else { continue }
            if let existing = latestByDay[day] {
                if scan.createdAt >= existing.createdAt {
                    latestByDay[day] = scan
                }
            } else {
                latestByDay[day] = scan
            }
        }

        return latestByDay.keys.sorted().compactMap { day in
            guard let scan = latestByDay[day] else { return nil }
            return DayScore(date: day, score: Double(scan.displayWellnessScore))
        }
    }

    private func demoSeries(for range: RangeKind) -> [DayScore] {
        let count: Int
        switch range {
        case .week: count = 11
        case .month: count = 30
        case .all: count = 90
        }
        let shape: [Double] = [
            58, 60, 59, 63, 62, 66, 65, 69, 68, 72, 71, 75, 74, 78, 77, 81
        ]
        return (0..<count).compactMap { index in
            guard let date = calendar.date(byAdding: .day, value: -(count - 1 - index), to: today) else {
                return nil
            }
            let sampleIndex = Int(
                round(Double(index) / Double(max(count - 1, 1)) * Double(shape.count - 1))
            )
            return DayScore(
                date: calendar.startOfDay(for: date),
                score: shape[sampleIndex]
            )
        }
    }

    enum RangeKind: String, CaseIterable, Identifiable {
        case week
        case month
        case all

        var id: String { rawValue }

        @MainActor
        var title: String {
            switch self {
            case .week: AppCopy.t("Semaine", en: "Week")
            case .month: AppCopy.t("Mois", en: "Month")
            case .all: AppCopy.t("Tout", en: "All")
            }
        }
    }
}

private struct DayScore: Identifiable {
    let date: Date
    let score: Double
    var id: Date { date }
}

private struct ProfileDebloatScoreChart: View {
    let points: [DayScore]
    let theme: AppTheme
    var isDemo: Bool = false

    private let scoreMin: Double = 0
    private let scoreMax: Double = 100

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                chartCanvas
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                yAxis
            }
            .frame(maxHeight: .infinity)

            xAxis
        }
    }

    private var yAxis: some View {
        VStack {
            Text("100")
            Spacer(minLength: 0)
            Text("50")
            Spacer(minLength: 0)
            Text("0")
        }
        .font(.system(size: 11, weight: .regular))
        .foregroundStyle(theme.secondaryText.opacity(0.72))
        .frame(width: 28)
        .monospacedDigit()
    }

    private var xAxis: some View {
        let labels = xLabels
        return HStack(spacing: 0) {
            ForEach(Array(labels.enumerated()), id: \.offset) { _, item in
                Text(item)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(theme.secondaryText.opacity(0.72))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.trailing, 36)
    }

    private var chartCanvas: some View {
        GeometryReader { _ in
            let values = points.map(\.score)
            let line = ProfileAnalyticsLineShape(values: values, valueMin: scoreMin, valueMax: scoreMax)
            let area = ProfileAnalyticsAreaShape(values: values, valueMin: scoreMin, valueMax: scoreMax)
            let grid = theme.primaryText.opacity(theme.isDark ? 0.14 : 0.10)

            ZStack {
                gridLayer(color: grid)

                area
                    .fill(
                        LinearGradient(
                            colors: [
                                theme.primaryText.opacity(theme.isDark ? 0.22 : 0.12),
                                theme.primaryText.opacity(0.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                line
                    .stroke(
                        theme.primaryText.opacity(isDemo ? 0.72 : 0.92),
                        style: StrokeStyle(
                            lineWidth: isDemo ? 1.35 : 1.8,
                            lineCap: .round,
                            lineJoin: .round,
                            dash: isDemo ? [5, 4] : []
                        )
                    )
            }
        }
    }

    private func gridLayer(color: Color) -> some View {
        Canvas { context, canvasSize in
            let rows = 2
            let cols = max(xLabels.count - 1, 1)

            for row in 0...rows {
                let y = canvasSize.height * CGFloat(row) / CGFloat(rows)
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: canvasSize.width, y: y))
                context.stroke(path, with: .color(color), lineWidth: 0.5)
            }

            for col in 0...cols {
                let x = canvasSize.width * CGFloat(col) / CGFloat(cols)
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: canvasSize.height))
                context.stroke(path, with: .color(color), lineWidth: 0.5)
            }
        }
        .allowsHitTesting(false)
    }

    private var xLabels: [String] {
        guard !points.isEmpty else { return [] }
        let formatter = DateFormatter()
        formatter.locale = ProcessAppLanguage.shared.locale
        formatter.dateFormat = "EEE"

        let count = min(5, points.count)
        guard count > 1 else {
            return [formattedWeekday(points[0].date, formatter: formatter)]
        }

        return (0..<count).map { index in
            let position = Double(index) / Double(count - 1)
            let pointIndex = Int(round(position * Double(points.count - 1)))
            return formattedWeekday(points[pointIndex].date, formatter: formatter)
        }
    }

    private func formattedWeekday(_ date: Date, formatter: DateFormatter) -> String {
        let raw = formatter.string(from: date)
        guard let first = raw.first else { return raw }
        return String(first).uppercased() + raw.dropFirst()
    }
}

private enum ProfileDebloatScorePalette {
    static let mint = Color(red: 0.42, green: 0.91, blue: 0.78)
}
