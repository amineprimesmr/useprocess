import SwiftUI

/// Vue autonome de la série quotidienne.
///
/// Aucun jour de l'accueil n'est modifié pendant la consultation : la date
/// externe ne change que lorsque l'utilisateur choisit explicitement d'ouvrir
/// le journal du jour.
struct ProcessStreakSheet: View {
    @Binding private var selectedDate: Date

    @Bindable private var streakStore = ProcessStreakStore.shared
    @Bindable private var planStore = WelcomePlanStore.shared

    @EnvironmentObject private var profileService: UnifiedProfileService
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    init(selectedDate: Binding<Date>) {
        _selectedDate = selectedDate
    }

    private var snapshot: ProcessStreakSnapshot {
        streakStore.snapshot
    }

    private var firstName: String {
        profileService.currentProfile?.firstName
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var safeTodayProgress: Double {
        guard snapshot.todayProgress.isFinite else { return 0 }
        return min(1, max(0, snapshot.todayProgress))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ProcessScreenBackground()

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 18) {
                        heroCard
                        todayCard
                        weekSection
                        historySection
                        statisticsSection
                        milestoneSection
                        explanationSection

                        if planStore.plan != nil {
                            openTodayJournalButton
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
                .processTransparentScrollSurface()
            }
            .navigationTitle("Ma série")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    closeButton
                }
            }
            .refreshable {
                planStore.reloadForCurrentUser()
                streakStore.sync(from: planStore.plan)
            }
        }
        .processClearUIKitHostingBackground()
        .onAppear(perform: refresh)
        .onChange(of: planStore.plan?.lastUpdated) { _, _ in
            refresh()
        }
    }

    // MARK: - Hero

    private var heroCard: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(ProcessStreakPalette.flame.opacity(theme.isDark ? 0.14 : 0.10))
                    .frame(width: 126, height: 126)

                Circle()
                    .strokeBorder(ProcessStreakPalette.flame.opacity(0.24), lineWidth: 1)
                    .frame(width: 126, height: 126)

                VStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(ProcessStreakPalette.flameGradient)

                    Text("\(snapshot.currentStreak)")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.primaryText)
                        .monospacedDigit()

                    Text(snapshot.currentStreak > 1 ? "jours" : "jour")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.secondaryText)
                }
            }

            VStack(spacing: 6) {
                Text(snapshot.streakTitle)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(theme.primaryText)

                Text(snapshot.encouragement(firstName: firstName))
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .padding(.vertical, 22)
        .background(cardBackground(cornerRadius: 28))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Aujourd'hui

    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: snapshot.isTodayComplete ? "checkmark.circle.fill" : "sun.max.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(
                        snapshot.isTodayComplete
                            ? ProcessStreakPalette.flame
                            : theme.onboardingAccent
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Aujourd’hui")
                        .font(.headline)
                        .foregroundStyle(theme.primaryText)

                    Text(
                        snapshot.isTodayComplete
                            ? "Journée validée"
                            : "Progression de la checklist"
                    )
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
                }

                Spacer(minLength: 8)

                Text(snapshot.isTodayComplete ? "100 %" : "\(Int(safeTodayProgress * 100)) %")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(
                        snapshot.isTodayComplete
                            ? ProcessStreakPalette.flame
                            : theme.primaryText
                    )
                    .monospacedDigit()
            }

            ProgressView(value: safeTodayProgress)
                .tint(
                    snapshot.isTodayComplete
                        ? ProcessStreakPalette.flame
                        : theme.onboardingAccent
                )

            Text(
                snapshot.isTodayComplete
                    ? "Ta série est protégée jusqu’à demain."
                    : "Termine les habitudes du jour pour valider cette journée."
            )
            .font(.caption)
            .foregroundStyle(theme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(cardBackground())
    }

    // MARK: - Semaine

    private var weekSection: some View {
        sectionCard(title: "Cette semaine", subtitle: weekSummary) {
            HStack(spacing: 7) {
                ForEach(snapshot.calendarWeek) { day in
                    ProcessStreakWeekDayCell(day: day)
                }
            }
        }
    }

    private var weekSummary: String {
        let completed = snapshot.calendarWeek.filter(\.isComplete).count
        return "\(completed) jour\(completed > 1 ? "s" : "") validé\(completed > 1 ? "s" : "") sur 7"
    }

    // MARK: - Historique

    private var historySection: some View {
        sectionCard(
            title: "28 derniers jours",
            subtitle: "Chaque flamme représente une journée entièrement validée."
        ) {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 7),
                spacing: 7
            ) {
                ForEach(snapshot.month) { day in
                    ProcessStreakHistoryDayCell(day: day)
                }
            }
        }
    }

    // MARK: - Statistiques

    private var statisticsSection: some View {
        HStack(spacing: 10) {
            statisticCard(
                value: snapshot.totalCompletedDays,
                label: "Jours validés",
                symbol: "checkmark.circle.fill"
            )
            statisticCard(
                value: snapshot.longestStreak,
                label: "Meilleur record",
                symbol: "trophy.fill"
            )
        }
    }

    private func statisticCard(value: Int, label: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ProcessStreakPalette.flame)

            Text("\(value)")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(theme.primaryText)
                .monospacedDigit()

            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(theme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(cardBackground())
        .accessibilityElement(children: .combine)
    }

    // MARK: - Palier

    @ViewBuilder
    private var milestoneSection: some View {
        if let milestone = snapshot.nextMilestone,
           let remaining = snapshot.daysUntilNextMilestone {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "flag.checkered")
                        .font(.headline)
                        .foregroundStyle(theme.onboardingAccent)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Prochain palier")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.secondaryText)
                        Text(milestone.title)
                            .font(.headline)
                            .foregroundStyle(theme.primaryText)
                    }

                    Spacer()

                    Text("\(remaining) j")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(theme.onboardingAccent)
                        .monospacedDigit()
                }

                ProgressView(value: milestoneProgress(for: milestone))
                    .tint(theme.onboardingAccent)

                Text(milestone.subtitle)
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
            }
            .padding(16)
            .background(cardBackground())
        } else {
            HStack(spacing: 12) {
                Image(systemName: "crown.fill")
                    .font(.title3)
                    .foregroundStyle(ProcessStreakPalette.flame)
                Text("Tous les paliers sont débloqués.")
                    .font(.headline)
                    .foregroundStyle(theme.primaryText)
                Spacer()
            }
            .padding(16)
            .background(cardBackground())
        }
    }

    private func milestoneProgress(for milestone: ProcessStreakMilestone) -> Double {
        let previous = ProcessStreakMilestone.catalog
            .map(\.days)
            .filter { $0 < milestone.days }
            .max() ?? 0
        let span = max(1, milestone.days - previous)
        return min(1, max(0, Double(snapshot.currentStreak - previous) / Double(span)))
    }

    // MARK: - Explication

    private var explanationSection: some View {
        sectionCard(
            title: "Comment fonctionne la série ?",
            subtitle: nil
        ) {
            VStack(spacing: 12) {
                explanationRow(
                    symbol: "checklist",
                    title: "Termine ta checklist",
                    text: "Une journée compte lorsque toutes les habitudes manuelles sont validées."
                )
                explanationRow(
                    symbol: "calendar",
                    title: "Reviens chaque jour",
                    text: "La série reste active si aujourd’hui ou hier est validé."
                )
                explanationRow(
                    symbol: "lock.shield.fill",
                    title: "Tes données restent cohérentes",
                    text: "Le calcul provient directement de ton protocole et de ton journal."
                )
            }
        }
    }

    private func explanationRow(symbol: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.onboardingAccent)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.primaryText)
                Text(text)
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Actions et composants

    private var openTodayJournalButton: some View {
        Button {
            HapticManager.shared.impact(.light)
            selectedDate = Calendar.current.startOfDay(for: Date())
            dismiss()
        } label: {
            Label("Ouvrir le journal d’aujourd’hui", systemImage: "arrow.right.circle.fill")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
        }
        .buttonStyle(.borderedProminent)
        .tint(theme.onboardingAccent)
        .accessibilityHint("Ferme la page et affiche le journal du jour")
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.secondaryText)
        .background(Circle().fill(theme.cardBackgroundStrong))
        .accessibilityLabel("Fermer")
    }

    private func sectionCard<Content: View>(
        title: String,
        subtitle: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(theme.primaryText)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground())
    }

    private func cardBackground(cornerRadius: CGFloat = 20) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(theme.cardBackgroundStrong.opacity(theme.isDark ? 0.88 : 0.96))
            .overlay {
                if theme.isDark {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(theme.cardStroke.opacity(0.45), lineWidth: 0.5)
                }
            }
    }

    private func refresh() {
        streakStore.sync(from: planStore.plan)
    }
}

