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
                HealthHubDesign.sectionHeader(AppCopy.t("Scan visage", en: "Face scan"), subtitle: statusSubtitle, theme: theme)
                Spacer()
                if let latest {
                    FaceWellnessAppreciationBadge(
                        appreciation: FaceWellnessScore.appreciation(for: latest),
                        theme: theme,
                        style: .compact
                    )
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
                Text(AppCopy.t("Scan quotidien — fatigue, récupération, visage.", en: "Daily scan — fatigue, recovery, face."))
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
            }

            HStack(spacing: 10) {
                Button(action: onScan) {
                    Label(isScanDue ? AppCopy.t("Scanner maintenant", en: "Scan now") : AppCopy.t("Scanner", en: "Scan"), systemImage: "camera.fill")
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
                .accessibilityLabel(AppCopy.t("Historique des scans visage", en: "Face scan history"))
            }
        }
        .padding(14)
        .background(HealthHubDesign.surfaceCard(theme: theme))
    }

    private var statusSubtitle: String {
        FaceScanCadence.statusLabel(since: latest?.createdAt)
    }
}
