import SwiftUI

enum PlanPostureCircuitContent {
    static func mobilityBlocks(for plan: FaceOriginPlan) -> [String] {
        let blocks = plan.postureProtocol.mobilityBlocks
        if blocks.isEmpty {
            return PostureIntelligenceGuide.neutralHomeMobilityBlocks
        }
        return blocks.map(sanitizeLegacyHomeLine).filter { !shouldHideProtocolLine($0) }
    }

    private static func shouldHideProtocolLine(_ line: String) -> Bool {
        let lower = line.lowercased()
        return lower.contains("respiration nasale lente") && lower.contains("5 min")
    }

    private static func sanitizeLegacyHomeLine(_ line: String) -> String {
        let lower = line.lowercased()
        if lower.contains("neck curl") && !lower.contains("vide") && !lower.contains("lit") && !lower.contains("canapé") {
            return "Neck curls — buste sur lit ou canapé, tête dans le vide, menton vers poitrine, 3×10–12"
        }
        if lower.contains("face pull") {
            return "Rétraction scapulaire au mur — bras en Y, omoplates serrées, 2×12"
        }
        if lower.contains("câble") || lower.contains("plaque légère") {
            return "Extension nuque (face au sol) — mains au front, 3×10 sans charge"
        }
        if lower.contains("banc") && lower.contains("chin tuck") {
            return "Chin tuck — dos au mur ou tête hors lit, 3×10, maintien 2–3 s"
        }
        return line
    }

    static func walkingTarget(for plan: FaceOriginPlan) -> String? {
        let target = plan.postureProtocol.walkingTargets.trimmingCharacters(in: .whitespacesAndNewlines)
        return target.isEmpty ? nil : target
    }

    static func hasWalkingTarget(for plan: FaceOriginPlan) -> Bool {
        walkingTarget(for: plan) != nil
    }

    static func dailyStepTarget(for plan: FaceOriginPlan) -> Int {
        plan.resolvedDailyTargets.dailySteps
    }

    static func dailyChecks(for plan: FaceOriginPlan) -> [String] {
        plan.postureProtocol.dailyChecks
    }

    /// Circuit posture condensé pour l’accueil Plan (3–4 blocs max).
    static func compactLines(
        for plan: FaceOriginPlan,
        limit: Int = 4,
        isRestDay: Bool = false,
        includeWalking: Bool = true
    ) -> [String] {
        let cap = min(max(limit, 3), 4)
        if isRestDay {
            return restDayLines(for: plan, limit: cap, includeWalking: includeWalking)
        }

        var lines: [String] = []

        let mobility = mobilityBlocks(for: plan)
        lines.append(contentsOf: mobility.prefix(cap))

        if includeWalking, lines.count < cap, let walking = walkingTarget(for: plan) {
            lines.append(compactWalkingLine(walking))
        }

        return Array(lines.prefix(cap))
    }

    private static func restDayLines(
        for plan: FaceOriginPlan,
        limit: Int,
        includeWalking: Bool
    ) -> [String] {
        var lines: [String] = []
        if includeWalking {
            if let walking = walkingTarget(for: plan) {
                lines.append(compactWalkingLine(walking))
            } else {
                lines.append("Marche légère + mobilité douce")
            }
        }

        let mobility = mobilityBlocks(for: plan)
        let mobilitySlots = min(max(0, limit - lines.count), mobility.count)
        lines.append(contentsOf: mobility.prefix(mobilitySlots))

        return Array(lines.prefix(limit))
    }

    private static func compactWalkingLine(_ line: String) -> String {
        if line.count <= 72 { return line }
        if let range = line.range(of: " — ") {
            return String(line[..<range.lowerBound])
        }
        return String(line.prefix(72)) + "…"
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

    private var circuitLines: [String] {
        PlanPostureCircuitContent.compactLines(for: plan)
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

                    blockTitle("Circuit posture")
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(circuitLines, id: \.self) { line in
                            PlanTrainingBlockRow(line: line, fallbackSystemImage: postureIcon(for: line))
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

    private func postureIcon(for line: String) -> String {
        let lower = line.lowercased()
        if lower.contains("buteyko") || lower.contains("respiration") { return "wind" }
        if lower.contains("marche") || lower.contains("pas") { return "figure.walk" }
        return "figure.mind.and.body"
    }
}
