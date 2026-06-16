import SwiftUI

struct OriginPlanProgramView: View {
    let plan: FaceOriginPlan

    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var store = WelcomePlanStore.shared
    @State private var selectedWeek = 1
    @State private var selectedDayIndex = 0

    private var livePlan: FaceOriginPlan { store.plan ?? plan }

    private var currentWeek: OriginProgramWeek? {
        livePlan.calendar.weeks.first { $0.weekNumber == selectedWeek }
    }

    private var selectedDay: OriginProgramDay? {
        currentWeek?.days.first { $0.weekdayIndex == selectedDayIndex }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    progressHeader
                    weekPicker
                    dayPicker
                    if let day = selectedDay {
                        dayDetail(day)
                    }
                    extrasSection
                    modificationsSection
                }
                .padding()
            }
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Programme · \(livePlan.totalWeeks) sem.")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .onAppear {
                selectedWeek = livePlan.calendar.currentWeekNumber()
                let idx = livePlan.calendar.currentProgramDayIndex()
                if let week = livePlan.calendar.weeks.first(where: { w in w.days.contains(where: { $0.globalDayIndex == idx }) }) {
                    selectedWeek = week.weekNumber
                    selectedDayIndex = week.days.first(where: { $0.globalDayIndex == idx })?.weekdayIndex ?? 0
                }
                store.reloadForCurrentUser()
            }
        }
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(livePlan.primaryFaceGoal)
                .font(.headline)
                .foregroundStyle(theme.onboardingAccent)
            Text(livePlan.executiveSummary)
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)
            HStack {
                Label("Semaine \(livePlan.calendar.currentWeekNumber())/13", systemImage: "calendar")
                Spacer()
                Label("\(livePlan.progress.completedTaskIds.count) tâches", systemImage: "checkmark.circle")
            }
            .font(.caption)
            .foregroundStyle(theme.secondaryText)
        }
        .padding(14)
        .background(theme.coachUserBubble.opacity(0.35), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var weekPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(livePlan.calendar.weeks) { week in
                    Button {
                        selectedWeek = week.weekNumber
                        selectedDayIndex = 0
                    } label: {
                        Text("S\(week.weekNumber)")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                selectedWeek == week.weekNumber ? theme.onboardingAccent : theme.coachUserBubble,
                                in: Capsule()
                            )
                            .foregroundStyle(selectedWeek == week.weekNumber ? Color.white : theme.primaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var dayPicker: some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { idx in
                let label = ["L", "M", "M", "J", "V", "S", "D"][idx]
                Button {
                    selectedDayIndex = idx
                } label: {
                    Text(label)
                        .font(.caption.weight(.bold))
                        .frame(width: 36, height: 36)
                        .background(selectedDayIndex == idx ? theme.onboardingAccent : theme.coachUserBubble, in: Circle())
                        .foregroundStyle(selectedDayIndex == idx ? Color.white : theme.primaryText)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func dayDetail(_ day: OriginProgramDay) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(day.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(theme.primaryText)

            if let mindset = day.mindset {
                Text(mindset)
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
            }

            planSection(path: "\(day.id)/morning", title: "Matin", items: day.morning.map { ($0.title, $0.detail) }, tasks: day.morning)
            nutritionSection(for: day)
            if let training = day.training {
                let trainingText = training.exercises.map { "• \($0.name) \($0.sets)×\($0.reps) — \($0.coachingCue)" }.joined(separator: "\n")
                coachableBlock(
                    path: "\(day.id)/training",
                    title: "Entraînement — \(training.sessionName)",
                    content: "\(training.durationMinutes) min\n\(trainingText)\n\(training.notes ?? "")"
                )
            }

            planSection(path: "\(day.id)/posture", title: "Posture & marche", items: day.posture.map { ($0.title, $0.detail) }, tasks: day.posture)
            planSection(path: "\(day.id)/face", title: "Mewing & maxillaire", items: day.face.map { ($0.title, $0.detail) }, tasks: day.face)
            planSection(path: "\(day.id)/evening", title: "Soir", items: day.evening.map { ($0.title, $0.detail) }, tasks: day.evening)

            coachableBlock(
                path: "\(day.id)/sleep",
                title: "Sommeil",
                content: "Coucher \(day.sleep.targetBedtime) · Réveil \(day.sleep.targetWake) · \(String(format: "%.1f", day.sleep.targetHours)) h\n\(day.sleep.eveningActions.joined(separator: "\n"))"
            )
        }
    }

    @ViewBuilder
    private func nutritionSection(for day: OriginProgramDay) -> some View {
        let nutrition = day.nutrition
        let isOMAD = nutrition.isOMAD || livePlan.nutritionProtocol.mealPlanStyle == .omad

        if isOMAD {
            let meal = nutrition.omadMeal ?? nutrition.lunch
            planSection(
                path: "\(day.id)/nutrition",
                title: "Nutrition — OMAD (1 repas/jour)",
                items: [
                    ("Repas unique", meal.isEmpty ? "Repas dense — viande + tubercule + gras" : meal),
                    ("Hydratation", nutrition.hydration),
                    ("Principe", nutrition.principles.first ?? "1 repas/jour — fenêtre 4–6 h")
                ],
                tasks: []
            )
        } else if nutrition.mealPlanStyle == .twoMeals || livePlan.nutritionProtocol.mealPlanStyle == .twoMeals {
            planSection(
                path: "\(day.id)/nutrition",
                title: "Nutrition — 2 repas/jour",
                items: [
                    ("Déjeuner", nutrition.lunch),
                    ("Dîner", nutrition.dinner),
                    ("Hydratation", nutrition.hydration)
                ],
                tasks: []
            )
        } else {
            planSection(
                path: "\(day.id)/nutrition",
                title: "Nutrition",
                items: [
                    ("Petit-déjeuner", nutrition.breakfast),
                    ("Déjeuner", nutrition.lunch),
                    ("Dîner", nutrition.dinner),
                    ("Hydratation", nutrition.hydration)
                ],
                tasks: []
            )
        }
    }

    private func planSection(path: String, title: String, items: [(String, String)], tasks: [OriginPlanTask]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.0).font(.subheadline.weight(.semibold))
                    Text(CoachFormattedText.sanitizeField(item.1))
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                }
            }
            ForEach(tasks) { task in
                taskRow(task)
            }
            coachButtons(path: path, title: title, content: items.map { "\($0.0): \($0.1)" }.joined(separator: "\n"))
        }
        .padding(12)
        .background(theme.coachUserBubble.opacity(0.3), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func taskRow(_ task: OriginPlanTask) -> some View {
        let done = livePlan.progress.completedTaskIds.contains(task.id)
        return Button {
            store.toggleTaskComplete(taskId: task.id, dayId: task.id)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(done ? theme.onboardingAccent : theme.secondaryText)
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title).font(.subheadline.weight(.medium))
                    Text(task.detail).font(.caption).foregroundStyle(theme.secondaryText)
                }
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    private func coachableBlock(path: String, title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Text(content).font(.caption).foregroundStyle(theme.secondaryText)
            coachButtons(path: path, title: title, content: content)
        }
        .padding(12)
        .background(theme.coachUserBubble.opacity(0.3), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func coachButtons(path: String, title: String, content: String) -> some View {
        HStack(spacing: 8) {
            coachChip("Demander", mode: .ask, path: path, title: title, content: content)
            coachChip("Évaluer", mode: .evaluate, path: path, title: title, content: content)
            coachChip("Modifier", mode: .modify, path: path, title: title, content: content)
        }
    }

    private func coachChip(_ label: String, mode: PlanCoachMode, path: String, title: String, content: String) -> some View {
        Button {
            CoachPlanNavigationBridge.shared.askCoachAboutPlan(
                focus: CoachPlanFocus(sectionPath: path, sectionTitle: title, sectionContent: content, mode: mode)
            )
            dismiss()
        } label: {
            Text(label)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(theme.onboardingAccent.opacity(0.2), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var extrasSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Protocoles complémentaires")
                .font(.headline)
            groupBlock("Soleil & lumière", livePlan.lifestyleExtras.sunlightProtocol)
            groupBlock("Récupération", livePlan.lifestyleExtras.recoveryProtocol)
            groupBlock("Suivi", livePlan.lifestyleExtras.trackingChecklist)
            Text("Propositions bonus")
                .font(.subheadline.weight(.semibold))
            ForEach(livePlan.lifestyleExtras.bonusProposals, id: \.self) { proposal in
                Text("• \(proposal)").font(.caption).foregroundStyle(theme.secondaryText)
            }
        }
    }

    private func groupBlock(_ title: String, _ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline.weight(.semibold))
            ForEach(items, id: \.self) { item in
                Text("• \(item)").font(.caption).foregroundStyle(theme.secondaryText)
            }
            coachButtons(path: "extras/\(title)", title: title, content: items.joined(separator: "\n"))
        }
    }

    private var modificationsSection: some View {
        Group {
            if !livePlan.progress.modifications.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Historique ajustements coach")
                        .font(.headline)
                    ForEach(livePlan.progress.modifications.prefix(5)) { mod in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(mod.sectionPath).font(.caption.weight(.semibold))
                            Text(mod.coachResponse).font(.caption2).foregroundStyle(theme.secondaryText).lineLimit(3)
                        }
                    }
                }
            }
        }
    }
}
