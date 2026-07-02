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

// MARK: - Programme entraînement complet (« Voir tout »)

struct PlanTrainingDayOverviewSheet: View {
    let plan: FaceOriginPlan
    let day: OriginProgramDay

    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var healthManager: HealthManager

    private var training: OriginDayTraining? { day.training }

    private var postureLines: [String] {
        PlanPostureCircuitContent.mobilityBlocks(for: plan)
    }

    private var walkingTarget: String? {
        PlanPostureCircuitContent.walkingTarget(for: plan)
    }

    private var stepsToday: Int {
        healthManager.todaySnapshot.effort.steps
    }

    private var stepTarget: Int {
        PlanPostureCircuitContent.dailyStepTarget(for: plan)
    }

    private var totalSessionCount: Int {
        TrainingProgramCatalog.allSessionTemplates().count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    programSummaryHeader

                    overviewSection(
                        title: "Salle de sport",
                        subtitle: "\(TrainingProgramCatalog.gymSessions().count) séances · force & hypertrophie"
                    ) {
                        sessionCards(TrainingProgramCatalog.gymSessions())
                    }

                    overviewSection(
                        title: "Maison",
                        subtitle: "\(TrainingProgramCatalog.homeSessions().count) séances · poids du corps & élastiques"
                    ) {
                        sessionCards(TrainingProgramCatalog.homeSessions())
                    }

                    overviewSection(
                        title: "Femme",
                        subtitle: "\(TrainingProgramCatalog.femaleSessions().count) séances · fessiers & haut du corps"
                    ) {
                        sessionCards(TrainingProgramCatalog.femaleSessions())
                    }

                    overviewSection(
                        title: "Récupération",
                        subtitle: "Repos actif · marche & mobilité"
                    ) {
                        restDayCard
                    }

                    overviewSection(
                        title: "Cardio & mobilité",
                        subtitle: "Échauffements et retours au calme du programme"
                    ) {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(TrainingProgramCatalog.sharedCardioMobilityBlocks(), id: \.self) { line in
                                PlanTrainingBlockRow(line: line, fallbackSystemImage: cardioIcon(for: line))
                            }
                        }
                    }

