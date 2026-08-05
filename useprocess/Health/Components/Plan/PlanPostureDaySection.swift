import SwiftUI

enum PlanPostureCircuitContent {
    @MainActor
    static func mobilityBlocks(for plan: FaceOriginPlan) -> [String] {
        let blocks = plan.postureProtocol.mobilityBlocks
        let source = blocks.isEmpty ? PostureIntelligenceGuide.neutralHomeMobilityBlocks : blocks
        return source
            .map(sanitizeLegacyHomeLine)
            .filter { !shouldHideProtocolLine($0) && !isWalkingLine($0) }
    }

    nonisolated private static func isWalkingLine(_ line: String) -> Bool {
        let lower = line.lowercased()
        return lower.contains("marche")
            || lower.contains("walking")
            || lower.contains("pas amplifiés")
            || lower.contains("figure.walk")
    }

    nonisolated private static func shouldHideProtocolLine(_ line: String) -> Bool {
        let lower = line.lowercased()
        if lower.contains("respiration nasale lente") && lower.contains("5 min") {
            return true
        }
        if lower.contains("neck curl") {
            return true
        }
        return false
    }

    @MainActor
    private static func sanitizeLegacyHomeLine(_ line: String) -> String {
        let lower = line.lowercased()
        if lower.contains("face pull") {
            return AppCopy.t(
                "Rétraction scapulaire au mur — bras en Y, omoplates serrées, 2×12",
                en: "Wall scapular retraction — Y arms, squeeze shoulder blades, 2×12"
            )
        }
        if lower.contains("câble") || lower.contains("plaque légère") || lower.contains("extension nuque") {
            return AppCopy.t(
                "Extension nuque — mains au front, 3×10 sans charge",
                en: "Neck extension — hands on forehead, 3×10 with no load"
            )
        }
        if lower.contains("banc") && lower.contains("chin tuck") {
            return AppCopy.t(
                "Chin tuck — dos au mur ou tête hors lit, 3×10, maintien 2–3 s",
                en: "Chin tuck — back to wall or head off bed, 3×10, hold 2–3 s"
            )
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
    @MainActor
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

    @MainActor
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
                lines.append(AppCopy.t("Marche légère + mobilité douce", en: "Easy walk + gentle mobility"))
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

    @MainActor
    static func estimatedCircuitDurationMinutes(for plan: FaceOriginPlan) -> Int {
        let blocks = mobilityBlocks(for: plan)
        guard !blocks.isEmpty else { return 11 }

        var totalSeconds = 0
        for (index, block) in blocks.enumerated() {
            totalSeconds += estimatedSeconds(forBlock: block)
            if index > 0 { totalSeconds += 42 }
        }

        let raw = Int((Double(totalSeconds) / 60.0).rounded())
        return naturalCircuitDuration(rawMinutes: max(8, raw), blockCount: blocks.count)
    }

    @MainActor
    static func estimatedCircuitDurationLabel(for plan: FaceOriginPlan) -> String {
        "\(estimatedCircuitDurationMinutes(for: plan)) min"
    }

    private static func naturalCircuitDuration(rawMinutes: Int, blockCount: Int) -> Int {
        var value = rawMinutes
        while value % 5 == 0 {
            value += blockCount.isMultiple(of: 2) ? 2 : 3
        }
        return value
    }

    private static func estimatedSeconds(forBlock line: String) -> Int {
        let lower = line.lowercased()

        if let minutes = parseMinuteRange(from: lower) {
            return minutes * 60
        }

        if lower.contains("jambe") || (lower.contains("chaque") && lower.contains(" s")) {
            if let seconds = parseSeconds(from: lower) {
                let sides = lower.contains("avant") && lower.contains("gauche") && lower.contains("droite") ? 3 : 2
                return seconds * sides
            }
        }

        if let seconds = parseSeconds(from: lower) {
            return seconds
        }

        if let setsReps = parseSetsReps(from: line) {
            let hold = lower.contains("maintien") ? 3 : 4
            let work = setsReps.sets * setsReps.reps * hold
            let rest = setsReps.sets * 18
            return work + rest
        }

        return 88
    }

    private static func parseMinuteRange(from text: String) -> Int? {
        let rangePattern = #"(\d+)\s*[–\-]\s*(\d+)\s*min"#
        if let range = text.range(of: rangePattern, options: .regularExpression) {
            let match = String(text[range])
            let numbers = match.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap(Int.init)
            guard numbers.count >= 2 else { return numbers.first }
            return Int((Double(numbers[0] + numbers[1]) / 2.0).rounded())
        }

        let singlePattern = #"(\d+)\s*min"#
        guard let range = text.range(of: singlePattern, options: .regularExpression) else { return nil }
        let match = String(text[range])
        return match.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap(Int.init).first
    }

    private static func parseSeconds(from text: String) -> Int? {
        let pattern = #"(\d+)\s*s(?:ec)?(?:ondes?)?"#
        guard let range = text.range(of: pattern, options: .regularExpression) else { return nil }
        let match = String(text[range])
        return match.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap(Int.init).first
    }

    private static func parseSetsReps(from line: String) -> (sets: Int, reps: Int)? {
        let pattern = #"(\d+)\s*[×x]\s*(\d+)"#
        guard let range = line.range(of: pattern, options: .regularExpression) else { return nil }
        let match = String(line[range])
        let numbers = match.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap(Int.init)
        guard numbers.count >= 2 else { return nil }
        return (numbers[0], numbers[1])
    }
}

/// Section posture dédiée — le circuit est présenté dans « Cardio et Circuit ».
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
        PlanPostureCircuitContent.compactLines(for: plan, includeWalking: false)
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

                    blockTitle(PlanHomeSectionKind.training.title)
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(circuitLines, id: \.self) { line in
                            PlanTrainingBlockRow(line: line, fallbackSystemImage: postureIcon(for: line))
                        }
                    }
                }
                .padding()
            }
            .processTransparentScrollSurface()
            .navigationTitle(PlanHomeSectionKind.training.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(AppCopy.close) { dismiss() }
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
