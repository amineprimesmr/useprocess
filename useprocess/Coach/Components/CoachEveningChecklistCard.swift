import SwiftUI

struct CoachEveningChecklistCard: View {
    @Bindable private var streakStore = ProcessStreakStore.shared
    @Bindable private var eveningStore = ProcessEveningCheckInStore.shared
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.onboardingAccent)
                Text(AppCopy.t("Bilan du soir", en: "Evening check-in"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.primaryText)
                Spacer(minLength: 0)
                if eveningStore.hasSubmittedToday {
                    Label(AppCopy.t("Fait", en: "Done"), systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(red: 0.35, green: 0.78, blue: 0.45))
                }
            }

            Text(statusLine)
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                HapticManager.shared.impact(.medium)
                CoachPlanNavigationBridge.shared.openEveningCheckIn()
            } label: {
                Text(
                    eveningStore.hasSubmittedToday
                        ? AppCopy.t("Voir mon bilan", en: "View my check-in")
                        : AppCopy.t("Ouvrir le bilan du soir", en: "Open evening check-in")
                )
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            }
            .processGlassButton(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(14)
        .background(cardBackground)
    }

    private var statusLine: String {
        if eveningStore.hasSubmittedToday {
            return AppCopy.t(
                "Série \(streakStore.displayStreak) jour\(streakStore.displayStreak > 1 ? "s" : "") — tu peux modifier tes réponses sur l’accueil.",
                en: "\(streakStore.displayStreak)-day streak — you can update your answers on Home."
            )
        }
        return ProcessEveningCheckInSchedule.streakLaunchMessage()
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(theme.isDark ? Color(red: 0.11, green: 0.11, blue: 0.12) : theme.cardBackgroundStrong)
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(theme.cardStroke.opacity(0.45), lineWidth: 0.5)
            }
    }
}
