import SwiftUI

struct BodyScanReportView: View {
    @Environment(\.appTheme) private var theme

    let result: BodyScanResult
    var onContinue: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                scoreCard
                if !result.bodyZones.isEmpty { zonesSection }
                metricsGrid
                if !result.asymmetries.isEmpty { asymmetrySection }
                prioritiesSection
                if let face = result.faceMarkers { faceSection(face) }
                if !result.lifestyleInsights.isEmpty { lifestyleSection }
                narrativeSection
                disclaimer
                continueButton
            }
            .padding(20)
            .padding(.bottom, 32)
        }
        .processTransparentScrollSurface()
        .processAppPageBackground()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Rapport corporel")
                .font(.largeTitle.bold())
                .foregroundStyle(theme.primaryText)
            Text(result.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
            if result.aiEnhanced {
                Label("Analyse Claude", systemImage: "sparkles")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var scoreCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Score posture")
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)
                Text("\(result.postureScore)")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundStyle(theme.primaryText)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Confiance")
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
                Text("\(Int(result.confidence * 100)) %")
                    .font(.title3.bold())
                    .foregroundStyle(theme.primaryText)
            }
        }
        .padding(20)
        .background(theme.primaryText.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            metricTile("Épaules", result.metrics.shoulderAlignmentScore)
            metricTile("Bassin", result.metrics.hipAlignmentScore)
            metricTile("Colonne", result.metrics.spineAlignmentScore)
            metricTile("Genoux", result.metrics.kneeAlignmentScore)
            metricTile("Symétrie", result.metrics.leftRightSymmetryScore)
        }
    }

    private func metricTile(_ title: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
            Text("\(value)")
                .font(.title2.bold())
                .foregroundStyle(theme.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(theme.primaryText.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }

    private var zonesSection: some View {
        section(title: "Zones corporelles") {
            ForEach(result.bodyZones) { zone in
                HStack {
                    Circle()
                        .fill(zoneColor(zone.status))
                        .frame(width: 10, height: 10)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(zone.zoneName)
                            .font(.subheadline.bold())
                            .foregroundStyle(theme.primaryText)
                        Text(zone.detail)
                            .font(.caption)
                            .foregroundStyle(theme.secondaryText)
                    }
                }
            }
        }
    }

    private func zoneColor(_ status: ZoneHealthStatus) -> Color {
        switch status {
        case .strong: return .green
        case .neutral: return .yellow
        case .weak: return .red
        }
    }

    private var asymmetrySection: some View {
        section(title: "Asymétries") {
            ForEach(result.asymmetries, id: \.self) { item in
                Label(item, systemImage: "arrow.left.and.right")
                    .font(.subheadline)
                    .foregroundStyle(theme.primaryText)
            }
        }
    }

    private var prioritiesSection: some View {
        section(title: "Priorités musculaires") {
            ForEach(result.musclePriorities) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(item.priority). \(item.name)")
                        .font(.subheadline.bold())
                        .foregroundStyle(theme.primaryText)
                    Text(item.reason)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func faceSection(_ face: FaceWellnessMarkers) -> some View {
        section(title: "Visage & bien-être") {
            metricTile("Clarté", face.skinClarityScore)
            metricTile("Fatigue", face.underEyeFatigueScore)
            metricTile("Gonflement", face.puffinessScore)
            metricTile("Mâchoire", face.jawTensionScore)
            ForEach(face.notes, id: \.self) { note in
                Text("• \(note)")
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
            }
        }
    }

    private var lifestyleSection: some View {
        section(title: "Corrélations") {
            ForEach(result.lifestyleInsights, id: \.self) { insight in
                Text("• \(insight)")
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)
            }
        }
    }

    private var narrativeSection: some View {
        section(title: "Analyse détaillée") {
            Text(result.narrativeReport)
                .font(.subheadline)
                .foregroundStyle(theme.primaryText)
                .textSelection(.enabled)
        }
    }

    private var disclaimer: some View {
        Text(result.disclaimer)
            .font(.caption2)
            .foregroundStyle(theme.secondaryText)
            .padding(.top, 8)
    }

    private var continueButton: some View {
        Button(action: onContinue) {
            Text("Continuer")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(theme.background)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(theme.primaryText, in: RoundedRectangle(cornerRadius: 26))
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func section(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(theme.primaryText)
            content()
        }
    }
}
