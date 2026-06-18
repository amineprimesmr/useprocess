import SwiftUI

enum OriginPlanProgramSection: String, CaseIterable, Identifiable {
    case today = "Aujourd'hui"
    case week = "Semaine"
    case pillars = "Piliers"

    var id: String { rawValue }
}

struct OriginPlanHeaderCard: View {
    let plan: FaceOriginPlan
    @Environment(\.appTheme) private var theme

    var body: some View {
        let counts = OriginPlanPresenter.todayTaskCount(in: plan)
        let week = plan.calendar.currentWeekNumber()

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Protocole Origine · S\(week)/\(plan.totalWeeks)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.secondaryText)
                    Text(OriginPlanPresenter.phaseHeadline(plan))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.primaryText)
                }
                Spacer()
                if counts.total > 0 {
                    Text("\(counts.done)/\(counts.total)")
                        .font(.title3.weight(.bold).monospacedDigit())
                        .foregroundStyle(theme.onboardingAccent)
                }
            }

            Text(OriginPlanPresenter.oneLineSummary(plan))
                .font(.headline)
                .foregroundStyle(theme.onboardingAccent)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.coachUserBubble.opacity(0.35), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct OriginPlanProgramContent: View {
    @Binding var section: OriginPlanProgramSection
    let plan: FaceOriginPlan
    var closesOnCoachAsk = false

    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var store = WelcomePlanStore.shared
    @State private var selectedWeek = 1
    @State private var selectedDayIndex = 0

    private var livePlan: FaceOriginPlan { store.plan ?? plan }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            switch section {
            case .today:
                todayContent
            case .week:
                weekContent
            case .pillars:
                pillarsContent
            }
        }
        .onAppear { syncWeekDaySelection() }
    }

    @ViewBuilder
    private var todayContent: some View {
        prioritiesSection

        if let day = OriginPlanPresenter.todayDay(in: livePlan) {
            todayEssentials(day)
            continuousHabitsSection
            checklistSection(day)
        } else {
            Text("Calendrier en cours de génération.")
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)
        }
    }

    private var prioritiesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HealthHubDesign.sectionHeader("Tes 3 leviers", subtitle: "Priorité impact", theme: theme)

            ForEach(OriginPlanPresenter.impactPriorities(from: livePlan)) { pillar in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(pillar.score)")
                        .font(.title3.weight(.bold).monospacedDigit())
                        .foregroundStyle(pillar.score < 60 ? theme.onboardingAccent : theme.primaryText)
                        .frame(width: 36)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(shortPillarName(pillar.pillar))
                                .font(.subheadline.weight(.semibold))
                            Spacer(minLength: 8)
                            Text(OriginPlanPresenter.impactLabel(for: pillar.score))
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(theme.onboardingAccent.opacity(0.15), in: Capsule())
                        }
                        Text(OriginPlanPresenter.truncate(pillar.focus, max: 90))
                            .font(.caption)
                            .foregroundStyle(theme.secondaryText)
                    }
                }
                .padding(12)
                .background(cardBackground)
            }
        }
    }

    private func todayEssentials(_ day: OriginProgramDay) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HealthHubDesign.sectionHeader("Essentiel du jour", subtitle: day.title, theme: theme)

            OriginMealSuggestionCard(plan: livePlan, day: day)
                .environmentObject(UnifiedProfileService.shared)

            essentialRow(icon: "bed.double.fill", title: "Sommeil", value: OriginPlanPresenter.sleepOneLiner(day.sleep))
            if let training = OriginPlanPresenter.trainingOneLiner(day.training) {
                essentialRow(icon: "figure.strengthtraining.traditional", title: "Sport", value: training)
            }
        }
    }

    private var continuousHabitsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HealthHubDesign.sectionHeader("En permanence", subtitle: "24/7 — rien à cocher", theme: theme)

            ForEach(Array(ProcessContinuousHabits.all.enumerated()), id: \.offset) { _, habit in
                VStack(alignment: .leading, spacing: 4) {
                    Text(habit.title)
                        .font(.subheadline.weight(.semibold))
                    Text(habit.detail)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(cardBackground)
            }
        }
    }

    private func checklistSection(_ day: OriginProgramDay) -> some View {
        DailyJournalChecklistView(plan: livePlan, showHeader: false, showWeekStrip: true)
            .environmentObject(HealthManager.shared)
    }

    private var weekContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            weekPicker
            dayPicker

            if let day = selectedProgramDay {
                Text(day.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.primaryText)

                collapsedBlock("Matin", tasks: day.morning, path: "\(day.id)/morning")
                collapsedNutrition(day)
                if let training = day.training {
                    collapsedTraining(day, training)
                }
                collapsedBlock("Posture", tasks: day.posture, path: "\(day.id)/posture")
                if !day.face.isEmpty {
                    collapsedBlock("Visage", tasks: day.face, path: "\(day.id)/face")
                }
                collapsedBlock("Soir", tasks: day.evening, path: "\(day.id)/evening")
                collapsedSleep(day)
            }
        }
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
                            .background(selectedWeek == week.weekNumber ? theme.onboardingAccent : theme.coachUserBubble, in: Capsule())
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

    private var selectedProgramDay: OriginProgramDay? {
        livePlan.calendar.weeks.first { $0.weekNumber == selectedWeek }?
            .days.first { $0.weekdayIndex == selectedDayIndex }
    }

    private var pillarsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HealthHubDesign.sectionHeader(
                "Roadmap",
                subtitle: "\(livePlan.durationMinWeeks)–\(livePlan.durationMaxWeeks) semaines",
                theme: theme
            )

            ForEach(livePlan.phaseRoadmap) { phase in
                let isCurrent = OriginPlanPresenter.phaseHeadline(livePlan) == phase.title
                DisclosureGroup(isExpanded: .constant(isCurrent)) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(phase.objectives.prefix(3), id: \.self) { obj in
                            Text("• \(OriginPlanPresenter.truncate(obj, max: 100))")
                                .font(.caption)
                                .foregroundStyle(theme.secondaryText)
                        }
                    }
                    .padding(.top, 6)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(phase.weeksRange)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(theme.secondaryText)
                        Text(phase.title)
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .padding(12)
                .background(cardBackground)
            }

            HealthHubDesign.sectionHeader("Habitudes clés", subtitle: "5 maximum", theme: theme)

            ForEach(livePlan.dailyHabits.prefix(5)) { habit in
                VStack(alignment: .leading, spacing: 4) {
                    Text(habit.title).font(.subheadline.weight(.semibold))
                    Text(OriginPlanPresenter.truncate(habit.detail, max: 80))
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(cardBackground)
            }

            protocolAccordion("Nutrition", items: livePlan.nutritionProtocol.principles.prefix(4).map { String($0) })
            protocolAccordion("Sommeil", items: [
                "\(String(format: "%.1f", livePlan.sleepProtocol.targetHours)) h · \(livePlan.sleepProtocol.bedtimeWindow)"
            ] + livePlan.sleepProtocol.eveningRoutine.prefix(2).map { String($0) })
            protocolAccordion("Entraînement", items: [
                livePlan.trainingProtocol.splitOverview,
                "\(livePlan.trainingProtocol.sessionsPerWeek)× \(livePlan.trainingProtocol.sessionDurationMinutes) min"
            ])
        }
    }

    private var cardBackground: some View {
        HealthHubDesign.softCard(theme: theme)
    }

    private func essentialRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(theme.onboardingAccent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(theme.secondaryText)
                Text(value).font(.subheadline.weight(.medium)).foregroundStyle(theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(cardBackground)
    }

    private func taskRow(_ task: OriginPlanTask, dayId: String) -> some View {
        JournalTaskRow(
            task: task,
            dayId: dayId,
            plan: livePlan,
            onStatusChange: { status in
                store.setJournalTaskStatus(status, taskId: task.id, dayId: dayId)
            }
        )
    }

    private func collapsedBlock(_ title: String, tasks: [OriginPlanTask], path: String) -> some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(tasks) { task in
                    taskRow(task, dayId: path)
                }
                coachLink(path: path, title: title, content: tasks.map { "\($0.title): \($0.detail)" }.joined(separator: "\n"))
            }
            .padding(.top, 8)
        } label: {
            HStack {
                Text(title).font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(tasks.count)").font(.caption.weight(.bold)).foregroundStyle(theme.secondaryText)
            }
        }
        .padding(12)
        .background(cardBackground)
    }

    private func collapsedNutrition(_ day: OriginProgramDay) -> some View {
        OriginMealSuggestionCard(plan: livePlan, day: day)
            .environmentObject(UnifiedProfileService.shared)
    }

    private func collapsedTraining(_ day: OriginProgramDay, _ training: OriginDayTraining) -> some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(training.exercises.prefix(4)) { ex in
                    Text("• \(ex.name) \(ex.sets)×\(ex.reps)")
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                }
                coachLink(path: "\(day.id)/training", title: training.sessionName, content: OriginPlanPresenter.trainingOneLiner(training) ?? training.sessionName)
            }
            .padding(.top, 8)
        } label: {
            Text("Entraînement · \(training.durationMinutes) min").font(.subheadline.weight(.semibold))
        }
        .padding(12)
        .background(cardBackground)
    }

    private func collapsedSleep(_ day: OriginProgramDay) -> some View {
        DisclosureGroup {
            Text(OriginPlanPresenter.sleepOneLiner(day.sleep))
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
                .padding(.top, 8)
        } label: {
            Text("Sommeil").font(.subheadline.weight(.semibold))
        }
        .padding(12)
        .background(cardBackground)
    }

    private func protocolAccordion(_ title: String, items: [String]) -> some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(items, id: \.self) { item in
                    Text("• \(OriginPlanPresenter.truncate(item, max: 100))")
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                }
            }
            .padding(.top, 6)
        } label: {
            Text(title).font(.subheadline.weight(.semibold))
        }
        .padding(12)
        .background(cardBackground)
    }

    private func coachLink(path: String, title: String, content: String) -> some View {
        Button {
            CoachPlanNavigationBridge.shared.askCoachAboutPlan(
                focus: CoachPlanFocus(sectionPath: path, sectionTitle: title, sectionContent: content, mode: .ask)
            )
            if closesOnCoachAsk { dismiss() }
        } label: {
            Label("Demander au coach", systemImage: "sparkles")
                .font(.caption.weight(.semibold))
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.onboardingAccent)
    }

    private func syncWeekDaySelection() {
        selectedWeek = livePlan.calendar.currentWeekNumber()
        let idx = livePlan.calendar.currentProgramDayIndex()
        if let week = livePlan.calendar.weeks.first(where: { w in w.days.contains(where: { $0.globalDayIndex == idx }) }) {
            selectedWeek = week.weekNumber
            selectedDayIndex = week.days.first(where: { $0.globalDayIndex == idx })?.weekdayIndex ?? 0
        }
    }

    private func shortPillarName(_ name: String) -> String {
        if name.contains("Hormones") { return "Hormones & sommeil" }
        if name.contains("Entraînement") { return "Entraînement" }
        if name.contains("Posture") { return "Posture" }
        if name.contains("Maxillaire") { return "Maxillaire" }
        if name.contains("Visage") { return "Visage" }
        return OriginPlanPresenter.truncate(name, max: 22)
    }
}
