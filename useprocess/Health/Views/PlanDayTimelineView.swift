import SwiftUI

// MARK: - Timeline chronologique du jour

struct PlanDayChronologicalTimeline: View {
    let day: OriginProgramDay
    let plan: FaceOriginPlan
    let selectedDate: Date
    var isEditable: Bool = true
    var onTaskStatusChange: (String, String, JournalTaskStatus?) -> Void

    private var checklistTasks: [OriginPlanTask] {
        OriginPlanPresenter.manualJournalTasks(from: day, plan: plan)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(checklistTasks) { task in
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
