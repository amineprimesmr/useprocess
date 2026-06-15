import SwiftUI

struct FaceScanAnalysisCard: View {
    let analysis: FaceScanAnalysisContent
    var theme: AppTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(analysis.summary)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.primaryText)

            if !analysis.signals.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(analysis.signals, id: \.self) { signal in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(Color.orange.opacity(0.85))
                                .frame(width: 6, height: 6)
                                .padding(.top, 6)
                            Text(signal)
                                .font(.caption)
                                .foregroundStyle(theme.secondaryText)
                        }
                    }
                }
            }

            if !analysis.evolution.isEmpty {
                Text(analysis.evolution)
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
            }

            if !analysis.tips.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Conseils")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.secondaryText)
                        .textCase(.uppercase)

                    ForEach(Array(analysis.tips.enumerated()), id: \.offset) { index, tip in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1)")
                                .font(.caption2.weight(.bold))
                                .frame(width: 18, height: 18)
                                .background(theme.cardStroke.opacity(0.5))
                                .clipShape(Circle())
                            Text(tip)
                                .font(.caption)
                                .foregroundStyle(theme.primaryText)
                        }
                    }
                }
            }
        }
    }
}

struct FaceScanMetricsRow: View {
    let markers: FaceWellnessMarkers
    var trend: FaceScanTrend?
    var theme: AppTheme

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            metric("Gonflement", markers.puffinessScore, trend?.puffiness, higherIsWorse: true)
            metric("Cernes", markers.underEyeFatigueScore, trend?.underEyeFatigue, higherIsWorse: true)
            metric("Mâchoire", markers.jawTensionScore, trend?.jawTension, higherIsWorse: true)
            metric("Peau", markers.skinClarityScore, trend?.skinClarity, higherIsWorse: false)
        }
    }

    private func metric(_ title: String, _ value: Int, _ delta: Int?, higherIsWorse: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(theme.secondaryText)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(value)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(theme.primaryText)
                if let delta, delta != 0 {
                    Text(deltaLabel(delta, higherIsWorse: higherIsWorse))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(deltaColor(delta, higherIsWorse: higherIsWorse))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(theme.cardBackground.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func deltaLabel(_ delta: Int, higherIsWorse: Bool) -> String {
        delta > 0 ? "+\(delta)" : "\(delta)"
    }

    private func deltaColor(_ delta: Int, higherIsWorse: Bool) -> Color {
        let improved = higherIsWorse ? delta < 0 : delta > 0
        if improved { return .green }
        if delta == 0 { return theme.secondaryText }
        return .orange
    }
}
