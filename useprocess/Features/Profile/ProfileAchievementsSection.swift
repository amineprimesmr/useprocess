import SwiftUI

struct ProfileAchievementsSection: View {
    @Environment(\.appTheme) private var theme
    @Bindable private var streakStore = ProcessStreakStore.shared
    @Bindable private var planStore = WelcomePlanStore.shared

    private var snapshot: ProcessStreakSnapshot { streakStore.snapshot }

    private var unlockedAchievements: Int {
        ProcessStreakMilestone.catalog.filter {
            snapshot.longestStreak >= $0.days || snapshot.totalCompletedDays >= $0.days
        }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(AppCopy.t("Succès", en: "Achievements"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.primaryText)
                Spacer()
                Text("\(unlockedAchievements)/\(ProcessStreakMilestone.catalog.count)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.secondaryText)
                    .monospacedDigit()
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ],
                spacing: 10
            ) {
                ForEach(Array(ProcessStreakMilestone.catalog.enumerated()), id: \.element.id) { index, milestone in
                    achievementCard(milestone, index: index)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            streakStore.sync(from: planStore.plan)
        }
        .onChange(of: planStore.plan?.id) { _, _ in
            streakStore.sync(from: planStore.plan)
        }
    }

    private func achievementCard(_ milestone: ProcessStreakMilestone, index: Int) -> some View {
        let unlocked = snapshot.longestStreak >= milestone.days || snapshot.totalCompletedDays >= milestone.days
        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        unlocked
                            ? ProfileAchievementsDesign.accent.opacity(0.18)
                            : (theme.isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.04))
                    )
                    .frame(width: 40, height: 40)
                Image(systemName: achievementIcon(for: milestone.days))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(unlocked ? ProfileAchievementsDesign.accent : theme.secondaryText.opacity(0.4))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(milestone.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(unlocked ? theme.primaryText : theme.secondaryText.opacity(0.55))
                Text(milestone.subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.secondaryText.opacity(unlocked ? 0.85 : 0.45))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Image(systemName: unlocked ? "checkmark.circle.fill" : "lock.fill")
                .font(.system(size: unlocked ? 16 : 12))
                .foregroundStyle(unlocked ? ProfileAchievementsDesign.accent : theme.secondaryText.opacity(0.35))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: ProfileAchievementsDesign.cardRadius, style: .continuous)
                .fill(theme.isDark ? Color.white.opacity(0.06) : Color.white.opacity(0.72))
                .overlay {
                    RoundedRectangle(cornerRadius: ProfileAchievementsDesign.cardRadius, style: .continuous)
                        .strokeBorder(
                            unlocked
                                ? ProfileAchievementsDesign.accent.opacity(0.25)
                                : (theme.isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)),
                            lineWidth: 1
                        )
                }
        )
        .opacity(unlocked ? 1 : 0.72)
        .animation(.spring(response: 0.4, dampingFraction: 0.82).delay(Double(index) * 0.04), value: unlocked)
    }

    private func achievementIcon(for days: Int) -> String {
        switch days {
        case 3: return "sparkles"
        case 7: return "flame.fill"
        case 14: return "bolt.fill"
        case 30: return "star.fill"
        case 60: return "crown.fill"
        default: return "trophy.fill"
        }
    }
}

private enum ProfileAchievementsDesign {
    static var accent: Color { ProcessStreakPalette.flame }
    static let cardRadius: CGFloat = 16
}
