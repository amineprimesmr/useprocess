import SwiftUI

// MARK: - Périodes

enum ProfileWeightChartPeriod: String, CaseIterable, Identifiable {
    case day = "1D"
    case week = "1W"
    case month = "1M"
    case sixMonths = "6M"
    case year = "1Y"

    var id: String { rawValue }

    var displayLabel: String { rawValue }

    var bucketCount: Int {
        switch self {
        case .day: return 24
        case .week: return 7
        case .month: return 30
        case .sixMonths: return 26
        case .year: return 52
        }
    }
}

struct ProfileWeightSpectrumBar: Identifiable, Equatable {
    let id: String
    let date: Date
    let value: Double?
    let hasData: Bool
}

enum ProfileWeightSpectrumPalette {
    static let inactive = Color(red: 0.82, green: 0.84, blue: 0.87)
    static let purple = Color(red: 0.482, green: 0.380, blue: 1.0)
    static let pink = Color(red: 1.0, green: 0.20, blue: 0.40)
    static let tooltipBackground = Color.black
    static let mutedLabel = Color.primary.opacity(0.38)
}

enum ProfileWeightSpectrumBuilder {

    static func bars(
        from history: [ProfileAnalyticsPoint],
        period: ProfileWeightChartPeriod
    ) -> [ProfileWeightSpectrumBar] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let sorted = history
            .filter { $0.value > 0 }
            .sorted { $0.date < $1.date }

        switch period {
        case .day:
            return hourlyBars(for: today, history: sorted, calendar: calendar)
        case .week:
            return dailyBars(
                endingAt: today,
                dayCount: 7,
                history: sorted,
                calendar: calendar,
                idPrefix: "week"
            )
        case .month:
            return dailyBars(
                endingAt: today,
                dayCount: 30,
                history: sorted,
                calendar: calendar,
                idPrefix: "month"
            )
        case .sixMonths:
            return weeklyBars(
                endingAt: today,
                weekCount: 26,
                history: sorted,
                calendar: calendar,
                idPrefix: "6m"
            )
        case .year:
            return weeklyBars(
                endingAt: today,
                weekCount: 52,
                history: sorted,
                calendar: calendar,
                idPrefix: "1y"
            )
        }
    }

    private static func hourlyBars(
        for day: Date,
        history: [ProfileAnalyticsPoint],
        calendar: Calendar
    ) -> [ProfileWeightSpectrumBar] {
        let daySamples = history.filter { calendar.isDate($0.date, inSameDayAs: day) }
        let fallback = history.last

        return (0..<24).map { hour in
            let bucketStart = calendar.date(byAdding: .hour, value: hour, to: day) ?? day
            let match = daySamples.min(by: { abs($0.date.timeIntervalSince(bucketStart)) < abs($1.date.timeIntervalSince(bucketStart)) })
            let value: Double?
            if let match, calendar.component(.hour, from: match.date) == hour {
                value = match.value
            } else if hour == calendar.component(.hour, from: Date()), let fallback, calendar.isDate(fallback.date, inSameDayAs: day) {
                value = fallback.value
            } else {
                value = nil
            }
            return ProfileWeightSpectrumBar(
                id: "hour-\(hour)",
                date: bucketStart,
                value: value,
                hasData: value != nil
            )
        }
    }

    private static func dailyBars(
        endingAt endDay: Date,
        dayCount: Int,
        history: [ProfileAnalyticsPoint],
        calendar: Calendar,
        idPrefix: String
    ) -> [ProfileWeightSpectrumBar] {
        let lookup = Dictionary(uniqueKeysWithValues: history.map {
            (calendar.startOfDay(for: $0.date), $0.value)
        })

        return (0..<dayCount).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: endDay) ?? endDay
            let normalized = calendar.startOfDay(for: day)
            let value = lookup[normalized]
            return ProfileWeightSpectrumBar(
                id: "\(idPrefix)-\(offset)",
                date: normalized,
                value: value,
                hasData: value != nil
            )
        }
    }

    private static func weeklyBars(
        endingAt endDay: Date,
        weekCount: Int,
        history: [ProfileAnalyticsPoint],
        calendar: Calendar,
        idPrefix: String
    ) -> [ProfileWeightSpectrumBar] {
        (0..<weekCount).reversed().map { offset in
            let weekEnd = calendar.date(byAdding: .day, value: -(offset * 7), to: endDay) ?? endDay
            let weekStart = calendar.date(byAdding: .day, value: -6, to: weekEnd) ?? weekEnd
            let values = history
                .filter { $0.date >= calendar.startOfDay(for: weekStart) && $0.date <= calendar.startOfDay(for: weekEnd) }
                .map(\.value)
            let average = values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
            return ProfileWeightSpectrumBar(
                id: "\(idPrefix)-\(offset)",
                date: weekEnd,
                value: average,
                hasData: average != nil
            )
        }
    }
}

