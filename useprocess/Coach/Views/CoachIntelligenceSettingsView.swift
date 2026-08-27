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
                    Text(AppCopy.t("Intelligence Process", en: "Process Intelligence"))
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
                    .accessibilityLabel(AppCopy.close)
                }
            }
            .confirmationDialog(
                AppCopy.t("Supprimer toutes les conversations ?", en: "Delete all conversations?"),
                isPresented: $showsDeleteConversationsConfirm,
                titleVisibility: .visible
            ) {
                Button(AppCopy.t("Supprimer toutes les conversations", en: "Delete all conversations"), role: .destructive) {
                    Task { await onDeleteAllConversations() }
                }
                Button(AppCopy.cancel, role: .cancel) {}
            }
            .confirmationDialog(
                AppCopy.t("Supprimer tous les fichiers ?", en: "Delete all files?"),
                isPresented: $showsDeleteFilesConfirm,
                titleVisibility: .visible
            ) {
                Button(AppCopy.t("Supprimer tous les fichiers", en: "Delete all files"), role: .destructive) {
                    onDeleteAllFiles()
                }
                Button(AppCopy.cancel, role: .cancel) {}
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
            .onChange(of: store.isEnabled) { _, _ in
                Task {
                    await CoachDailyRhythmService.rescheduleAll()
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
                Text(AppCopy.t("Intelligence Process", en: "Process Intelligence"))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(theme.primaryText)

                Text(AppCopy.t("Un guide intelligent intégré dans vos activités, vos tendances et vos objectifs quotidiens.", en: "An intelligent guide integrated with your activity, trends, and daily goals."))
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 0) {
                settingsToggleRow(
                    title: AppCopy.t("Intelligence Process", en: "Process Intelligence"),
                    subtitle: nil,
                    isOn: $store.isEnabled
                )

                settingsDivider

                Button {
                    showsPersonalityPicker = true
                } label: {
                    HStack {
                        Text(AppCopy.t("Personnalité", en: "Personality"))
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
                .buttonStyle(.processPlain)
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
        Text(AppCopy.t("Process n'est pas un dispositif médical et ne doit pas être utilisé pour diagnostiquer ou traiter une condition médicale. Consultez toujours un professionnel de santé qualifié.", en: "Process is not a medical device and must not be used to diagnose or treat a medical condition. Always consult a qualified health professional."))
            .font(.caption)
            .foregroundStyle(theme.secondaryText.opacity(0.88))
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Sections

    private var usageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(AppCopy.t("Utilisation", en: "Usage"))

            VStack(spacing: 0) {
                usageMetricRow(
                    title: AppCopy.t("Limites hebdomadaires", en: "Weekly limit"),
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
                    title: AppCopy.t("Crédits supplémentaires", en: "Extra credits"),
                    value: store.creditsLabel,
                    progress: store.extraCredits > 0 ? 0.35 : 0
                )

                settingsDivider

                Button {
                    showsCredits = true
                } label: {
                    HStack {
                        Text(AppCopy.t("Gérer les crédits", en: "Manage credits"))
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
                .buttonStyle(.processPlain)
            }
            .background(cardBackground)
        }
    }

    private var proactiveSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(AppCopy.t("Notifications", en: "Notifications"))

            VStack(spacing: 0) {
                settingsToggleRow(
                    title: AppCopy.t("Brief matin", en: "Morning brief"),
                    subtitle: AppCopy.t("Une notification quotidienne : plan du jour, sommeil, scan si besoin.", en: "A daily notification: your plan, sleep, and a scan when needed."),
                    isOn: Binding(
                        get: { CoachDailyRhythmService.morningOutlookEnabled },
                        set: { CoachDailyRhythmService.morningOutlookEnabled = $0 }
                    )
                )
            }
            .background(cardBackground)
        }
    }

    private var myMemorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(AppCopy.t("Ma mémoire", en: "My memory"))

            Button {
                showsMyMemory = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(AppCopy.t("Gérer Ma mémoire", en: "Manage My Memory"))
                            .font(.body)
                            .foregroundStyle(theme.primaryText)
                        Text(AppCopy.t("Objectifs, contraintes, préférences — comme WHOOP My Memory.", en: "Goals, constraints, preferences — like WHOOP My Memory."))
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
            .buttonStyle(.processPlain)
            .background(cardBackground)
        }
    }

    private var personalizationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(AppCopy.t("Personnalisation", en: "Personalization"))

            VStack(spacing: 0) {
                settingsToggleRow(
                    title: AppCopy.t("Suivis suggérés", en: "Suggested follow-ups"),
                    subtitle: AppCopy.t("Afficher les questions de suivi rapide après chaque réponse.", en: "Show quick follow-up questions after each response."),
                    isOn: $store.showsSuggestedFollowUps
                )
            }
            .background(cardBackground)
        }
    }

    private var dataSharingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(AppCopy.t("Partage des données", en: "Data sharing"))

            VStack(spacing: 0) {
                settingsToggleRow(
                    title: AppCopy.t("Santé reproductive", en: "Reproductive health"),
                    subtitle: AppCopy.t("Autorisez l'accès aux données sur la santé reproductive dans le journal et le suivi du cycle.", en: "Allow reproductive-health data in your journal and cycle tracking."),
                    isOn: $store.sharesReproductiveHealth
                )
            }
            .background(cardBackground)
        }
    }

    private var footerNote: some View {
        Text(AppCopy.t("Les crédits supplémentaires ne sont utilisés qu'une fois que votre limite hebdomadaire est atteinte.", en: "Extra credits are only used after you reach your weekly limit."))
            .font(.caption)
            .foregroundStyle(theme.secondaryText.opacity(0.88))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            actionButton(title: isResyncing
                         ? AppCopy.t("Synchronisation…", en: "Syncing…")
                         : AppCopy.t("Re-synchroniser l'historique des conversations", en: "Resync conversation history")) {
                guard !isResyncing else { return }
                isResyncing = true
                Task {
                    await onResyncHistory()
                    isResyncing = false
                }
            }

            actionButton(title: AppCopy.t("Supprimer toutes les conversations", en: "Delete all conversations"), destructive: true) {
                showsDeleteConversationsConfirm = true
            }

            actionButton(title: AppCopy.t("Supprimer tous les fichiers", en: "Delete all files"), destructive: true) {
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
            .navigationTitle(AppCopy.t("Personnalité", en: "Personality"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppCopy.close) { showsPersonalityPicker = false }
                }
            }
        }
        .processAppPageBackground()
        .processAppPresentationBackground()
        .presentationDetents([.medium])
    }
}
