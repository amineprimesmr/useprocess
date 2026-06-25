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
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Crédits coach")
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
    }

    private var usageCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Limite hebdomadaire")
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
            Text("Crédits supplémentaires")
                .font(.headline.weight(.semibold))
            Text("\(store.extraCredits)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
            Text("Utilisés uniquement après la limite hebdomadaire.")
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(cardBackground)
    }

    private var explanation: some View {
        Text(subscriptionService.subscriptionStatus.isActive
             ? "Abonné PRO : tu reçois 50 crédits bonus à chaque reset hebdomadaire."
             : "Passe PRO pour recevoir 50 crédits bonus par semaine en plus de ta limite.")
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
                    Text("Passer PRO")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(theme.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .processGlassButton(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            #if DEBUG
            Button("Ajouter 10 crédits (debug)") {
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