// MARK: - Graphique

struct ProfileWeightSpectrumChart: View {
    let history: [ProfileAnalyticsPoint]
    var theme: AppTheme
    @Binding var selectedPeriod: ProfileWeightChartPeriod

    @State private var revealProgress: CGFloat = 0

    private let chartHeight: CGFloat = 148
    private let inactiveBarHeight: CGFloat = 11
    private let barWidth: CGFloat = 3
    private let barSpacing: CGFloat = 5
    private let barCornerRadius: CGFloat = 1.5
    private let sidePaddingBarCount: Int = 14

    private var bars: [ProfileWeightSpectrumBar] {
        ProfileWeightSpectrumBuilder.bars(from: history, period: selectedPeriod)
    }

    private var paddedBars: [ProfileWeightSpectrumBar] {
        let core = bars
        guard !core.isEmpty else { return core }

        let calendar = Calendar.current
        let leading = (0..<sidePaddingBarCount).map { index in
            let offset = sidePaddingBarCount - index
            let date = calendar.date(byAdding: .day, value: -offset, to: core[0].date) ?? core[0].date
            return ProfileWeightSpectrumBar(
                id: "pad-leading-\(selectedPeriod.rawValue)-\(index)",
                date: date,
                value: nil,
                hasData: false
            )
        }
        let trailing = (0..<sidePaddingBarCount).map { index in
            let date = calendar.date(byAdding: .day, value: index + 1, to: core[core.count - 1].date) ?? core[core.count - 1].date
            return ProfileWeightSpectrumBar(
                id: "pad-trailing-\(selectedPeriod.rawValue)-\(index)",
                date: date,
                value: nil,
                hasData: false
            )
        }
        return leading + core + trailing
    }

    private var dataBars: [(index: Int, bar: ProfileWeightSpectrumBar)] {
        paddedBars.enumerated().compactMap { index, bar in
            bar.hasData ? (index, bar) : nil
        }
    }

    private var peakEntry: (index: Int, bar: ProfileWeightSpectrumBar)? {
        dataBars.max(by: { ($0.bar.value ?? 0) < ($1.bar.value ?? 0) })
    }

    private var valueRange: (min: Double, max: Double) {
        let values = dataBars.compactMap(\.bar.value)
        guard let minV = values.min(), let maxV = values.max() else {
            return (70, 75)
        }
        if minV == maxV {
            return (minV - 0.8, maxV + 0.8)
        }
        let padding = max(0.35, (maxV - minV) * 0.22)
        return (minV - padding, maxV + padding)
    }

    var body: some View {
        chartCanvas
            .frame(height: chartHeight + 44)
            .padding(.top, 4)
            .onAppear {
                revealProgress = 0
                withAnimation(.spring(response: 0.72, dampingFraction: 0.82)) {
                    revealProgress = 1
                }
            }
            .onChange(of: selectedPeriod) { _, _ in
                revealProgress = 0
                withAnimation(.spring(response: 0.62, dampingFraction: 0.84)) {
                    revealProgress = 1
                }
            }
    }

