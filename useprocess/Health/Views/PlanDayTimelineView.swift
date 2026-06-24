import SwiftUI

// MARK: - Timeline chronologique du jour

struct PlanDayChronologicalTimeline: View {
    let day: OriginProgramDay
    let plan: FaceOriginPlan
    let selectedDate: Date
    var isEditable: Bool = true
    var onTaskStatusChange: (String, String, JournalTaskStatus?) -> Void

    @EnvironmentObject private var healthManager: HealthManager
    @Environment(\.appTheme) private var theme

    @State private var selectedTraining: OriginDayTraining?
    @State private var showTrainingDetail = false
    @State private var showNutritionGuide = false

    private var isSelectedToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    private var phases: [OriginPlanPresenter.PlanDayPhase] {
        OriginPlanPresenter.chronologicalPhases(
            for: day,
            calendar: plan.calendar,
            includeAutoTracking: isSelectedToday,
            includeMeals: false,
            includeTraining: false
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(phases) { phase in
                PlanDayTimelinePhaseRow(
                    phase: phase,
                    day: day,
                    plan: plan,
                    isEditable: isEditable,
                    healthSnapshot: healthManager.todaySnapshot,
                    onTaskStatusChange: onTaskStatusChange,
                    onOpenTraining: {
                        selectedTraining = $0
                        showTrainingDetail = true
                    },
                    onOpenNutritionGuide: { showNutritionGuide = true }
                )
            }
        }
        .sheet(isPresented: $showTrainingDetail) {
            if let training = selectedTraining {
                PlanTrainingDetailSheet(training: training, dayTitle: day.title)
            }
        }
        .sheet(isPresented: $showNutritionGuide) {
            PlanDebloatGuideSheet(initialPillar: .nutrition)
        }
    }
}

// MARK: - Ligne de phase

private struct PlanDayTimelinePhaseRow: View {
    let phase: OriginPlanPresenter.PlanDayPhase
    let day: OriginProgramDay
    let plan: FaceOriginPlan
    var isEditable: Bool
    var healthSnapshot: DailyHealthSnapshot
    var onTaskStatusChange: (String, String, JournalTaskStatus?) -> Void
    var onOpenTraining: (OriginDayTraining) -> Void
    var onOpenNutritionGuide: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            phaseHeader
            phaseContent
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var phaseHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(phase.title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(theme.primaryText)
            if let hint = phase.timeHint {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
            }
        }
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch phase.kind {
        case .checklist(let tasks):
            VStack(spacing: 8) {
                ForEach(tasks) { task in
                    JournalTaskRow(
                        task: task,
                        dayId: day.id,
                        plan: plan,
                        isEditable: isEditable,
                        onStatusChange: { status in
                            onTaskStatusChange(task.id, day.id, status)
                        }
                    )
                }
            }

        case .meals:
            OriginMealSuggestionCard(plan: plan, day: day, isEditable: isEditable)
                .environmentObject(UnifiedProfileService.shared)

            PlanInfoLinkButton(
                title: "Comprendre la nutrition debloat",
                systemImage: "book.fill",
                action: onOpenNutritionGuide
            )

        case .training(let training):
            PlanTrainingSummaryCard(training: training) {
                onOpenTraining(training)
            }

        case .autoTracking:
            VStack(spacing: 8) {
                PlanAutoMetricRow(
                    emoji: "👟",
                    title: "\(formatted(ProcessDailyTargets.dailySteps))+ pas",
                    value: healthSnapshot.effort.steps > 0
                        ? formatted(healthSnapshot.effort.steps) + " pas"
                        : "—",
                    progress: Double(healthSnapshot.effort.steps) / Double(max(ProcessDailyTargets.dailySteps, 1))
                )

                if healthSnapshot.effort.exerciseMinutes > 0 {
                    PlanAutoMetricRow(
                        emoji: "🏃",
                        title: "Exercice",
                        value: "\(Int(healthSnapshot.effort.exerciseMinutes)) min",
                        progress: healthSnapshot.effort.exerciseMinutes / 30
                    )
                }
            }
        }
    }

    private func formatted(_ value: Int) -> String {
        let nf = NumberFormatter()
        nf.locale = Locale(identifier: "fr_FR")
        nf.numberStyle = .decimal
        nf.groupingSeparator = " "
        return nf.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

// MARK: - Composants

struct PlanInfoLinkButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.onboardingAccent)
                    .frame(width: 22)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.primaryText)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(theme.secondaryText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(theme.coachUserBubble.opacity(theme.isDark ? 0.22 : 0.4))
            )
        }
        .buttonStyle(.plain)
    }
}

private struct PlanTrainingSummaryCard: View {
    let training: OriginDayTraining
    let onOpen: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 14) {
                Text("🏋️")
                    .font(.system(size: 26))
                VStack(alignment: .leading, spacing: 4) {
                    Text(training.sessionName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.primaryText)
                        .multilineTextAlignment(.leading)
                    Text("\(training.exercises.count) exercices · \(training.durationMinutes) min")
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.secondaryText)
            }
            .padding(14)
            .background(planCardBackground)
        }
        .buttonStyle(.plain)
    }

    private var planCardBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(theme.isDark ? Color(red: 0.11, green: 0.11, blue: 0.12) : theme.cardBackgroundStrong)
    }
}

