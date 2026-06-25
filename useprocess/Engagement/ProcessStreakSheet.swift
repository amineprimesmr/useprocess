import SwiftUI

/// Page plein écran — streak + protocole Origine et journal du jour complets.
struct ProcessStreakSheet: View {
    @Binding var selectedDate: Date

    @Bindable private var streakStore = ProcessStreakStore.shared
    @Bindable private var planStore = WelcomePlanStore.shared

    @EnvironmentObject private var healthManager: HealthManager
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var weeklyMealHistory: [MealHistoryEntry] = []
    @State private var shoppingItems: [MealShoppingItem] = []
    @State private var activeResourceSheet: PlanResourceSheet?

    private var snapshot: ProcessStreakSnapshot { streakStore.snapshot }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    heroCard
                    todayCard
                    weekSection
                    monthSection
                    milestonesSection

                    protocolDivider

                    if let plan = planStore.plan {
                        fullProtocolSection(plan: plan)
                    } else {
                        noPlanCard
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 48)
            }
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Streak & Protocole")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(theme.secondaryText)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(theme.cardBackgroundStrong.opacity(theme.isDark ? 0.9 : 0.75))
                            )
                    }
                    .accessibilityLabel("Fermer")
                }
            }
            .refreshable {
                refreshMealSections()
                planStore.reloadForCurrentUser()
                streakStore.sync(from: planStore.plan)
            }
            .sheet(item: $activeResourceSheet) { sheet in
                resourceSheet(for: sheet)
            }
        }
        .onAppear {
            streakStore.sync(from: planStore.plan)
            refreshMealSections()
        }
        .onChange(of: planStore.plan?.lastUpdated) { _, _ in
            streakStore.sync(from: planStore.plan)
            refreshMealSections()
        }
    }

    // MARK: - Protocole complet

    private var protocolDivider: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
                .padding(.top, 4)

            Text("Ton protocole")
                .font(.title3.weight(.bold))
                .foregroundStyle(theme.primaryText)

            Text("Journal, repas, entraînement et ressources — tout ton plan Origine.")
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
    }

    @ViewBuilder
    private func fullProtocolSection(plan: FaceOriginPlan) -> some View {
        OriginPlanHeaderCard(plan: plan)

        if !plan.successCriteria.isEmpty {
            OriginPlanSuccessCriteriaCard(criteria: plan.successCriteria)
        }

        DailyJournalChecklistView(
            plan: plan,
            selectedDate: $selectedDate,
            showHeader: true,
            showWeekStrip: true
        )
        .environmentObject(healthManager)

        PlanResourcesFooter(activeSheet: $activeResourceSheet)
    }

    private var noPlanCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Aucun protocole chargé")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.primaryText)

            Text("Termine la configuration Origine sur l’onglet Plan pour débloquer ton journal complet ici.")
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(streakCardBackground)
    }

    @ViewBuilder
    private func resourceSheet(for sheet: PlanResourceSheet) -> some View {
        switch sheet {
        case .debloatGuide:
            PlanDebloatGuideSheet()
        case .mealsHub:
            PlanMealsHubSheet(
                mealHistory: weeklyMealHistory,
                shoppingItems: shoppingItems,
                onToggleShopping: { id in
                    planStore.toggleShoppingItem(id)
                    refreshMealSections()
                },
                onClearChecked: {
                    planStore.clearCheckedShoppingItems()
                    refreshMealSections()
                }
            )
        case .continuousHabits:
            PlanContinuousHabitsSheet()
        }
    }

    private func refreshMealSections() {
        weeklyMealHistory = planStore.mealHistoryThisWeek()
        shoppingItems = planStore.plan?.progress.shoppingList ?? []
    }

    // MARK: - Streak

    private var heroCard: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                ProcessStreakPalette.flame.opacity(0.35),
                                ProcessStreakPalette.flame.opacity(0.08),
                                .clear
                            ],
                            center: .center,
                            startRadius: 8,
                            endRadius: 72
                        )
                    )
                    .frame(width: 140, height: 140)

                Image(systemName: "flame.fill")
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(ProcessStreakPalette.flameGradient)
                    .shadow(color: ProcessStreakPalette.flame.opacity(0.35), radius: 16, y: 8)
            }
            .padding(.top, 8)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(snapshot.currentStreak)")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(theme.primaryText)
                    .monospacedDigit()

                Text(snapshot.currentStreak <= 1 ? "jour" : "jours")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
            }

            Text(snapshot.headline)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(theme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)

            HStack(spacing: 18) {
                statPill(title: "Record", value: "\(snapshot.longestStreak)")
                statPill(title: "Total", value: "\(snapshot.totalCompletedDays)")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(streakCardBackground)
    }

    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Aujourd’hui", systemImage: "sun.max.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.primaryText)

            HStack(spacing: 12) {
                ProgressView(value: snapshot.todayProgress)
                    .tint(snapshot.isTodayComplete ? ProcessStreakPalette.flame : theme.onboardingAccent)
                    .scaleEffect(x: 1, y: 1.6, anchor: .center)

                Text(snapshot.isTodayComplete ? "Checklist validée" : "\(Int(snapshot.todayProgress * 100)) %")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(snapshot.isTodayComplete ? ProcessStreakPalette.flame : theme.secondaryText)
                    .monospacedDigit()
            }

            Text(
                snapshot.isTodayComplete
                    ? "Ta streak est sécurisée pour aujourd’hui."
                    : "Valide toutes les habitudes de ta checklist pour compter la journée."
            )
            .font(.caption)
            .foregroundStyle(theme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(streakCardBackground)
    }

    private var weekSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("7 derniers jours")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.primaryText)

            HStack(spacing: 8) {
                ForEach(snapshot.week) { day in
                    VStack(spacing: 8) {
                        Text(day.weekdaySymbol)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(day.isToday ? theme.onboardingAccent : theme.secondaryText)

                        ZStack {
                            Circle()
                                .fill(dayFillColor(for: day))
                                .frame(width: 34, height: 34)

                            if day.isComplete {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                            } else if day.isToday {
                                Circle()
                                    .strokeBorder(theme.onboardingAccent, lineWidth: 2)
                                    .frame(width: 16, height: 16)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(streakCardBackground)
    }

    private var monthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("28 derniers jours")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.primaryText)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(snapshot.month) { day in
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(dayFillColor(for: day))
                        .frame(height: 18)
                        .overlay {
                            if day.isToday {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(theme.onboardingAccent, lineWidth: 1.5)
                            }
                        }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(streakCardBackground)
    }

    private var milestonesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Jalons")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.primaryText)

            if let next = snapshot.nextMilestone, let remaining = snapshot.daysUntilNextMilestone {
                Text("Plus que \(remaining) jour\(remaining > 1 ? "s" : "") avant \(next.title.lowercased()).")
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
            }

            VStack(spacing: 10) {
                ForEach(ProcessStreakMilestone.catalog) { milestone in
                    milestoneRow(milestone)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(streakCardBackground)
    }

    private func milestoneRow(_ milestone: ProcessStreakMilestone) -> some View {
        let unlocked = snapshot.currentStreak >= milestone.days
        let progress = min(1, Double(snapshot.currentStreak) / Double(milestone.days))

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(unlocked ? ProcessStreakPalette.flame.opacity(0.18) : theme.cardBackgroundStrong)
                    .frame(width: 36, height: 36)
                Image(systemName: unlocked ? "flame.fill" : "lock.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(unlocked ? ProcessStreakPalette.flame : theme.secondaryText.opacity(0.7))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(milestone.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.primaryText)
                    Spacer(minLength: 0)
                    Text(unlocked ? "Débloqué" : "\(Int(progress * 100)) %")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(unlocked ? ProcessStreakPalette.flame : theme.secondaryText)
                }

                Text(milestone.subtitle)
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(theme.cardStroke.opacity(0.35))
                        Capsule()
                            .fill(
                                unlocked
                                    ? AnyShapeStyle(ProcessStreakPalette.flameGradient)
                                    : AnyShapeStyle(theme.onboardingAccent.opacity(0.65))
                            )
                            .frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 5)
            }
        }
    }

    private func statPill(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(theme.primaryText)
                .monospacedDigit()
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(theme.secondaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(theme.cardBackgroundStrong.opacity(theme.isDark ? 0.9 : 0.75))
        )
    }

    private func dayFillColor(for day: ProcessStreakDaySnapshot) -> Color {
        if day.isFuture {
            return theme.cardStroke.opacity(0.25)
        }
        if day.isComplete {
            return ProcessStreakPalette.flame.opacity(day.isToday ? 1 : 0.82)
        }
        if day.isToday {
            return theme.onboardingAccent.opacity(0.12)
        }
        return theme.cardStroke.opacity(0.45)
    }

    private var streakCardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(theme.isDark ? theme.cardBackgroundStrong : theme.coachUserBubble)
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(theme.cardStroke, lineWidth: theme.isDark ? 0 : 0.5)
            }
    }
}

enum ProcessStreakPalette {
    static let flame = Color(red: 1.0, green: 0.45, blue: 0.12)

    static var flameGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.62, blue: 0.18),
                Color(red: 1.0, green: 0.34, blue: 0.08)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
