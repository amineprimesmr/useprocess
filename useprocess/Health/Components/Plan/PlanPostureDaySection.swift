import SwiftUI

/// Circuit posture quotidien — hero + blocs mobilité illustrés.
struct PlanPostureDaySection: View {
    let plan: FaceOriginPlan

    @Environment(\.appTheme) private var theme

    private var protocolBlocks: [String] {
        var lines = plan.postureProtocol.mobilityBlocks
        if lines.isEmpty {
            lines = PostureIntelligenceGuide.defaultMobilityBlocks
        }
        return lines
    }

    private var breathingLines: [String] {
        plan.postureProtocol.breathingWork
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Posture & circuit quotidien")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(theme.primaryText)

            postureHeroCard

            VStack(alignment: .leading, spacing: 10) {
                Text("Circuit")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
                    .textCase(.uppercase)

                ForEach(protocolBlocks, id: \.self) { block in
                    PlanTrainingBlockRow(line: block, fallbackSystemImage: "figure.cooldown")
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HealthHubDesign.softCard(theme: theme))

            if !breathingLines.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Respiration")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.secondaryText)
                        .textCase(.uppercase)

                    ForEach(breathingLines, id: \.self) { line in
                        PlanTrainingBlockRow(line: line, fallbackSystemImage: "wind")
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(HealthHubDesign.softCard(theme: theme))
            }

            if !plan.postureProtocol.walkingTargets.isEmpty {
                PlanTrainingBlockRow(
                    line: plan.postureProtocol.walkingTargets,
                    fallbackSystemImage: "figure.walk"
                )
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(HealthHubDesign.softCard(theme: theme))
            }
        }
    }

    private var postureHeroCard: some View {
        let assetName = TrainingAssetCatalog.resolvedHeroAsset(
            for: TrainingSessionCatalog.entry(for: .femaleUpper)
        )

        return PlanTrainingFullBleedCard(
            assetName: assetName,
            headline: "💥 Posture — circuit quotidien",
            muscleTags: "DOS · NUQUE · MOBILITÉ",
            durationMinutes: 10,
            footerLine: "\(protocolBlocks.count) blocs · orofacial + habitudes 24/7",
            isBookmarked: false,
            cardMaxHeight: PlanTrainingVisuals.heroMaxHeight,
            showsBookmark: false,
            onTap: {}
        )
        .frame(maxWidth: .infinity, alignment: .center)
    }
}
