import SwiftUI

/// Courbes lissées partagées par les graphiques profil.
struct ProfileAnalyticsLineShape: Shape {
    let values: [Double]
    var valueMin: Double?
    var valueMax: Double?

    func path(in rect: CGRect) -> Path {
        smoothPath(in: rect, closesToBottom: false)
    }

    func smoothPath(in rect: CGRect, closesToBottom: Bool) -> Path {
        var path = Path()
        guard !values.isEmpty else { return path }

        let minV = valueMin ?? values.min() ?? 0
        let maxV = valueMax ?? values.max() ?? 100
        let range = max(maxV - minV, 0.5)

        let points = values.enumerated().map { index, value in
            let normalized = (value - minV) / range
            return CGPoint(
                x: values.count == 1 ? rect.midX : rect.width * CGFloat(index) / CGFloat(values.count - 1),
                y: rect.height * (1 - CGFloat(normalized))
            )
        }

        if closesToBottom {
            path.move(to: CGPoint(x: points[0].x, y: rect.maxY))
            path.addLine(to: points[0])
        } else {
            path.move(to: points[0])
        }

        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]
            let midpoint = (previous.x + current.x) / 2
            path.addCurve(
                to: current,
                control1: CGPoint(x: midpoint, y: previous.y),
                control2: CGPoint(x: midpoint, y: current.y)
            )
        }

        if closesToBottom, let last = points.last {
            path.addLine(to: CGPoint(x: last.x, y: rect.maxY))
            path.closeSubpath()
        }
        return path
    }
}

struct ProfileAnalyticsAreaShape: Shape {
    let values: [Double]
    var valueMin: Double?
    var valueMax: Double?

    func path(in rect: CGRect) -> Path {
        ProfileAnalyticsLineShape(values: values, valueMin: valueMin, valueMax: valueMax)
            .smoothPath(in: rect, closesToBottom: true)
    }
}

/// Compat — délègue au renderer profil.
struct ProfileWeightChart: View {
    let points: [ProfileAnalyticsPoint]
    let metric: ProfileChartMetric
    var theme: AppTheme
    var compact: Bool = false

    var body: some View {
        ProfileMetricChartRenderer(
            points: points,
            metric: metric,
            theme: theme,
            style: metric.visualStyle(pointCount: points.count)
        )
    }
}

typealias ProfileRegularityChart = ProfileWeightChart