private struct PlanAutoMetricRow: View {
    let emoji: String
    let title: String
    let value: String
    let progress: Double

    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(spacing: 14) {
            Text(emoji)
                .font(.system(size: 26))
                .frame(width: 32, alignment: .center)

            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(theme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(value)
                .font(.caption.weight(.medium))
                .foregroundStyle(theme.secondaryText)
                .monospacedDigit()

            JournalCircularProgressRing(
                progress: progress,
                fillColor: progress >= 1 ? Color(red: 0.35, green: 0.78, blue: 0.45) : theme.secondaryText.opacity(0.5)
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.isDark ? Color(red: 0.11, green: 0.11, blue: 0.12) : theme.cardBackgroundStrong)
        )
    }
}

// MARK: - Fiches détail

struct PlanTrainingDetailSheet: View {
    let training: OriginDayTraining
    let dayTitle: String

    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(dayTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.secondaryText)

                    if !training.warmup.isEmpty {
                        blockTitle("Échauffement")
                        bulletList(training.warmup)
                    }

                    blockTitle("Exercices")
                    VStack(spacing: 10) {
                        ForEach(training.exercises) { exercise in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(exercise.name)
                                    .font(.subheadline.weight(.semibold))
                                Text("\(exercise.sets)×\(exercise.reps) · repos \(exercise.restSeconds)s")
                                    .font(.caption)
                                    .foregroundStyle(theme.secondaryText)
                                if !exercise.coachingCue.isEmpty {
                                    Text(exercise.coachingCue)
                                        .font(.caption)
                                        .foregroundStyle(theme.primaryText.opacity(0.85))
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(HealthHubDesign.softCard(theme: theme))
                        }
                    }

                    if !training.cooldown.isEmpty {
                        blockTitle("Retour au calme")
                        bulletList(training.cooldown)
                    }

                    if let notes = training.notes, !notes.isEmpty {
                        blockTitle("Notes")
                        Text(notes)
                            .font(.subheadline)
                            .foregroundStyle(theme.secondaryText)
                    }
                }
                .padding()
            }
            .background(theme.background.ignoresSafeArea())
            .navigationTitle(training.sessionName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func blockTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(theme.secondaryText)
            .textCase(.uppercase)
    }

    private func bulletList(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(items, id: \.self) { item in
                Text("• \(item)")
                    .font(.subheadline)
                    .foregroundStyle(theme.primaryText)
            }
        }
    }
}

struct PlanDebloatGuideSheet: View {
    var initialPillar: HealthDebloatGuide.Pillar = .nutrition

    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                HealthDebloatGuideView(initialPillar: initialPillar)
                    .padding()
            }
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Comprendre le debloat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Ressources (hors timeline)

enum PlanResourceSheet: Identifiable {
    case debloatGuide
    case mealsHub
    case continuousHabits

    var id: String {
        switch self {
        case .debloatGuide: "debloat"
        case .mealsHub: "meals"
        case .continuousHabits: "habits"
        }
    }
}

struct PlanResourcesFooter: View {
    @Binding var activeSheet: PlanResourceSheet?

    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Aller plus loin")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.secondaryText)
                .textCase(.uppercase)
                .padding(.top, 8)

            PlanInfoLinkButton(title: "Guide debloat complet", systemImage: "lightbulb.fill") {
                activeSheet = .debloatGuide
            }

            PlanInfoLinkButton(title: "Historique repas & courses", systemImage: "cart.fill") {
                activeSheet = .mealsHub
            }

            PlanInfoLinkButton(title: "Habitudes 24/7", systemImage: "infinity") {
                activeSheet = .continuousHabits
            }
        }
    }
}

struct PlanMealsHubSheet: View {
    let mealHistory: [MealHistoryEntry]
    let shoppingItems: [MealShoppingItem]
    var onToggleShopping: (String) -> Void
    var onClearChecked: () -> Void

    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    MealHistoryCarouselView(entries: mealHistory, theme: theme)
                    MealShoppingListSection(
                        items: shoppingItems,
                        theme: theme,
                        onToggle: onToggleShopping,
                        onClearChecked: onClearChecked
                    )
                }
                .padding()
            }
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Repas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}

struct PlanContinuousHabitsSheet: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ces habitudes ne se cochent pas — elles s'appliquent en continu, toute la journée.")
                        .font(.subheadline)
                        .foregroundStyle(theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(Array(ProcessContinuousHabits.all.enumerated()), id: \.offset) { _, habit in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(habit.title)
                                .font(.subheadline.weight(.semibold))
                            Text(habit.detail)
                                .font(.caption)
                                .foregroundStyle(theme.secondaryText)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(HealthHubDesign.softCard(theme: theme))
                    }
                }
                .padding()
            }
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Habitudes 24/7")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
