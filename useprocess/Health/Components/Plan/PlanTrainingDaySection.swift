import SwiftUI

// MARK: - Section entraînement (page Plan)

struct PlanTrainingDaySection: View {
    let plan: FaceOriginPlan
    let day: OriginProgramDay
    var selectedDate: Date = Date()
    var isEditable: Bool = true

    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var healthManager: HealthManager

    @Namespace private var trainingZoomNamespace
    @State private var selectedProtocolItem: PlanProtocolCarouselItem?
    @State private var showsDayOverview = false

    private var training: OriginDayTraining? { day.training }

    private var stepsToday: Int {
        healthManager.todaySnapshot.effort.steps
    }

    private var carouselItems: [PlanProtocolCarouselItem] {
        if let training {
            return PlanProtocolCarouselBuilder.trainingDayCarouselItems(
                training: training,
                plan: plan,
                stepsToday: stepsToday
            )
        }
        return PlanProtocolCarouselBuilder.restDayCarouselItems(
            plan: plan,
            stepsToday: stepsToday
        )
    }

    /// Cartes affichées sans la carte « Voir tout » (compteur header).
    private var previewCarouselItems: [PlanProtocolCarouselItem] {
        carouselItems.filter { $0.id != PlanProtocolCarouselBuilder.SummaryID.seeAllTraining }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PlanHomeSectionDesign.headerContentSpacing) {
            PlanProtocolSectionHeader(
                title: "Entraînement du jour",
                trailing: sectionHeaderTrailing
            )

            PlanDayProtocolCarousel(
                items: carouselItems,
                zoomNamespace: trainingZoomNamespace,
                zoomIDForItem: { zoomID(for: $0) },
                onTap: handleCarouselTap
            )
            .processZoomSource(id: .trainingDay, namespace: trainingZoomNamespace)
        }
        .sheet(item: $selectedProtocolItem) { item in
            PlanProtocolItemDetailSheet(item: item)
        }
        .fullScreenCover(isPresented: $showsDayOverview) {
            PlanTrainingDayOverviewSheet(plan: plan, day: day)
                .processZoomTransition(id: .trainingDay, namespace: trainingZoomNamespace)
        }
    }

    private func handleCarouselTap(_ item: PlanProtocolCarouselItem) {
        if item.id == PlanProtocolCarouselBuilder.SummaryID.seeAllTraining {
            HapticManager.shared.impact(.light)
            showsDayOverview = true
        } else {
            selectedProtocolItem = item
        }
    }

    private var sectionHeaderTrailing: String? {
        if let training {
            return trainingHeaderTrailing(for: training)
        }
        return "Repos actif · \(previewCarouselItems.count) blocs"
    }

    private func trainingHeaderTrailing(for training: OriginDayTraining) -> String? {
        var parts: [String] = []
        if training.durationMinutes > 0 {
            parts.append("\(training.durationMinutes) min")
        }
        let exerciseCount = training.exercises.count
        if exerciseCount > 0 {
            parts.append("\(exerciseCount) ex.")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func zoomID(for item: PlanProtocolCarouselItem) -> ProcessZoomTransitionID {
        if item.id == PlanProtocolCarouselBuilder.SummaryID.seeAllTraining {
            return .trainingDay
        }
        if item.id.hasPrefix("posture-") {
            return .postureCircuit
        }
        return .protocolItem(item.id)
    }
}

// MARK: - Aperçu complet du jour

struct PlanTrainingDayOverviewSheet: View {
    let plan: FaceOriginPlan
    let day: OriginProgramDay

    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    private var training: OriginDayTraining? { day.training }

    private var postureLines: [String] {
        PlanPostureCircuitContent.mobilityBlocks(for: plan)
    }

    private var walkingTarget: String? {
        PlanPostureCircuitContent.walkingTarget(for: plan)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !day.title.isEmpty {
                        Text(day.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.secondaryText)
                    }

                    if let training {
                        sessionSection(training)
                    } else {
                        restDaySection
                    }

                    postureSection
                }
                .padding()
            }
            .processTransparentScrollSurface()
            .navigationTitle(training?.sessionName ?? "Entraînement du jour")
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

    @ViewBuilder
    private func sessionSection(_ training: OriginDayTraining) -> some View {
        if !training.warmup.isEmpty {
            blockTitle("Échauffement")
            VStack(alignment: .leading, spacing: 6) {
                ForEach(training.warmup, id: \.self) { line in
                    PlanTrainingBlockRow(line: line, fallbackSystemImage: "flame.fill")
                }
            }
        }

        blockTitle("Exercices")
        VStack(spacing: 10) {
            ForEach(training.exercises) { exercise in
                PlanTrainingExerciseCard(exercise: exercise)
            }
        }

        if !training.cooldown.isEmpty {
            blockTitle("Retour au calme")
            VStack(alignment: .leading, spacing: 6) {
                ForEach(training.cooldown, id: \.self) { line in
                    PlanTrainingBlockRow(line: line, fallbackSystemImage: "figure.walk")
                }
            }
        }

        if let notes = training.notes, !notes.isEmpty {
            blockTitle("Notes")
            Text(notes)
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)
        }
    }

    @ViewBuilder
    private var restDaySection: some View {
        blockTitle("Repos actif")
        if let walkingTarget {
            PlanTrainingBlockRow(line: walkingTarget, fallbackSystemImage: "figure.walk")
        } else {
            PlanTrainingBlockRow(
                line: "Marche légère + mobilité douce",
                fallbackSystemImage: "figure.walk"
            )
        }
    }

    @ViewBuilder
    private var postureSection: some View {
        blockTitle("Circuit posture")
        VStack(alignment: .leading, spacing: 6) {
            ForEach(postureLines, id: \.self) { line in
                PlanTrainingBlockRow(
                    line: line,
                    fallbackSystemImage: postureIcon(for: line)
                )
            }
        }
    }

    private func blockTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(theme.secondaryText)
            .textCase(.uppercase)
    }

    private func postureIcon(for line: String) -> String {
        let lower = line.lowercased()
        if lower.contains("buteyko") || lower.contains("respiration") || lower.contains("digastrique") {
            return "wind"
        }
        if lower.contains("marche") || lower.contains("pas") {
            return "figure.walk"
        }
        return "figure.mind.and.body"
    }
}