    private var chartCanvas: some View {
        GeometryReader { geometry in
            let bars = paddedBars
            let totalWidth = CGFloat(bars.count) * barWidth + CGFloat(max(bars.count - 1, 0)) * barSpacing
            let contentWidth = max(totalWidth, geometry.size.width)
            let maxBarHeight = chartHeight - 8

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    ZStack(alignment: .bottom) {
                        HStack(alignment: .bottom, spacing: barSpacing) {
                            ForEach(Array(bars.enumerated()), id: \.element.id) { index, bar in
                                barView(
                                    bar: bar,
                                    index: index,
                                    dataIndex: dataIndex(for: index, in: bars),
                                    maxBarHeight: maxBarHeight
                                )
                                .id(index)
                            }
                        }
                        .frame(width: contentWidth, height: chartHeight, alignment: .bottomLeading)

                        if let peak = peakEntry,
                           let tooltipValue = peak.bar.value {
                            tooltip(
                                value: tooltipValue,
                                barIndex: peak.index,
                                maxBarHeight: maxBarHeight
                            )
                        }
                    }
                    .frame(width: contentWidth, height: chartHeight + 44)
                }
                .onAppear {
                    scrollToPeak(proxy: proxy, animated: false)
                }
                .onChange(of: selectedPeriod) { _, _ in
                    scrollToPeak(proxy: proxy, animated: true)
                }
            }
        }
    }

    @ViewBuilder
    private func barView(
        bar: ProfileWeightSpectrumBar,
        index: Int,
        dataIndex: Int?,
        maxBarHeight: CGFloat
    ) -> some View {
        let targetHeight = barHeight(for: bar, maxBarHeight: maxBarHeight)
        let animatedHeight = inactiveBarHeight + (targetHeight - inactiveBarHeight) * revealProgress

        RoundedRectangle(cornerRadius: barCornerRadius, style: .continuous)
            .fill(barColor(for: bar, dataIndex: dataIndex))
            .frame(width: barWidth, height: max(animatedHeight, inactiveBarHeight * revealProgress))
            .animation(.spring(response: 0.58, dampingFraction: 0.84), value: revealProgress)
            .animation(.spring(response: 0.58, dampingFraction: 0.84), value: selectedPeriod)
    }

    private func barHeight(for bar: ProfileWeightSpectrumBar, maxBarHeight: CGFloat) -> CGFloat {
        guard let value = bar.value else { return inactiveBarHeight }
        let span = max(valueRange.max - valueRange.min, 0.5)
        let normalized = (value - valueRange.min) / span
        return inactiveBarHeight + CGFloat(normalized) * (maxBarHeight - inactiveBarHeight)
    }

    private func barColor(for bar: ProfileWeightSpectrumBar, dataIndex: Int?) -> Color {
        guard bar.hasData, let dataIndex else {
            return ProfileWeightSpectrumPalette.inactive.opacity(theme.isDark ? 0.35 : 1)
        }
        let dataCount = max(dataBars.count - 1, 1)
        let progress = Double(dataIndex) / Double(dataCount)
        return interpolatedColor(progress: progress)
    }

    private func interpolatedColor(progress: Double) -> Color {
        let t = min(max(progress, 0), 1)
        return Color(
            red: 0.482 + (1.0 - 0.482) * t,
            green: 0.380 + (0.20 - 0.380) * t,
            blue: 1.0 + (0.40 - 1.0) * t
        )
    }

    private func dataIndex(for index: Int, in bars: [ProfileWeightSpectrumBar]) -> Int? {
        let indices = bars.enumerated().compactMap { idx, bar -> Int? in
            bar.hasData ? idx : nil
        }
        guard let position = indices.firstIndex(of: index) else { return nil }
        return position
    }

    private func tooltip(
        value: Double,
        barIndex: Int,
        maxBarHeight: CGFloat
    ) -> some View {
        let bar = paddedBars[barIndex]
        let barHeight = self.barHeight(for: bar, maxBarHeight: maxBarHeight)
        let animatedHeight = inactiveBarHeight + (barHeight - inactiveBarHeight) * revealProgress
        let x = barCenterX(index: barIndex)

        return VStack(spacing: 0) {
            Text(formattedTooltipValue(value))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(ProfileWeightSpectrumPalette.tooltipBackground)
                )
                .overlay(alignment: .bottom) {
                    TooltipCaret()
                        .fill(ProfileWeightSpectrumPalette.tooltipBackground)
                        .frame(width: 10, height: 5)
                        .offset(y: 4)
                }
        }
        .position(x: x, y: chartHeight - animatedHeight - 30)
        .opacity(revealProgress)
        .animation(.spring(response: 0.58, dampingFraction: 0.86), value: revealProgress)
        .animation(.spring(response: 0.58, dampingFraction: 0.86), value: selectedPeriod)
    }

    private func barCenterX(index: Int) -> CGFloat {
        CGFloat(index) * (barWidth + barSpacing) + barWidth / 2
    }

    private func formattedTooltipValue(_ value: Double) -> String {
        let text = String(format: "%.1f", value).replacingOccurrences(of: ".", with: ",")
        return "\(text) kg"
    }

    private func scrollToPeak(proxy: ScrollViewProxy, animated: Bool) {
        let centerIndex = sidePaddingBarCount + max(bars.count / 2, 0)
        let target = peakEntry?.index ?? centerIndex
        if animated {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.86)) {
                proxy.scrollTo(target, anchor: .center)
            }
        } else {
            proxy.scrollTo(target, anchor: .center)
        }
    }
}

