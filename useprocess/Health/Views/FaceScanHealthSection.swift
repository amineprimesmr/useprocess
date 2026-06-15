import SwiftUI

struct FaceScanHealthSection: View {
    @Environment(\.appTheme) private var theme

    let latest: FaceScanResult?
    let previous: FaceScanResult?
    let history: [FaceScanResult]
    let streakDays: Int
    let daysSinceLastScan: Int?
    let faceDayScore: Int?
    let correlations: [FaceScanCorrelationInsight]
    var onScan: () -> Void
    var onHistory: () -> Void

    private var trend: FaceScanTrend? {
        guard let latest, let previous else { return nil }
        return latest.delta(from: previous)
    }

    private var analysis: FaceScanAnalysisContent {
        guard let latest else { return .empty }
        return CoachEngine.parsedFaceAnalysis(for: latest)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Label("Scan visage", systemImage: "face.smiling")
                    .font(.headline)
                    .foregroundStyle(theme.primaryText)

                Spacer()

                if let faceDayScore {
                    Text("Visage \(faceDayScore)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.primaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(theme.cardBackground.opacity(0.8))
                        .clipShape(Capsule())
                }

                if streakDays > 0 {
                    Text("\(streakDays) j 🔥")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.secondaryText)
                }
            }

            dailyNudge

            if history.count >= 2 {
                FaceScanTrendChartView(history: history, theme: theme)
            }

            if !correlations.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Corrélations détectées")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.secondaryText)
                        .textCase(.uppercase)

                    ForEach(correlations.prefix(3)) { insight in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: insight.icon)
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .frame(width: 16)
                            Text(insight.message)
                                .font(.caption)
                                .foregroundStyle(theme.primaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            if let latest {
                FaceScanMetricsRow(markers: latest.markers, trend: trend, theme: theme)

                if analysis.isValid {
                    FaceScanAnalysisCard(analysis: analysis, theme: theme)
                } else if let raw = latest.claudeAnalysis {
                    Text(raw)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(4)
                }

                Text("Dernier scan : \(latest.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(theme.secondaryText)
            } else {
                Text("Scanne ton visage chaque matin pour suivre gonflement, cernes, cortisol et récupération.")
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)
            }

            HStack(spacing: 10) {
                Button(action: onScan) {
                    Label("Nouveau scan", systemImage: "camera.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.primaryText)

                Button(action: onHistory) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.body.weight(.semibold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
                .tint(theme.primaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(cardBackground)
    }

    @ViewBuilder
    private var dailyNudge: some View {
        if let days = daysSinceLastScan {
            if days == 0 {
                Label("Scan du jour effectué", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.green)
            } else {
                Text("Pas de scan depuis \(days) jour\(days > 1 ? "s" : "") — refais-en un ce matin.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(theme.cardBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(theme.cardStroke, lineWidth: theme.isDark ? 0 : 0.5)
            }
    }
}
