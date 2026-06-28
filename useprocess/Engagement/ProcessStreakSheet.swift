import SwiftUI

/// Page streak — header + bande jours 3D + stats + guide debloat / habitudes.
struct ProcessStreakSheet: View {
    @Binding var selectedDate: Date

    @Bindable private var streakStore = ProcessStreakStore.shared
    @Bindable private var planStore = WelcomePlanStore.shared

    @EnvironmentObject private var profileService: UnifiedProfileService
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    private var snapshot: ProcessStreakSnapshot { streakStore.snapshot }

    private var firstName: String {
        profileService.currentProfile?.firstName
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ProcessScreenBackground()
                ProcessStreakDotGrid()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        streakHero
                        protocolDayStripSection
                        todayProgressCard
                        monthGridSection
                        statsSection
                        if let next = snapshot.nextMilestone, let remaining = snapshot.daysUntilNextMilestone {
                            insightsPill(remaining: remaining, milestone: next)
                        }
                        guideSection
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 48)
                }
                .scrollClipDisabled(false)
            }
            .navigationTitle("Streak")
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
                planStore.reloadForCurrentUser()
                streakStore.sync(from: planStore.plan)
            }
        }
        .processClearUIKitHostingBackground()
        .onAppear {
            streakStore.sync(from: planStore.plan)
        }
        .onChange(of: planStore.plan?.lastUpdated) { _, _ in
            streakStore.sync(from: planStore.plan)
        }
    }

    // MARK: - Hero

    private var streakHero: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .strokeBorder(Color.primary.opacity(theme.isDark ? 0.14 : 0.10), lineWidth: 1.5)
                    .frame(width: 196, height: 196)

                VStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 46, weight: .semibold))
                        .foregroundStyle(ProcessStreakPalette.flameGradient)
                        .shadow(color: ProcessStreakPalette.flame.opacity(0.28), radius: 10, y: 5)

                    Text("\(snapshot.currentStreak)")
                        .font(.system(size: 58, weight: .bold))
                        .foregroundStyle(theme.primaryText)
                        .monospacedDigit()
                }
            }
            .padding(.top, 4)

            Text(snapshot.streakTitle)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(theme.primaryText)

            Text(snapshot.encouragement(firstName: firstName))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(theme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Bande protocole (relief 3D)

    @ViewBuilder
    private var protocolDayStripSection: some View {
        if let plan = planStore.plan {
            VStack(alignment: .leading, spacing: 10) {
                Text("Ton protocole")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.primaryText)

                JournalWeekDayStrip(selectedDate: $selectedDate, plan: plan)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Aujourd’hui

    private var todayProgressCard: some View {
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

    // MARK: - Grille 28 jours (3D)

    private var monthGridSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("28 derniers jours")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.primaryText)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7),
                spacing: 8
            ) {
                ForEach(snapshot.month) { day in
                    ProcessStreakMonthDayCell(
                        day: day,
                        selectedDate: $selectedDate
                    )
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(streakCardBackground)
    }

    // MARK: - Stats

    private var statsSection: some View {
        VStack(spacing: 10) {
            Text("TES STATS")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(theme.secondaryText.opacity(0.75))
                .tracking(0.6)

            HStack(spacing: 0) {
                statsColumn(title: "Jours", value: "\(snapshot.totalCompletedDays)")
                statsDivider
                statsColumn(title: "Série", value: "\(snapshot.currentStreak)")
                statsDivider
                statsColumn(title: "Record", value: "\(snapshot.longestStreak)")
                statsDivider
                statsColumn(
                    title: "Aujourd’hui",
                    value: snapshot.isTodayComplete ? "100 %" : "\(Int(snapshot.todayProgress * 100)) %"
                )
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(theme.isDark ? theme.cardBackgroundStrong : Color.white)
            )
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(theme.primaryText.opacity(theme.isDark ? 0.08 : 0.05))
        )
    }

    private var statsDivider: some View {
        Rectangle()
            .fill(theme.cardStroke.opacity(0.55))
            .frame(width: 1, height: 36)
    }

    private func statsColumn(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(theme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(theme.primaryText)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
    }

    private func insightsPill(remaining: Int, milestone: ProcessStreakMilestone) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.onboardingAccent)
            Text("Plus que \(remaining) jour\(remaining > 1 ? "s" : "") avant \(milestone.title.lowercased())")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.onboardingAccent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(theme.onboardingAccent.opacity(theme.isDark ? 0.14 : 0.10))
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(theme.onboardingAccent.opacity(0.35), lineWidth: 0.5)
                }
        )
    }

    // MARK: - Guide debloat + habitudes

    private var guideSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Guide debloat & habitudes")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(theme.primaryText)
                Text("Nutrition, sommeil, posture et routines 24/7 — tout sur une page.")
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HealthDebloatGuideView(showsOuterCard: false)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

// MARK: - Cellule jour (grille 28j, relief 3D)

private struct ProcessStreakMonthDayCell: View {
    let day: ProcessStreakDaySnapshot
    @Binding var selectedDate: Date

    @Environment(\.appTheme) private var theme

    private var isSelected: Bool {
        Calendar.current.isDate(day.date, inSameDayAs: selectedDate)
    }

    var body: some View {
        Button {
            guard !day.isFuture else { return }
            HapticManager.shared.impact(.light)
            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                selectedDate = day.date
            }
        } label: {
            ZStack {
                JournalDayTileBackground(
                    cornerRadius: 9,
                    isDark: theme.isDark,
                    isSelected: isSelected,
                    accent: theme.onboardingAccent
                )

                if day.isComplete {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(ProcessStreakPalette.flame.opacity(day.isToday ? 1 : 0.88))
                }

                if day.isComplete {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                } else if !day.isFuture {
                    Text("\(day.dayOfMonth)")
                        .font(.system(size: 12, weight: day.isToday ? .bold : .semibold))
                        .foregroundStyle(isSelected ? theme.primaryText : theme.secondaryText.opacity(0.9))
                        .monospacedDigit()
                }
            }
            .frame(height: 34)
            .scaleEffect(isSelected ? 1.04 : 1, anchor: .center)
            .animation(.spring(response: 0.32, dampingFraction: 0.78), value: isSelected)
        }
        .buttonStyle(JournalDayCellButtonStyle())
        .disabled(day.isFuture)
        .opacity(day.isFuture ? 0.45 : 1)
        .accessibilityLabel(monthDayAccessibilityLabel)
    }

    private var monthDayAccessibilityLabel: String {
        var parts = [day.date.formatted(.dateTime.day().month(.wide))]
        if day.isToday { parts.append("aujourd’hui") }
        if day.isComplete { parts.append("streak complétée") }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Fond points

private struct ProcessStreakDotGrid: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 14
            let dotSize: CGFloat = 1.6
            let color = Color.primary.opacity(0.06)

            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    let dotRect = CGRect(x: x, y: y, width: dotSize, height: dotSize)
                    context.fill(Path(ellipseIn: dotRect), with: .color(color))
                    x += step
                }
                y += step
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
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
