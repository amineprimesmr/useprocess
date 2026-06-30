import SwiftUI

enum FaceScanChartPeriod: String, CaseIterable, Identifiable {
    case week = "7 j"
    case month = "30 j"

    var id: String { rawValue }

    var dayCount: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        }
    }
}

enum FaceScanChartMetric: String, CaseIterable, Identifiable {
    case retention = "Rétention"
    case recovery = "Récupération"
    case skin = "Peau"
    case definition = "Définition"
    case stress = "Stress"

    var id: String { rawValue }

    private var kind: FaceScanIndicators.Kind {
        switch self {
        case .retention: return .retention
        case .recovery: return .recovery
        case .skin: return .skin
        case .definition: return .definition
        case .stress: return .stressLoad
        }
    }

    func value(from markers: FaceWellnessMarkers) -> Int {
        FaceScanIndicators.rawValue(for: kind, markers: markers)
    }

    func relativeValue(from result: FaceScanResult) -> Int {
        guard let signals = result.relativeSignals else {
            return FaceScanIndicators.rawValue(for: kind, result: result)
        }
        switch kind {
        case .retention: return signals.puffinessDelta
        case .recovery: return signals.underEyeFatigueDelta
        case .skin: return signals.skinClarityDelta
        case .definition: return signals.faceDefinitionDelta ?? 0
        case .stressLoad: return signals.stressLoadDelta ?? 0
        }
    }

    var color: Color {
        switch self {
        case .retention: return .orange
        case .recovery: return .purple
        case .skin: return .mint
        case .definition: return .cyan
        case .stress: return .red.opacity(0.85)
        }
    }
}

struct FaceScanTrendChartView: View {
    let history: [FaceScanResult]
    var theme: AppTheme

    @State private var period: FaceScanChartPeriod = .week
    @State private var metric: FaceScanChartMetric = .retention

    private var dataPoints: [(date: Date, value: Int)] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -period.dayCount, to: Date()) ?? Date()
        return history
            .filter { $0.createdAt >= cutoff }
            .sorted { $0.createdAt < $1.createdAt }
            .map { ($0.createdAt, metric.relativeValue(from: $0)) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Picker("Période", selection: $period) {
                    ForEach(FaceScanChartPeriod.allCases) { p in
                        Text(p.rawValue).tag(p)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Métrique", selection: $metric) {
                    ForEach(FaceScanChartMetric.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.menu)
            }

            if dataPoints.count < 2 {
                Text("Au moins 2 scans sur \(period.rawValue) pour afficher la courbe.")
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
            } else {
                FaceScanLineChart(points: dataPoints, color: metric.color, theme: theme)
                    .frame(height: 140)
            }
        }
    }
}

private struct FaceScanLineChart: View {
    let points: [(date: Date, value: Int)]
    let color: Color
    let theme: AppTheme

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let values = points.map { Double($0.value) }
            let minV = (values.min() ?? 0) - 5
            let maxV = (values.max() ?? 100) + 5
            let range = max(maxV - minV, 1)

            ZStack {
                ForEach(0..<4, id: \.self) { i in
                    let y = height * CGFloat(i) / 3
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                    .stroke(theme.cardStroke.opacity(0.35), lineWidth: 0.5)
                }

                Path { path in
                    for (index, point) in points.enumerated() {
                        let x = width * CGFloat(index) / CGFloat(max(points.count - 1, 1))
                        let normalized = (Double(point.value) - minV) / range
                        let y = height - height * CGFloat(normalized)
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                    let x = width * CGFloat(index) / CGFloat(max(points.count - 1, 1))
                    let normalized = (Double(point.value) - minV) / range
                    let y = height - height * CGFloat(normalized)
                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                        .position(x: x, y: y)
                }
            }
        }
    }
}
