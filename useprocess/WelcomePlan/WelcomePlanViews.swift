import SwiftUI

struct WelcomePlanCompactCard: View {
    let plan: FaceOriginPlan

    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(theme.onboardingAccent)
                Text(plan.headline)
                    .font(.headline)
                    .foregroundStyle(theme.primaryText)
            }

            Text(plan.primaryFaceGoal)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.onboardingAccent)

            Text(plan.executiveSummary)
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)
                .lineLimit(6)

            HStack(spacing: 8) {
                ForEach(plan.pillarScores) { pillar in
                    VStack(spacing: 4) {
                        Text("\(pillar.score)")
                            .font(.caption.bold().monospacedDigit())
                        Text(shortPillar(pillar.pillar))
                            .font(.caption2)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(theme.coachUserBubble.opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .padding(16)
        .background(theme.coachUserBubble.opacity(0.35), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func shortPillar(_ name: String) -> String {
        if name.contains("Hormones") { return "Hormones" }
        if name.contains("Entraînement") { return "Training" }
        if name.contains("Posture") { return "Posture" }
        if name.contains("Maxillaire") { return "Maxillaire" }
        return "Visage"
    }
}

struct WelcomePlanProfileSection: View {
    @State private var store = WelcomePlanStore.shared
    @State private var showProgram = false

    var body: some View {
        if let plan = store.plan {
            Button {
                showProgram = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "leaf.fill")
                        .foregroundStyle(ProfileTheme.avatarAccent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Protocole Origine · 13 sem.")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(ProfileTheme.textPrimary)
                        Text("Semaine \(plan.calendar.currentWeekNumber()) — \(plan.primaryFaceGoal)")
                            .font(.system(size: 13))
                            .foregroundStyle(ProfileTheme.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ProfileTheme.textSecondary)
                }
                .padding(14)
                .background(ProfileTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .fullScreenCover(isPresented: $showProgram) {
                OriginPlanProgramView(plan: plan)
            }
            .onAppear { store.reloadForCurrentUser() }
        }
    }
}

struct WelcomePlanDetailView: View {
    let plan: FaceOriginPlan

    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    WelcomePlanCompactCard(plan: plan)

                    section("Philosophie", items: [plan.philosophyNote])

                    section("Habitudes quotidiennes", items: plan.dailyHabits.map { "• \($0.title) — \($0.detail)" })

                    roadmapSection

                    protocolSection("Nutrition", items: plan.nutritionProtocol.principles + plan.nutritionProtocol.dailyStructure)
                    protocolSection("Sommeil", items: [
                        "Cible : \(String(format: "%.1f", plan.sleepProtocol.targetHours)) h",
                        plan.sleepProtocol.bedtimeWindow,
                        plan.sleepProtocol.wakeWindow
                    ] + plan.sleepProtocol.eveningRoutine + plan.sleepProtocol.morningRoutine)

                    protocolSection("Entraînement", items: [
                        plan.trainingProtocol.splitOverview,
                        "\(plan.trainingProtocol.sessionsPerWeek)× \(plan.trainingProtocol.sessionDurationMinutes) min"
                    ] + plan.trainingProtocol.weeklyTemplate + plan.trainingProtocol.recoveryRules)

                    protocolSection("Posture & fascias", items: plan.postureProtocol.dailyChecks + plan.postureProtocol.mobilityBlocks)

                    protocolSection("Mewing & maxillaire", items: plan.faceProtocol.focusAreas + plan.faceProtocol.jawAndTongueWork + plan.faceProtocol.lymphAndFascia)

                    section("Mindset", items: plan.mindsetNotes)
                }
                .padding()
            }
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Protocole Origine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }

    private var roadmapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Roadmap 13 semaines")
                .font(.headline)
                .foregroundStyle(theme.primaryText)

            ForEach(plan.phaseRoadmap) { phase in
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(phase.weeksRange) — \(phase.title)")
                        .font(.subheadline.weight(.semibold))
                    ForEach(phase.objectives, id: \.self) { obj in
                        Text("• \(obj)")
                            .font(.caption)
                            .foregroundStyle(theme.secondaryText)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.coachUserBubble.opacity(0.4), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private func section(_ title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(theme.primaryText)
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)
            }
        }
    }

    private func protocolSection(_ title: String, items: [String]) -> some View {
        section(title, items: items.map { $0.hasPrefix("•") ? $0 : "• \($0)" })
    }
}

struct WelcomePlanHealthSection: View {
    @State private var store = WelcomePlanStore.shared
    @Environment(\.appTheme) private var theme
    @State private var showDetail = false
    @State private var showProgram = false

    var body: some View {
        Group {
            if let plan = store.plan {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Ton Protocole Origine")
                            .font(.headline)
                            .foregroundStyle(theme.primaryText)
                        Spacer()
                        Button("Programme") { showProgram = true }
                            .font(.subheadline.weight(.semibold))
                        Button("Résumé") { showDetail = true }
                            .font(.subheadline.weight(.semibold))
                    }

                    WelcomePlanCompactCard(plan: plan)

                    Text("Semaine \(plan.calendar.currentWeekNumber())/13 · \(plan.progress.completedTaskIds.count) tâches · 100 % naturel")
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                }
                .sheet(isPresented: $showDetail) {
                    WelcomePlanDetailView(plan: plan)
                }
                .fullScreenCover(isPresented: $showProgram) {
                    OriginPlanProgramView(plan: plan)
                }
            }
        }
        .onAppear { store.reloadForCurrentUser() }
    }
}