// MARK: - Cellules stables

private struct ProcessStreakWeekDayCell: View {
    let day: ProcessStreakDaySnapshot

    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(spacing: 7) {
            Text(day.weekdaySymbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(day.isToday ? theme.primaryText : theme.secondaryText)

            ZStack {
                Circle()
                    .fill(cellFill)

                if day.isComplete {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(day.dayOfMonth)")
                        .font(.system(size: 12, weight: day.isToday ? .bold : .semibold))
                        .foregroundStyle(day.isFuture ? theme.secondaryText.opacity(0.45) : theme.secondaryText)
                        .monospacedDigit()
                }
            }
            .frame(width: 34, height: 34)
            .overlay {
                if day.isToday {
                    Circle()
                        .strokeBorder(theme.onboardingAccent, lineWidth: 1.5)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(day.accessibilityLabel)
    }

    private var cellFill: Color {
        if day.isComplete {
            return ProcessStreakPalette.flame
        }
        return theme.primaryText.opacity(theme.isDark ? 0.09 : 0.06)
    }
}

private struct ProcessStreakHistoryDayCell: View {
    let day: ProcessStreakDaySnapshot

    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(spacing: 4) {
            Text(day.weekdaySymbol)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(theme.secondaryText.opacity(0.72))

            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        day.isComplete
                            ? ProcessStreakPalette.flame
                            : theme.primaryText.opacity(theme.isDark ? 0.08 : 0.05)
                    )

                if day.isComplete {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(day.dayOfMonth)")
                        .font(.system(size: 10, weight: day.isToday ? .bold : .medium))
                        .foregroundStyle(theme.secondaryText)
                        .monospacedDigit()
                }
            }
            .frame(height: 30)
            .overlay {
                if day.isToday {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(theme.onboardingAccent, lineWidth: 1.5)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(day.accessibilityLabel)
    }
}

private extension ProcessStreakDaySnapshot {
    var accessibilityLabel: String {
        var parts = [date.formatted(.dateTime.weekday(.wide).day().month(.wide))]
        if isToday { parts.append("aujourd’hui") }
        if isComplete { parts.append("journée validée") }
        if isFuture { parts.append("à venir") }
        return parts.joined(separator: ", ")
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
