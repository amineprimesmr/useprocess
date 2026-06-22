import SwiftUI

/// Résumé scan visage — page Plan, sous le bandeau de jours.
struct PlanLastFaceScanSection: View {
    let latest: FaceScanResult?
    let isScanDue: Bool

    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                scanMediaPreview

                VStack(alignment: .leading, spacing: 4) {
                    Text("Dernier scan visage")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.primaryText)

                    if let latest {
                        Text(lastScanDateLabel(for: latest.createdAt))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(theme.secondaryText)
                    } else {
                        Text("Aucun scan enregistré pour l’instant.")
                            .font(.caption)
                            .foregroundStyle(theme.secondaryText)
                    }
                }

                Spacer(minLength: 8)

                if let latest {
                    FaceWellnessScoreBadge(
                        score: latest.resolvedFaceDayScore,
                        theme: theme,
                        style: .compact
                    )
                }
            }

            nextScanCountdownRow
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.isDark ? Color(red: 0.11, green: 0.11, blue: 0.12) : theme.cardBackgroundStrong)
        )
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var scanMediaPreview: some View {
        if let latest {
            FaceScanRecordingMediaView(
                result: latest,
                height: 68,
                displayMode: .thumbnail
            )
            .frame(width: 52)
            .accessibilityLabel("Vidéo du dernier scan visage")
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(theme.isDark ? Color.white.opacity(0.06) : theme.cardBackground.opacity(0.9))
                .frame(width: 52, height: 68)
                .overlay {
                    Image(systemName: "camera.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.secondaryText)
                }
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var nextScanCountdownRow: some View {
        HStack(spacing: 10) {
            Image(systemName: countdownIcon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(countdownAccent)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text("Prochain scan")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
                    .textCase(.uppercase)

                if latest == nil || isScanDue {
                    Text(latest == nil ? "Premier scan à faire" : "Scan disponible")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(latest == nil ? .orange : theme.onboardingAccent)
                        .monospacedDigit()
                } else {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(FaceScanCadence.countdownLabel(
                            since: latest?.createdAt,
                            now: context.date
                        ))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(theme.primaryText)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.isDark ? Color.white.opacity(0.05) : theme.cardBackground.opacity(0.85))
        )
    }

    private var countdownIcon: String {
        if latest == nil || isScanDue { return "camera.fill" }
        return "timer"
    }

    private var countdownAccent: Color {
        if latest == nil || isScanDue { return .orange }
        return theme.onboardingAccent
    }

    private func lastScanDateLabel(for date: Date) -> String {
        let calendar = Calendar.current
        let dayLabel: String
        if calendar.isDateInToday(date) {
            dayLabel = "Aujourd'hui"
        } else if calendar.isDateInYesterday(date) {
            dayLabel = "Hier"
        } else {
            dayLabel = date.formatted(.dateTime.day().month(.abbreviated))
        }
        return "Dernier scan · \(dayLabel) à \(date.formatted(date: .omitted, time: .shortened))"
    }
}