                    overviewSection(
                        title: "Circuit posture",
                        subtitle: "\(postureLines.count) blocs · nuque, épaules, hanches"
                    ) {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(postureLines, id: \.self) { line in
                                PlanTrainingBlockRow(
                                    line: line,
                                    fallbackSystemImage: postureIcon(for: line)
                                )
                            }
                        }
                    }
                }
                .padding()
            }
            .processTransparentScrollSurface()
            .navigationTitle("Programme entraînement")
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

    private var programSummaryHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(totalSessionCount) séances organisées")
                .font(.title3.weight(.bold))
                .foregroundStyle(theme.primaryText)

            Text("Salle · Maison · Femme · Récup · \(postureLines.count) blocs posture · cardio & mobilité")
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(sectionCardBackground)
    }

    @ViewBuilder
    private func overviewSection<Content: View>(
        title: String,
        subtitle: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(theme.primaryText)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                }
            }

            content()
        }
    }

    @ViewBuilder
    private func sessionCards(_ templates: [TrainingProgramSessionTemplate]) -> some View {
        VStack(spacing: 12) {
            ForEach(templates) { template in
                PlanTrainingSessionOverviewCard(
                    template: template,
                    liveTraining: liveTraining(for: template),
                    isToday: TrainingProgramCatalog.matchesToday(template, day: day) && training != nil
                )
            }
        }
    }

    private var restDayCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sessionHeader(
                title: TrainingProgramCatalog.restSession().sessionName,
                tags: TrainingProgramCatalog.restSession().catalogEntry.muscleTagsLabel,
                isToday: training == nil
            )

            if PlanPostureCircuitContent.hasWalkingTarget(for: plan) {
                HStack(spacing: 12) {
                    PlanTrainingMediaThumb(
                        assetName: TrainingAssetCatalog.blockAsset(for: "Marche"),
                        fallbackSystemImage: "figure.walk",
                        size: 52,
                        cornerRadius: 12
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Marche")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.primaryText)
                        Text(PlanStepsProgressFormatter.stepsRatio(current: stepsToday, target: stepTarget))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.secondaryText)
                            .monospacedDigit()
                        if let walkingTarget {
                            Text(walkingTarget)
                                .font(.caption)
                                .foregroundStyle(theme.secondaryText.opacity(0.9))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    PlanStepsProgressRing(progress: Double(stepsToday) / Double(max(stepTarget, 1)), size: 36)
                }
                .padding(.vertical, 4)
            } else if let walkingTarget {
                PlanTrainingBlockRow(line: walkingTarget, fallbackSystemImage: "figure.walk")
            } else {
                PlanTrainingBlockRow(
                    line: "Marche légère + mobilité douce",
                    fallbackSystemImage: "figure.walk"
                )
            }

            if !postureLines.isEmpty {
                Text("Enchaîner le circuit posture ci-dessous.")
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .padding(16)
        .background(sectionCardBackground)
        .overlay {
            if training == nil {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(theme.onboardingAccent.opacity(0.55), lineWidth: 1.5)
            }
        }
    }

    private func liveTraining(for template: TrainingProgramSessionTemplate) -> OriginDayTraining? {
        guard TrainingProgramCatalog.matchesToday(template, day: day) else { return nil }
        return training
    }

    private var sectionCardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(theme.isDark ? Color(red: 0.13, green: 0.13, blue: 0.14) : theme.cardBackgroundStrong)
    }

    private func sessionHeader(title: String, tags: String, isToday: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text(tags)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(theme.onboardingAccent.opacity(0.9))
            }
            Spacer(minLength: 8)
            if isToday {
                Text("Aujourd'hui")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(theme.onboardingAccent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(theme.onboardingAccent.opacity(0.14)))
            }
        }
    }

    private func cardioIcon(for line: String) -> String {
        let lower = line.lowercased()
        if lower.contains("sprint") { return "bolt.fill" }
        if lower.contains("vélo") || lower.contains("velo") { return "bicycle" }
        if lower.contains("mobilit") { return "figure.mind.and.body" }
        if lower.contains("marche") || lower.contains("étirement") { return "figure.walk" }
        return "flame.fill"
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

// MARK: - Carte séance (catalogue)

private struct PlanTrainingSessionOverviewCard: View {
    let template: TrainingProgramSessionTemplate
    var liveTraining: OriginDayTraining?
    var isToday: Bool = false

    @Environment(\.appTheme) private var theme

    private var warmup: [String] { liveTraining?.warmup ?? template.warmup }
    private var exercises: [OriginExercise] { liveTraining?.exercises ?? template.exercises }
    private var cooldown: [String] { liveTraining?.cooldown ?? template.cooldown }
    private var notes: String? { liveTraining?.notes }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.sessionName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(template.catalogEntry.muscleTagsLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(theme.onboardingAccent.opacity(0.9))
                }
                Spacer(minLength: 8)
                if isToday {
                    Text("Aujourd'hui")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(theme.onboardingAccent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(theme.onboardingAccent.opacity(0.14)))
                }
            }

            if !warmup.isEmpty {
                blockLabel("Échauffement")
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(warmup, id: \.self) { line in
                        PlanTrainingBlockRow(line: line, fallbackSystemImage: "flame.fill")
                    }
                }
            }

            if !exercises.isEmpty {
                blockLabel("Exercices · \(exercises.count)")
                VStack(spacing: 10) {
                    ForEach(exercises) { exercise in
                        PlanTrainingExerciseCard(exercise: exercise)
                    }
                }
            }

            if !cooldown.isEmpty {
                blockLabel("Retour au calme")
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(cooldown, id: \.self) { line in
                        PlanTrainingBlockRow(line: line, fallbackSystemImage: "figure.walk")
                    }
                }
            }

            if let notes, !notes.isEmpty {
                blockLabel("Notes")
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(theme.isDark ? Color(red: 0.13, green: 0.13, blue: 0.14) : theme.cardBackgroundStrong)
        }
        .overlay {
            if isToday {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(theme.onboardingAccent.opacity(0.55), lineWidth: 1.5)
            }
        }
    }

    private func blockLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(theme.secondaryText)
            .textCase(.uppercase)
    }
}
