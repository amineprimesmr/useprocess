import SwiftUI

struct CoachIntelligenceCreditsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @Bindable private var store = CoachIntelligenceSettingsStore.shared
    @ObservedObject private var subscriptionService = SubscriptionService.shared

    @State private var showsPaywall = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    usageCard
                    creditsCard
                    explanation
                    actionButtons
                }
                .padding(16)
            }
            .processTransparentScrollSurface()
            .navigationTitle(AppCopy.t("Crédits coach", en: "Coach credits"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(theme.primaryText)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(theme.cardBackgroundStrong.opacity(0.95)))
                    }
                }
            }
            .sheet(isPresented: $showsPaywall) {
                PaywallView(onComplete: {
                    showsPaywall = false
                    store.syncSubscriberCreditsIfNeeded()
                })
            }
            .onAppear {
                store.syncSubscriberCreditsIfNeeded()
            }
        }
        .processAppPageBackground()
    }

    private var usageCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(AppCopy.t("Limite hebdomadaire", en: "Weekly limit"))
                .font(.headline.weight(.semibold))
            Text(store.weeklyUsageLabel)
                .font(.title3.weight(.bold))
            Text(store.weeklyResetLabel)
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(cardBackground)
    }

    private var creditsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppCopy.t("Crédits supplémentaires", en: "Extra credits"))
                .font(.headline.weight(.semibold))
            Text("\(store.extraCredits)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
            Text(AppCopy.t("Utilisés uniquement après la limite hebdomadaire.", en: "Used only after your weekly limit."))
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(cardBackground)
    }

    private var explanation: some View {
        Text(subscriptionService.subscriptionStatus.isActive
             ? AppCopy.t("Abonné PRO : tu reçois 50 crédits bonus à chaque reset hebdomadaire.", en: "PRO subscriber: you receive 50 bonus credits at each weekly reset.")
             : AppCopy.t("Passe PRO pour recevoir 50 crédits bonus par semaine en plus de ta limite.", en: "Go PRO to receive 50 bonus credits per week in addition to your limit."))
            .font(.subheadline)
            .foregroundStyle(theme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            if !subscriptionService.subscriptionStatus.isActive {
                Button {
                    showsPaywall = true
                } label: {
                    Text(AppCopy.t("Passer PRO", en: "Go PRO"))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(theme.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .processGlassButton(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            #if DEBUG
            Button(AppCopy.t("Ajouter 10 crédits (debug)", en: "Add 10 credits (debug)")) {
                store.grantDebugCredits(10)
            }
            .font(.caption)
            .foregroundStyle(theme.secondaryText)
            #endif
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(theme.cardBackgroundStrong.opacity(theme.isDark ? 0.92 : 0.98))
    }
}
