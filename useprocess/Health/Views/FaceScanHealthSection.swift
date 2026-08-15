import SwiftUI

struct FaceScanHealthSection: View {
    @Environment(\.appTheme) private var theme

    let latest: FaceScanResult?
    let previous: FaceScanResult?
    let history: [FaceScanResult]
    let streakDays: Int
    let daysSinceLastScan: Int?
    let daysUntilNextScan: Int?
    let isScanDue: Bool
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

    private var dailyHistory: [FaceScanResult] {
        FaceScanEvolutionEngine.dailyHistory(from: history)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Label(AppCopy.t("Scan visage", en: "Face scan"), systemImage: "face.smiling")
                    .font(.headline)
                    .foregroundStyle(theme.primaryText)

                Spacer()

                if let latest {
                    FaceWellnessAppreciationBadge(
                        appreciation: FaceWellnessScore.appreciation(for: latest),
                        theme: theme,
                        style: .compact
                    )
                }

                if streakDays > 0 {
                    Text(AppCopy.t("\(streakDays) j · scans", en: "\(streakDays) d · scans"))
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
                    Text(AppCopy.t("Corrélations détectées", en: "Correlations found"))
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
                if let confidence = latest.scanConfidence {
                    Text(AppCopy.t(
                        "\(FaceWellnessScore.confidenceLabel(for: confidence)) · score relatif à ta baseline, pas à ta forme de visage.",
                        en: "\(FaceWellnessScore.confidenceLabel(for: confidence)) · score relative to your baseline, not your face shape."
                    ))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(FaceScanMetricDisplay.evolutionSentence(
                    for: latest,
                    previous: previous,
                    history: dailyHistory
                ))
                .font(.caption.weight(.medium))
                .foregroundStyle(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

                FaceScanMetricsRow(
                    markers: latest.markers,
                    relativeSignals: latest.relativeSignals,
                    trend: trend,
                    theme: theme
                )

            if analysis.isValid {
                FaceScanAnalysisCard(analysis: analysis, theme: theme)
            } else if let raw = latest.claudeAnalysis {
                let cleaned = FaceScanAnalysisParser.sanitize(raw)
                if !cleaned.isEmpty {
                    Text(cleaned)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(4)
                }
            }

                Text(AppCopy.t("Dernier scan : \(latest.createdAt.formatted(date: .abbreviated, time: .shortened))", en: "Latest scan: \(latest.createdAt.formatted(date: .abbreviated, time: .shortened))"))
                    .font(.caption2)
                    .foregroundStyle(theme.secondaryText)
            } else {
                Text(AppCopy.t("Scanne ton visage chaque jour pour suivre rétention, récupération, peau, définition et charge stress.", en: "Scan your face every day to track retention, recovery, skin, definition, and stress load."))
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)
            }

            HStack(spacing: 10) {
                Button(action: onScan) {
                    Label(isScanDue ? AppCopy.t("Nouveau scan", en: "New scan") : AppCopy.t("Scan déjà fait", en: "Scan already done"), systemImage: "camera.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.primaryText)
                .disabled(!isScanDue)

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
        if latest == nil {
            Label(AppCopy.t("Premier scan à faire", en: "First scan to do"), systemImage: "exclamationmark.circle")
                .font(.caption.weight(.medium))
                .foregroundStyle(.orange)
        } else if isScanDue {
            Label(AppCopy.t("Scan du jour à faire", en: "Today's scan to do"), systemImage: "bell.badge")
                .font(.caption.weight(.medium))
                .foregroundStyle(.orange)
        } else if let remaining = daysUntilNextScan, remaining == 1 {
            Label(AppCopy.t("Prochain scan demain", en: "Next scan tomorrow"), systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(.green)
        } else if let remaining = daysUntilNextScan, remaining > 1 {
            Label(AppCopy.t("Prochain scan dans \(remaining) jours", en: remaining == 1 ? "Next scan in 1 day" : "Next scan in \(remaining) days"), systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(.green)
        } else if let days = daysSinceLastScan, days == 0 {
            Label(AppCopy.t("Scan enregistré aujourd'hui", en: "Scan saved today"), systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(.green)
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
