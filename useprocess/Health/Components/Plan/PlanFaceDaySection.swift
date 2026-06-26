import SwiftUI

/// Protocole visage complet — orofacial, lymphe, cadence scan.
struct PlanFaceDaySection: View {
    let plan: FaceOriginPlan

    @Environment(\.appTheme) private var theme

    private var faceProtocol: OriginFaceProtocol { plan.faceProtocol }

    private var jawLines: [String] {
        faceProtocol.jawAndTongueWork
    }

    private var lymphLines: [String] {
        faceProtocol.lymphAndFascia
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Protocole visage")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(theme.primaryText)

            faceHeroCard

            if !faceProtocol.focusAreas.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Priorités")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.secondaryText)
                        .textCase(.uppercase)
                    Text(faceProtocol.focusAreas.joined(separator: " · "))
                        .font(.subheadline)
                        .foregroundStyle(theme.primaryText)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(HealthHubDesign.softCard(theme: theme))
            }

            if !jawLines.isEmpty {
                protocolBlock(title: "Mâchoire & langue", lines: jawLines, icon: "mouth")
            }

            if !lymphLines.isEmpty {
                protocolBlock(title: "Lymphe & fascias", lines: lymphLines, icon: "drop")
            }

            if !faceProtocol.scanCadence.isEmpty {
                PlanTrainingBlockRow(
                    line: faceProtocol.scanCadence,
                    fallbackSystemImage: "camera.viewfinder"
                )
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(HealthHubDesign.softCard(theme: theme))
            }
        }
    }

    private var faceHeroCard: some View {
        let assetName = TrainingAssetCatalog.resolvedHeroAsset(
            for: TrainingSessionCatalog.entry(for: .femaleUpper)
        )

        return PlanTrainingFullBleedCard(
            assetName: assetName,
            headline: "✨ Visage — debloat & structure",
            muscleTags: "OROFACIAL · LYMPHE · MEWING",
            durationMinutes: 15,
            footerLine: "\(jawLines.count) actions orofaciales · habitudes 24/7",
            isBookmarked: false,
            cardMaxHeight: PlanTrainingVisuals.heroMaxHeight,
            showsBookmark: false,
            onTap: {}
        )
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func protocolBlock(title: String, lines: [String], icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.secondaryText)
                .textCase(.uppercase)

            ForEach(lines, id: \.self) { line in
                PlanTrainingBlockRow(line: line, fallbackSystemImage: icon)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HealthHubDesign.softCard(theme: theme))
    }
}
