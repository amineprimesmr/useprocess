import SwiftUI
import UIKit
import UserNotifications

/// Hub Paramètres — fond noir, cartes fines, header glass transparent.
struct EditProfileView: View {
    var showsDismissHeader: Bool = true

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var profileService: UnifiedProfileService
    @EnvironmentObject private var healthManager: HealthManager

    @State private var profileStore = SocialProfileStore.shared
    @State private var notificationsEnabled = false
    @State private var showsSupportChat = false
    @State private var inAppSafariURL: URL?
    @State private var toolbarSubtitle: String?
    @State private var activeSectionIndex: Int?
    @State private var scrollEffectsActive = false
    @Bindable private var appLanguage = ProcessAppLanguage.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                accountEntryCard
                personalizeSection
                assistanceSection
                permissionsSection
                programsSection
                followSection
                ProcessSettingsOpalVersionFooter()
            }
            .padding(.bottom, ProcessIGTabMetrics.tabBarOverlayClearance + 16)
        }
        .scrollIndicators(.hidden)
        .processAdoptForIGTabBar()
        .processSettingsScrollToolBar(
            title: toolbarSubtitle,
            subtitle: nil,
            showsBackButton: showsDismissHeader,
            onBack: { dismiss() }
        )
        .processSettingsOpalPage()
        .navigationBarBackButtonHidden(showsDismissHeader)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadProfileIfNeeded()
            await refreshNotificationStatus()
            FaceScanHistoryStore.shared.reloadForUser(userId: profileService.currentProfile?.userId)
            try? await Task.sleep(for: .seconds(0.01))
            scrollEffectsActive = true
        }
        .onChange(of: activeSectionIndex) { _, newValue in
            toolbarSubtitle = newValue.flatMap { settingsSectionTitle(for: $0) }
        }
        .onAppear {
            profileStore.bind(unified: profileService.currentProfile)
            ProcessCreatorModeStore.shared.syncFromCurrentProfile()
        }
        .sheet(isPresented: Binding(
            get: { inAppSafariURL != nil },
            set: { if !$0 { inAppSafariURL = nil } }
        )) {
            if let url = inAppSafariURL {
                ProfileSettingsSafariView(url: url)
                    .ignoresSafeArea()
            }
        }
        .fullScreenCover(isPresented: $showsSupportChat) {
            ProcessSupportChatView()
        }
    }

    // MARK: - Mon compte

    private var accountEntryCard: some View {
        ProcessSettingsOpalCard {
            NavigationLink(value: ProfileSettingsCategory.account) {
                ProcessSettingsOpalRow(title: AppCopy.t("Mon compte", en: "My Account")) {
                    ProcessSettingsLatestScanAvatar(
                        size: 26,
                        initials: accountInitials
                    )
                }
            }
            .processSettingsOpalRowButton()
        }
        .padding(.horizontal, ProcessSettingsOpalTheme.horizontalPadding)
        .padding(.top, showsDismissHeader ? 24 : 12)
    }

    private var accountInitials: String {
        String((profileService.currentProfile?.firstName ?? "?").prefix(1))
    }

    // MARK: - Personnaliser

    private var personalizeSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProcessSettingsScrollSectionReporter(
                title: AppCopy.t("Personnaliser", en: "Personalize"),
                index: 0,
                effectsActive: scrollEffectsActive,
                activeIndex: $activeSectionIndex
            )

            ProcessSettingsOpalCard {
                NavigationLink(value: ProfileSettingsCategory.app) {
                    ProcessSettingsOpalRow(
                        icon: "paintbrush.fill",
                        title: AppCopy.t("Apparence", en: "Appearance")
                    )
                }
                .processSettingsOpalRowButton()

                ProcessSettingsOpalRowDivider()

                NavigationLink(value: ProfileSettingsCategory.language) {
                    ProcessSettingsOpalRow(
                        icon: "globe.americas.fill",
                        title: AppCopy.t("Langue", en: "Language"),
                        trailingIcon: .status("\(appLanguage.code.flag) \(appLanguage.code.displayName)")
                    )
                }
                .processSettingsOpalRowButton()
            }
            .padding(.horizontal, ProcessSettingsOpalTheme.horizontalPadding)
        }
        .onAppear { syncLanguageFromProfileIfNeeded() }
    }

    private func syncLanguageFromProfileIfNeeded() {
        guard let profileLang = profileService.currentProfile?.preferences.language else { return }
        let normalized = ProcessAppLanguage.normalize(profileLang)
        if normalized != appLanguage.code {
            appLanguage.setLanguage(normalized)
        }
    }

    // MARK: - Assistance

    private var assistanceSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProcessSettingsScrollSectionReporter(
                title: AppCopy.t("Assistance", en: "Support"),
                index: 1,
                effectsActive: scrollEffectsActive,
                activeIndex: $activeSectionIndex
            )

            ProcessSettingsOpalCard {
                Button { openSupportChat() } label: {
                    ProcessSettingsOpalRow(
                        icon: "bubble.left.and.bubble.right.fill",
                        title: AppCopy.t("Discuter avec l'assistance", en: "Chat with Support")
                    )
                }
                .processSettingsOpalRowButton()

                ProcessSettingsOpalRowDivider()

                Button { inAppSafariURL = ProcessLegalURLs.supportPage } label: {
                    ProcessSettingsOpalRow(
                        icon: "book.fill",
                        title: AppCopy.t("Centre d'aide", en: "Help Center")
                    )
                }
                .processSettingsOpalRowButton()

                ProcessSettingsOpalRowDivider()

                Button { openURL(ProcessAppStoreReviewPrompt.writeReviewURL) } label: {
                    ProcessSettingsOpalRow(
                        icon: "star.fill",
                        title: AppCopy.t("Noter Process", en: "Rate Process")
                    )
                }
                .processSettingsOpalRowButton()

                ProcessSettingsOpalRowDivider()

                NavigationLink(value: ProfileSettingsCategory.legal) {
                    ProcessSettingsOpalRow(
                        icon: "lifepreserver.fill",
                        title: AppCopy.t("Aide & confidentialité", en: "Help & Privacy")
                    )
                }
                .processSettingsOpalRowButton()
            }
            .padding(.horizontal, ProcessSettingsOpalTheme.horizontalPadding)
        }
    }

    // MARK: - Autorisations

    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProcessSettingsScrollSectionReporter(
                title: AppCopy.t("Autorisations", en: "Permissions"),
                index: 2,
                effectsActive: scrollEffectsActive,
                activeIndex: $activeSectionIndex
            )

            ProcessSettingsOpalCard {
                NavigationLink(value: ProfileSettingsCategory.health) {
                    ProcessSettingsOpalRow(
                        icon: "heart.text.square.fill",
                        title: AppCopy.t("Apple Santé", en: "Apple Health"),
                        trailingIcon: .status(healthStatusLabel)
                    )
                }
                .processSettingsOpalRowButton()

                ProcessSettingsOpalRowDivider()

                Button {
                    Task { await openNotificationSettings() }
                } label: {
                    ProcessSettingsOpalRow(
                        icon: "bell.fill",
                        title: AppCopy.t("Notifications", en: "Notifications"),
                        trailingIcon: .status(notificationsStatusLabel)
                    )
                }
                .processSettingsOpalRowButton()
            }
            .padding(.horizontal, ProcessSettingsOpalTheme.horizontalPadding)
        }
    }

    // MARK: - Programmes

    @ViewBuilder
    private var programsSection: some View {
        let showsStudio = ProcessCreatorModeStore.shared.showsStudioEntry

        VStack(alignment: .leading, spacing: 0) {
            ProcessSettingsScrollSectionReporter(
                title: AppCopy.t("Programmes", en: "Programs"),
                index: 3,
                effectsActive: scrollEffectsActive,
                activeIndex: $activeSectionIndex
            )

            ProcessSettingsOpalCard {
                NavigationLink(value: ProfileSettingsCategory.referral) {
                    ProcessSettingsOpalRow(
                        icon: "gift.fill",
                        title: AppCopy.t("Parrainage", en: "Refer friends")
                    )
                }
                .processSettingsOpalRowButton()

                ProcessSettingsOpalRowDivider()

                Button {
                    inAppSafariURL = ProcessAffiliatePortalLink.urlForCurrentUser()
                } label: {
                    ProcessSettingsOpalRow(
                        icon: "sparkles",
                        title: AppCopy.t("Programme créateurs", en: "Creator Program")
                    )
                }
                .processSettingsOpalRowButton()

                if showsStudio {
                    ProcessSettingsOpalRowDivider()

                    NavigationLink(value: ProfileSettingsCategory.studio) {
                        ProcessSettingsOpalRow(
                            icon: "video.fill",
                            title: AppCopy.t("Studio contenu", en: "Content Studio")
                        )
                    }
                    .processSettingsOpalRowButton()
                }
            }
            .padding(.horizontal, ProcessSettingsOpalTheme.horizontalPadding)
        }
    }

    // MARK: - Suis-nous

    private var followSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProcessSettingsScrollSectionReporter(
                title: AppCopy.t("Suis-nous", en: "Follow Us"),
                index: 4,
                effectsActive: scrollEffectsActive,
                activeIndex: $activeSectionIndex
            )

            ProcessSettingsOpalCard {
                shareRow(title: AppCopy.t("Partager Process", en: "Share Process"))
                ProcessSettingsOpalRowDivider()
                externalLinkRow(title: "TikTok", url: ProcessLegalURLs.tiktok)
                ProcessSettingsOpalRowDivider()
                externalLinkRow(title: "Instagram", url: ProcessLegalURLs.instagram)
            }
            .padding(.horizontal, ProcessSettingsOpalTheme.horizontalPadding)
        }
    }

    // MARK: - Helpers

    private func settingsSectionTitle(for index: Int) -> String? {
        switch index {
        case 0: return AppCopy.t("Personnaliser", en: "Personalize")
        case 1: return AppCopy.t("Assistance", en: "Support")
        case 2: return AppCopy.t("Autorisations", en: "Permissions")
        case 3: return AppCopy.t("Programmes", en: "Programs")
        case 4: return AppCopy.t("Suis-nous", en: "Follow Us")
        default: return nil
        }
    }

    private func shareRow(title: String) -> some View {
        Button {
            shareProcessApp()
        } label: {
            ProcessSettingsOpalRow(title: title)
        }
        .processSettingsOpalRowButton()
    }

    private func externalLinkRow(title: String, url: URL) -> some View {
        Button { openURL(url) } label: {
            ProcessSettingsOpalRow(title: title, trailingIcon: .external)
        }
        .processSettingsOpalRowButton()
    }

    private var notificationsStatusLabel: String {
        notificationsEnabled
            ? AppCopy.t("Activées", en: "Enabled")
            : AppCopy.t("Désactivées", en: "Disabled")
    }

    private var healthStatusLabel: String {
        healthManager.isAuthorized
            ? AppCopy.t("Connecté", en: "Connected")
            : AppCopy.t("Connecter", en: "Connect")
    }

    private func loadProfileIfNeeded() async {
        if profileService.currentProfile == nil {
            await profileService.loadProfile()
        }
        profileStore.bind(unified: profileService.currentProfile)
    }

    private func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationsEnabled = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
    }

    private func openNotificationSettings() async {
        await refreshNotificationStatus()
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }

    private func openSupportChat() {
        ProcessAnalytics.trackSupportChatOpened(source: "settings_hub")
        if ProcessCrispSupport.isReady {
            showsSupportChat = true
        } else {
            openURL(ProcessLegalURLs.supportMail)
        }
    }

    private func shareProcessApp() {
        let text = AppCopy.t(
            "Découvre Process — debloat ton visage avec un plan sur mesure.",
            en: "Discover Process — debloat your face with a personalized plan."
        )
        let url = URL(string: "https://useprocess.xyz")!
        let activity = UIActivityViewController(activityItems: [text, url], applicationActivities: nil)
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }
        root.present(activity, animated: true)
    }
}
