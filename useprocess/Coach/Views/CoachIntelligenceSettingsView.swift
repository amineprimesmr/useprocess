import SwiftUI

struct CoachIntelligenceSettingsView: View {
    var onDeleteAllConversations: () async -> Void
    var onDeleteAllFiles: () -> Void
    var onResyncHistory: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @Bindable private var store = CoachIntelligenceSettingsStore.shared

    @State private var showsPersonalityPicker = false
    @State private var showsMyMemory = false
    @State private var showsCredits = false
    @State private var showsCheckIns = false
    @State private var showsDeleteConversationsConfirm = false
    @State private var showsDeleteFilesConfirm = false
    @State private var isResyncing = false

    private let cardShape = RoundedRectangle(cornerRadius: 16, style: .continuous)
    private let actionButtonShape = RoundedRectangle(cornerRadius: 16, style: .continuous)

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    heroCard
                    disclaimerText
                    usageSection
                    proactiveSection
                    personalizationSection
                    myMemorySection
                    dataSharingSection
                    footerNote
                    actionButtons
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .processTransparentScrollSurface()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Process Intelligence")
                        .font(.headline.weight(.semibold))
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(theme.primaryText)
                            .frame(width: 34, height: 34)
                            .background(
                                Circle()
                                    .fill(theme.cardBackgroundStrong.opacity(theme.isDark ? 0.95 : 0.82))
                            )
                    }
                    .accessibilityLabel("Fermer")
                }
            }
            .confirmationDialog(
                "Supprimer toutes les conversations ?",
                isPresented: $showsDeleteConversationsConfirm,
                titleVisibility: .visible
            ) {
                Button("Supprimer toutes les conversations", role: .destructive) {
                    Task { await onDeleteAllConversations() }
                }
                Button("Annuler", role: .cancel) {}
            }
            .confirmationDialog(
                "Supprimer tous les fichiers ?",
                isPresented: $showsDeleteFilesConfirm,
                titleVisibility: .visible
            ) {
                Button("Supprimer tous les fichiers", role: .destructive) {
                    onDeleteAllFiles()
                }
                Button("Annuler", role: .cancel) {}
            }
            .sheet(isPresented: $showsPersonalityPicker) {
                personalityPickerSheet
            }
            .sheet(isPresented: $showsMyMemory) {
                CoachMyMemoryView()
            }
            .sheet(isPresented: $showsCredits) {
                CoachIntelligenceCreditsView()
            }
            .sheet(isPresented: $showsCheckIns) {
                CoachCheckInsManageView()
            }
            .onChange(of: store.isEnabled) { _, _ in
                Task {
                    await CoachCheckInScheduler.rescheduleAll()
                    await CoachDailyRhythmService.reschedule()
                }
            }
        }
        .processAppPageBackground()
    }

    // MARK: - Hero

    private var heroCard: some View {
        VStack(spacing: 16) {
            intelligenceIcon
                .padding(.top, 8)

            VStack(spacing: 8) {
                Text("Process Intelligence")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(theme.primaryText)

                Text("Un guide intelligent intégré dans vos activités, vos tendances et vos objectifs quotidiens.")
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 0) {
                settingsToggleRow(
                    title: "Process Intelligence",
                    subtitle: nil,
                    isOn: $store.isEnabled
                )

                settingsDivider

                Button {
                    showsPersonalityPicker = true
                } label: {
                    HStack {
                        Text("Personnalité")
                            .font(.body)
                            .foregroundStyle(theme.primaryText)
                        Spacer()
                        Text(store.personality.label)
                            .font(.body)
                            .foregroundStyle(theme.secondaryText)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(theme.secondaryText.opacity(0.7))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 4)
        .background(cardBackground)
    }

    private var intelligenceIcon: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            OnboardingProfileChatDepthStyle.chatAccentViolet.opacity(0.45),
                            OnboardingProfileChatDepthStyle.chatAccentViolet.opacity(0.12),
                            .clear
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: 46
                    )
                )
                .frame(width: 88, height: 88)

            Image("caochiaicon")
                .resizable()
                .scaledToFit()
                .frame(width: 58, height: 58)
                .shadow(color: OnboardingProfileChatDepthStyle.chatAccentViolet.opacity(0.2), radius: 14, x: 0, y: 0)
                .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 4)
        }
    }

    private var disclaimerText: some View {
        Text("Process n'est pas un dispositif médical et ne doit pas être utilisé pour diagnostiquer ou traiter une condition médicale. Consultez toujours un professionnel de santé qualifié.")
            .font(.caption)
            .foregroundStyle(theme.secondaryText.opacity(0.88))
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Sections

    private var usageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Utilisation")

            VStack(spacing: 0) {
                usageMetricRow(
                    title: "Limites hebdomadaires",
                    value: store.weeklyUsageLabel,
                    progress: Double(store.weeklyUsagePercent) / 100
                )

                Text(store.weeklyResetLabel)
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)

                settingsDivider

                usageMetricRow(
                    title: "Crédits supplémentaires",
                    value: store.creditsLabel,
                    progress: store.extraCredits > 0 ? 0.35 : 0
                )

                settingsDivider

                Button {
                    showsCredits = true
                } label: {
                    HStack {
                        Text("Gérer les crédits")
                            .font(.body)
                            .foregroundStyle(theme.primaryText)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(theme.secondaryText.opacity(0.7))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
            }
            .background(cardBackground)
        }
    }

    private var proactiveSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Rythme proactif")

            VStack(spacing: 0) {
                settingsToggleRow(
                    title: "Check-ins programmés",
                    subtitle: "Rappels personnalisés pour ouvrir le coach aux moments clés.",
                    isOn: Binding(
                        get: { CoachCheckInStore.shared.proactiveCheckInsEnabled },
                        set: { CoachCheckInStore.shared.proactiveCheckInsEnabled = $0 }
                    )
                )

                settingsDivider

                settingsToggleRow(
                    title: "Brief matin",
                    subtitle: "Notification quotidienne avec readiness et action prioritaire.",
                    isOn: Binding(
                        get: { CoachDailyRhythmService.morningOutlookEnabled },
                        set: { CoachDailyRhythmService.morningOutlookEnabled = $0 }
                    )
                )

                settingsDivider

                settingsToggleRow(
                    title: "Bilan du soir",
                    subtitle: "Rappel streak et journal avant le coucher.",
                    isOn: Binding(
                        get: { CoachDailyRhythmService.eveningReviewEnabled },
                        set: { CoachDailyRhythmService.eveningReviewEnabled = $0 }
                    )
                )

                settingsDivider

                Button {
                    showsCheckIns = true
                } label: {
                    HStack {
                        Text("Gérer les check-ins")
                            .font(.body)
                            .foregroundStyle(theme.primaryText)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(theme.secondaryText.opacity(0.7))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
            }
            .background(cardBackground)
        }
    }

    private var myMemorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Ma mémoire")

            Button {
                showsMyMemory = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Gérer Ma mémoire")
                            .font(.body)
                            .foregroundStyle(theme.primaryText)
                        Text("Objectifs, contraintes, préférences — comme WHOOP My Memory.")
                            .font(.subheadline)
                            .foregroundStyle(theme.secondaryText)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.secondaryText.opacity(0.7))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            .background(cardBackground)
        }
    }

    private var personalizationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Personnalisation")

            VStack(spacing: 0) {
                settingsToggleRow(
                    title: "Étapes de réflexion étendues",
                    subtitle: "Afficher les étapes de raisonnement pour chaque réponse par défaut.",
                    isOn: $store.showsExtendedReasoning
                )

                settingsDivider

                settingsToggleRow(
                    title: "Suivis suggérés",
                    subtitle: "Afficher les questions de suivi rapide après chaque réponse.",
                    isOn: $store.showsSuggestedFollowUps
                )
            }
            .background(cardBackground)
        }
    }

    private var dataSharingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Partage des données")

            VStack(spacing: 0) {
                settingsToggleRow(
                    title: "Santé reproductive",
                    subtitle: "Autorisez l'accès aux données sur la santé reproductive dans le journal et le suivi du cycle.",
                    isOn: $store.sharesReproductiveHealth
                )
            }
            .background(cardBackground)
        }
    }

    private var footerNote: some View {
        Text("Les crédits supplémentaires ne sont utilisés qu'une fois que votre limite hebdomadaire est atteinte.")
            .font(.caption)
            .foregroundStyle(theme.secondaryText.opacity(0.88))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            actionButton(title: isResyncing ? "Synchronisation…" : "Re-synchroniser l'historique des conversations") {
                guard !isResyncing else { return }
                isResyncing = true
                Task {
                    await onResyncHistory()
                    isResyncing = false
                }
            }

            actionButton(title: "Supprimer toutes les conversations", destructive: true) {
                showsDeleteConversationsConfirm = true
            }

            actionButton(title: "Supprimer tous les fichiers", destructive: true) {
                showsDeleteFilesConfirm = true
            }
        }
    }

    // MARK: - Components

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline.weight(.semibold))
            .foregroundStyle(theme.primaryText)
            .padding(.leading, 4)
    }

    private var cardBackground: some View {
        cardShape
            .fill(theme.cardBackgroundStrong.opacity(theme.isDark ? 0.92 : 0.98))
            .overlay(
                cardShape.stroke(theme.secondaryText.opacity(0.12), lineWidth: 0.5)
            )
    }

    private var settingsDivider: some View {
        Rectangle()
            .fill(theme.secondaryText.opacity(0.14))
            .frame(height: 0.5)
            .padding(.leading, 16)
    }

    private func settingsToggleRow(title: String, subtitle: String?, isOn: Binding<Bool>) -> some View {
        HStack(alignment: subtitle == nil ? .center : .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(theme.primaryText)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Color.green)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func usageMetricRow(title: String, value: String, progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.body)
                    .foregroundStyle(theme.primaryText)
                Spacer()
                Text(value)
                    .font(.body)
                    .foregroundStyle(theme.secondaryText)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(theme.secondaryText.opacity(0.18))
                    Capsule()
                        .fill(theme.primaryText.opacity(0.55))
                        .frame(width: max(0, geo.size.width * min(1, progress)))
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }

    private func actionButton(title: String, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.medium))
                .foregroundStyle(destructive ? Color.orange : theme.primaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .contentShape(actionButtonShape)
        }
        .processGlassButton(in: actionButtonShape)
    }

    private var personalityPickerSheet: some View {
        NavigationStack {
            List {
                ForEach(CoachIntelligencePersonality.allCases) { option in
                    Button {
                        store.personality = option
                        showsPersonalityPicker = false
                    } label: {
                        HStack {
                            Text(option.label)
                                .foregroundStyle(theme.primaryText)
                            Spacer()
                            if store.personality == option {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.green)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Personnalité")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { showsPersonalityPicker = false }
                }
            }
        }
        .processAppPageBackground()
        .processAppPresentationBackground()
        .presentationDetents([.medium])
    }
}
