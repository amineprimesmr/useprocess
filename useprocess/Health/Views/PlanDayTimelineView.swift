import SwiftUI

// MARK: - Timeline chronologique du jour

struct PlanDayChronologicalTimeline: View {
    let day: OriginProgramDay
    let plan: FaceOriginPlan
    let selectedDate: Date
    var isEditable: Bool = true
    var onTaskStatusChange: (String, String, JournalTaskStatus?) -> Void
    var onCompleteAll: (() -> Void)? = nil

    @Environment(\.appTheme) private var theme

    private var checklistTasks: [OriginPlanTask] {
        OriginPlanPresenter.manualJournalTasks(from: day, plan: plan)
    }

    private var coreCompletedCount: Int {
        checklistTasks.filter { plan.progress.status(for: $0.id, dayId: day.id) == .completed }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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

            if isEditable {
                completeAllButton
            }
        }
    }

    private var completeAllButton: some View {
        Button {
            HapticManager.shared.notification(.success)
            onCompleteAll?()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                Text("Tout valider")
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 0)
                Text("\(coreCompletedCount)/\(checklistTasks.count)")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(theme.secondaryText)
            }
            .foregroundStyle(theme.onboardingAccent)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(theme.onboardingAccent.opacity(theme.isDark ? 0.14 : 0.10))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(theme.onboardingAccent.opacity(0.22), lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Tout valider — \(coreCompletedCount) sur \(checklistTasks.count)")
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
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(training.warmup, id: \.self) { line in
                                PlanTrainingBlockRow(line: line, fallbackSystemImage: "figure.run")
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
                .padding()
            }
            .processTransparentScrollSurface()
            .navigationTitle(training.sessionName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
        .processAppPageBackground()
        .processAppPresentationBackground()
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
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                HealthDebloatGuideView()
                    .padding()
            }
            .processTransparentScrollSurface()
            .navigationTitle("Comprendre le debloat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
        .processAppPageBackground()
        .processAppPresentationBackground()
        .presentationDetents([.large])
    }
}

// MARK: - Ressources (hors timeline)

enum PlanResourceSheet: Identifiable, Hashable {
    case debloatGuide
    case continuousHabits

    var id: String {
        switch self {
        case .debloatGuide: "debloat"
        case .continuousHabits: "habits"
        }
    }
}

struct PlanResourcesFooter: View {
    @Binding var activeSheet: PlanResourceSheet?
    var zoomNamespace: Namespace.ID? = nil

    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: PlanHomeSectionDesign.headerContentSpacing) {
            PlanHomeSectionHeader(title: "Aller plus loin")

            resourceLink(
                sheet: .debloatGuide,
                title: "Guide debloat & habitudes 24/7",
                systemImage: "lightbulb.fill"
            )
        }
    }

    private func resourceLink(sheet: PlanResourceSheet, title: String, systemImage: String) -> some View {
        PlanInfoLinkButton(title: title, systemImage: systemImage) {
            activeSheet = sheet
        }
        .processZoomSource(id: .planResource(sheet), namespace: zoomNamespace)
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
            .processTransparentScrollSurface()
            .navigationTitle("Habitudes 24/7")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
        .processAppPageBackground()
        .processAppPresentationBackground()
        .presentationDetents([.medium, .large])
    }
}