private struct TooltipCaret: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Sélecteur période (tuiles journal)

enum ProfileStatisticsStripMetrics {
    static let cellWidth: CGFloat = 50
    static let cellHeight: CGFloat = 56
    static let cellRadius: CGFloat = 15
    static let cellSpacing: CGFloat = 8
    static let stripHeight: CGFloat = 64
}

struct ProfileStatisticsPeriodStrip<Period: Hashable & Identifiable>: View where Period: CaseIterable, Period.AllCases: RandomAccessCollection {
    @Binding var selection: Period
    let theme: AppTheme
    var label: (Period) -> String

    var body: some View {
        HStack(alignment: .center, spacing: ProfileStatisticsStripMetrics.cellSpacing) {
            ForEach(Array(Period.allCases), id: \.id) { period in
                periodTile(for: period)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: ProfileStatisticsStripMetrics.stripHeight)
    }

    private func periodTile(for period: Period) -> some View {
        let isSelected = selection.id == period.id

        return Button {
            guard !isSelected else { return }
            HapticManager.shared.selection()
            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                selection = period
            }
        } label: {
            ZStack {
                JournalDayTileBackground(
                    cornerRadius: ProfileStatisticsStripMetrics.cellRadius,
                    isDark: theme.isDark,
                    isSelected: isSelected,
                    accent: theme.coachAccent
                )

                Text(label(period))
                    .font(.system(size: 14, weight: isSelected ? .bold : .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? theme.primaryText : theme.secondaryText.opacity(0.92))
                    .monospacedDigit()
            }
            .frame(
                width: ProfileStatisticsStripMetrics.cellWidth,
                height: ProfileStatisticsStripMetrics.cellHeight
            )
            .scaleEffect(isSelected ? 1.03 : 1, anchor: .center)
            .animation(.spring(response: 0.32, dampingFraction: 0.78), value: isSelected)
        }
        .buttonStyle(JournalDayCellButtonStyle())
        .accessibilityLabel(label(period))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

extension ProfileStatisticsPeriodStrip where Period == ProfileWeightChartPeriod {
    init(selection: Binding<ProfileWeightChartPeriod>, theme: AppTheme) {
        self._selection = selection
        self.theme = theme
        self.label = { $0.displayLabel }
    }
}

// MARK: - Section profil

struct ProfileWeightStatisticsSection: View {
    @Environment(\.appTheme) private var theme

    let history: [ProfileAnalyticsPoint]
    let latestValue: Double?
    let deltaVsPrevious: Double?
    @Binding var selectedPeriod: ProfileWeightChartPeriod

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerBlock

            if history.isEmpty, latestValue == nil {
                Text(ProfileChartMetric.weight.emptyNoDataMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(theme.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 180, alignment: .center)
                    .padding(.horizontal, ProfileTheme.horizontalPadding)
            } else {
                ProfileWeightSpectrumChart(
                    history: effectiveHistory,
                    theme: theme,
                    selectedPeriod: $selectedPeriod
                )
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Poids")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(theme.secondaryText)

            scoreRow

            if showsComparisonCaption {
                footerCaption
            }
        }
        .padding(.horizontal, ProfileTheme.horizontalPadding)
    }

    private var scoreRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if let latestValue {
                let formatted = ProfileChartMetric.weight.formattedChartValue(latestValue)
                Text(formatted.main)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.primaryText)
                if !formatted.unit.isEmpty {
                    Text(formatted.unit)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(theme.secondaryText)
                }
            } else {
                Text("—")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.secondaryText)
            }
        }
    }

    private var showsComparisonCaption: Bool {
        deltaVsPrevious != nil
    }

    private var effectiveHistory: [ProfileAnalyticsPoint] {
        if !history.isEmpty { return history }
        guard let latestValue else { return [] }
        return [
            ProfileAnalyticsPoint(
                id: "weight-fallback",
                date: Calendar.current.startOfDay(for: Date()),
                value: latestValue
            )
        ]
    }

    @ViewBuilder
    private var footerCaption: some View {
        ProfileMetricComparisonLabel(
            metric: .weight,
            deltaVsPrevious: deltaVsPrevious,
            theme: theme
        )
        .font(.system(size: 12))
        .foregroundStyle(theme.secondaryText)
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
    }
}
