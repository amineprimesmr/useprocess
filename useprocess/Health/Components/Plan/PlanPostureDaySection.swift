import SwiftUI

enum PlanPostureCircuitContent {
    static func mobilityBlocks(for plan: FaceOriginPlan) -> [String] {
        let blocks = plan.postureProtocol.mobilityBlocks
        if blocks.isEmpty {
            return PostureIntelligenceGuide.defaultMobilityBlocks
        }
        return blocks
    }

    static func breathingLines(for plan: FaceOriginPlan) -> [String] {
        plan.postureProtocol.breathingWork
    }

    static func walkingTarget(for plan: FaceOriginPlan) -> String? {
        let target = plan.postureProtocol.walkingTargets.trimmingCharacters(in: .whitespacesAndNewlines)
        return target.isEmpty ? nil : target
    }

    static func dailyChecks(for plan: FaceOriginPlan) -> [String] {
        plan.postureProtocol.dailyChecks
    }
}

/// Section posture dédiée — le circuit est présenté dans « Entraînement du jour ».
struct PlanPostureDaySection: View {
    let plan: FaceOriginPlan

    var body: some View {
        EmptyView()
    }
}

struct PlanPostureDetailSheet: View {
    let plan: FaceOriginPlan
    var dayTitle: String?

    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    private var mobilityBlocks: [String] {
        PlanPostureCircuitContent.mobilityBlocks(for: plan)
    }

    private var breathingLines: [String] {
        PlanPostureCircuitContent.breathingLines(for: plan)
    }

    private var walkingTarget: String? {
        PlanPostureCircuitContent.walkingTarget(for: plan)
    }

    private var dailyChecks: [String] {
        PlanPostureCircuitContent.dailyChecks(for: plan)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let dayTitle, !dayTitle.isEmpty {
                        Text(dayTitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.secondaryText)
                    }

                    blockTitle("Mobilité & correctifs")
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(mobilityBlocks, id: \.self) { line in
                            PlanTrainingBlockRow(line: line, fallbackSystemImage: "figure.cooldown")
                        }
                    }

                    if !breathingLines.isEmpty {
                        blockTitle("Respiration")
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(breathingLines, id: \.self) { line in
                                PlanTrainingBlockRow(line: line, fallbackSystemImage: "wind")
                            }
                        }
                    }

                    if let walkingTarget {
                        blockTitle("Marche")
                        PlanTrainingBlockRow(line: walkingTarget, fallbackSystemImage: "figure.walk")
                    }

                    if !dailyChecks.isEmpty {
                        blockTitle("Checks posture 24/7")
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(dailyChecks, id: \.self) { line in
                                PlanTrainingBlockRow(line: line, fallbackSystemImage: "checkmark.circle")
                            }
                        }
                    }
                }
                .padding()
            }
            .processTransparentScrollSurface()
            .navigationTitle("Circuit posture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
        .processAppPageBackground()
        .processAppPresentationBackground()
    }

    private func blockTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(theme.secondaryText)
            .textCase(.uppercase)
    }
}
