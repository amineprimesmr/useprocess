import SwiftUI

/// Scan visage compact — intégré au hub Santé / Protocole.
struct FaceScanHealthCompact: View {
    @Environment(\.appTheme) private var theme

    let latest: FaceScanResult?
    let faceDayScore: Int?
    let isScanDue: Bool
    let daysUntilNextScan: Int?
    var correlationHint: String?
    var historyZoomNamespace: Namespace.ID? = nil
    var onScan: () -> Void
    var onHistory: () -> Void

    private var analysisLine: String? {
        guard let latest else { return nil }
        let parsed = CoachEngine.parsedFaceAnalysis(for: latest)
        if parsed.isValid, !parsed.summary.isEmpty {
            return OriginPlanPresenter.truncate(parsed.summary, max: 90)
        }
        if let raw = latest.claudeAnalysis {
            return OriginPlanPresenter.truncate(raw, max: 90)
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HealthHubDesign.sectionHeader("Scan visage", subtitle: statusSubtitle, theme: theme)
                Spacer()
                if let faceDayScore {
                    FaceWellnessScoreBadge(score: faceDayScore, theme: theme)
                }
            }

            if let analysisLine {
                Text(analysisLine)
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let correlationHint {
                Text(correlationHint)
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Scan quotidien — fatigue, récupération, visage.")
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
            }

            HStack(spacing: 10) {
                Button(action: onScan) {
                    Label(isScanDue ? "Scanner maintenant" : "Scanner", systemImage: "camera.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.onboardingAccent)

                Button(action: onHistory) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.body.weight(.semibold))
                        .frame(width: 42, height: 42)
                }
                .buttonStyle(.bordered)
                .tint(theme.primaryText)
                .processZoomSource(id: .faceScanHistory, namespace: historyZoomNamespace)
                .accessibilityLabel("Historique des scans visage")
            }
        }
        .padding(14)
        .background(HealthHubDesign.surfaceCard(theme: theme))
    }

    private var statusSubtitle: String {
        FaceScanCadence.statusLabel(since: latest?.createdAt)
    }
}
