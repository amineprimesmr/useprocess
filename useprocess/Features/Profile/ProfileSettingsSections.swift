import SafariServices
import SwiftUI
import UIKit

// MARK: - Compte

struct ProfileSettingsAccountDetailView: View {
    @EnvironmentObject private var profileService: UnifiedProfileService
    @Environment(\.profileAccountDeletionHandler) private var onDeleteConfirmed
    @Bindable private var session = AppSession.shared

    @State private var showsLogoutConfirmation = false

    private var profile: UnifiedUserProfile? {
        profileService.currentProfile
    }

    private var ageText: String? {
        guard let profile, profile.age > 0 else { return nil }
        return profile.ageFormatted
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ProfileSummarySectionHeader(title: AppCopy.t("Identité", en: "Identity"))

                AccountDetailsCard {
                    NavigationLink(value: ProfileEditDestination.firstName) {
                        AccountDetailsGlassRow {
                            ProfileEditListRow(
                                label: AppCopy.t("Prénom", en: "First Name"),
                                value: profile?.firstName,
                                placeholder: AppCopy.t("Non renseigné", en: "Not provided"),
                                showsChevron: false
                            )
                        }
                    }
                    .buttonStyle(.processPlain)

                    NavigationLink(value: ProfileEditDestination.gender) {
                        AccountDetailsGlassRow {
                            ProfileEditListRow(
                                label: AppCopy.t("Sexe", en: "Gender"),
                                value: profile?.gender.displayName,
                                placeholder: AppCopy.t("Non renseigné", en: "Not provided")
                            )
                        }
                    }
                    .buttonStyle(.processPlain)

                    NavigationLink(value: ProfileEditDestination.birthDate) {
                        AccountDetailsGlassRow {
                            ProfileEditListRow(
                                label: AppCopy.t("Date de naissance", en: "Date of Birth"),
                                value: birthDateDisplay,
                                placeholder: AppCopy.t("Non renseigné", en: "Not provided")
                            )
                        }
                    }
                    .buttonStyle(.processPlain)

                    AccountDetailsGlassRow {
                        ProfileEditListRow(
                            label: AppCopy.t("Âge", en: "Age"),
                            value: ageText,
                            placeholder: "—",
                            showsChevron: false,
                            valueIsMuted: true
                        )
                    }
                }
                .padding(.horizontal, AccountDetailsTheme.horizontalPadding)

                ProfileSummarySectionHeader(title: AppCopy.t("Informations", en: "Information"))

                AccountDetailsCard {
                    if let profile = profile {
                        AccountDetailsGlassRow {
                            ProfileEditListRow(
                                label: "E-mail",
                                value: profile.email,
                                placeholder: AppCopy.t("Non renseigné", en: "Not provided"),
                                showsChevron: false,
                                valueIsMuted: true
                            )
                        }
                    }

                    if let score = BodyScanHistoryStore.shared.latestResult?.postureScore {
                        AccountDetailsGlassRow {
                            ProfileEditListRow(
                                label: AppCopy.t("Dernier scan", en: "Latest Scan"),
                                value: "\(score)/100",
                                placeholder: "—",
                                showsChevron: false,
                                valueIsMuted: true
                            )
                        }
                    }

                    AccountDetailsGlassRow {
                        ProfileEditListRow(
                            label: AppCopy.t("Appareil", en: "Device"),
                            value: deviceLine,
                            placeholder: "—",
                            showsChevron: false,
                            valueIsMuted: true
                        )
                    }
                }
                .padding(.horizontal, AccountDetailsTheme.horizontalPadding)

                AccountDetailsActionButton(title: AppCopy.t("Se déconnecter", en: "Log Out")) {
                    showsLogoutConfirmation = true
                }
                .padding(.horizontal, AccountDetailsTheme.horizontalPadding)
                .padding(.top, 28)

                AccountDeleteAnimatedButton(onConfirm: handleAccountDeletion)
                    .padding(.horizontal, AccountDetailsTheme.horizontalPadding)
                    .padding(.top, 12)
            }
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .processTransparentScrollSurface()
        .navigationTitle(AppCopy.t("Compte", en: "Account"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            AppCopy.t("Se déconnecter ?", en: "Log Out?"),
            isPresented: $showsLogoutConfirmation
        ) {
            Button(AppCopy.t("Se déconnecter", en: "Log Out"), role: .destructive) {
                AuthenticationManager.shared.signOut()
            }
            Button(AppCopy.cancel, role: .cancel) {}
        } message: {
            Text(AppCopy.t("Tu pourras te reconnecter à tout moment.", en: "You can log back in at any time."))
        }
    }

    private var birthDateDisplay: String? {
        guard let profile else { return nil }
        let formatter = DateFormatter()
        formatter.locale = ProcessAppLanguage.shared.locale
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: profile.birthDate)
    }

    private var deviceLine: String {
        "\(UIDevice.current.model) · iOS \(UIDevice.current.systemVersion)"
    }

    private func handleAccountDeletion() {
        if let onDeleteConfirmed {
            onDeleteConfirmed()
            return
        }

        Task { @MainActor in
            await session.performAccountDeletionFromUI()
        }
    }
}

// MARK: - Santé

struct ProfileSettingsHealthDetailView: View {
    @EnvironmentObject private var healthManager: HealthManager

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ProfileSummarySectionHeader(title: AppCopy.t("Santé & outils", en: "Health & Tools"))

                AccountDetailsCard {
                    NavigationLink {
                        BodyScanHistoryTabContent()
                            .processSettingsDetailPage()
                            .reportsProfileSubrouteActive(true)
                    } label: {
                        AccountDetailsGlassRow {
                            ProfileEditListRow(
                                label: AppCopy.t("Mes rapports de scan", en: "My Scan Reports"),
                                value: nil,
                                placeholder: AppCopy.t("Historique posture", en: "Posture history")
                            )
                        }
                    }
                    .buttonStyle(.processPlain)

                    AccountDetailsGlassRow {
                        Button {
                            Task {
                                if healthManager.isAuthorized {
                                    await healthManager.performFullSync()
                                } else {
                                    await healthManager.requestAuthorizationAsync(analyticsSource: "profile_settings")
                                }
                            }
                        } label: {
                            ProfileEditListRow(
                                label: healthManager.isAuthorized
                                    ? AppCopy.t("Synchroniser Santé", en: "Sync Health")
                                    : AppCopy.t("Connecter Apple Santé", en: "Connect Apple Health"),
                                value: healthManager.isAuthorized
                                    ? (healthManager.hasAppleWatch ? "Apple Watch" : AppCopy.t("App Santé", en: "Health app"))
                                    : nil,
                                placeholder: AppCopy.t("Autoriser l'accès", en: "Allow access")
                            )
                        }
                        .buttonStyle(.processPlain)
                    }

                    NavigationLink {
                        HealthConnectedSourcesSettingsView()
                            .environmentObject(healthManager)
                            .processSettingsDetailPage()
                            .reportsProfileSubrouteActive(true)
                    } label: {
                        AccountDetailsGlassRow {
                            ProfileEditListRow(
                                label: AppCopy.t("Sources connectées", en: "Connected Sources"),
                                value: healthManager.connectedSources.isEmpty
                                    ? nil
                                    : "\(healthManager.connectedSources.count)",
                                placeholder: AppCopy.t("Apps et appareils", en: "Apps and devices")
                            )
                        }
                    }
                    .buttonStyle(.processPlain)
                }
                .padding(.horizontal, AccountDetailsTheme.horizontalPadding)
            }
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .processTransparentScrollSurface()
        .navigationTitle(AppCopy.t("Santé & données", en: "Health & Data"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Application

struct ProfileSettingsAppDetailView: View {
    @EnvironmentObject private var profileService: UnifiedProfileService
    @Bindable private var session = AppSession.shared
    @Bindable private var appLanguage = ProcessAppLanguage.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ProfileSummarySectionHeader(title: AppCopy.t("Apparence", en: "Appearance"))

                AccountDetailsCard {
                    ForEach(Array(AppAppearance.allCases.enumerated()), id: \.element.id) { index, mode in
                        Group {
                            if index > 0 {
                                Color.clear.frame(height: AccountDetailsTheme.rowSpacing)
                            }
                            AccountDetailsGlassRow {
                                Button {
                                    session.setAppearance(mode)
                                } label: {
                                    ProfileEditListRow(
                                        label: mode.label,
                                        value: session.appearance == mode ? AppCopy.t("Actif", en: "Active") : nil,
                                        placeholder: "",
                                        showsChevron: false,
                                        valueIsMuted: session.appearance != mode
                                    )
                                }
                                .buttonStyle(.processPlain)
                            }
                        }
                    }
                }
                .padding(.horizontal, AccountDetailsTheme.horizontalPadding)

                ProfileSummarySectionHeader(title: AppCopy.t("Langue", en: "Language"))

                AccountDetailsCard {
                    ForEach(Array(ProcessAppLanguage.Code.allCases.enumerated()), id: \.element.id) { index, language in
                        Group {
                            if index > 0 {
                                Color.clear.frame(height: AccountDetailsTheme.rowSpacing)
                            }
                            AccountDetailsGlassRow {
                                Button {
                                    HapticManager.shared.selection()
                                    Task {
                                        await applyLanguage(language)
                                    }
                                } label: {
                                    ProfileEditListRow(
                                        label: "\(language.flag) \(language.displayName)",
                                        value: appLanguage.code == language ? AppCopy.t("Actif", en: "Active") : nil,
                                        placeholder: "",
                                        showsChevron: false,
                                        valueIsMuted: appLanguage.code != language
                                    )
                                }
                                .buttonStyle(.processPlain)
                            }
                        }
                    }
                }
                .padding(.horizontal, AccountDetailsTheme.horizontalPadding)
            }
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .processTransparentScrollSurface()
        .navigationTitle(AppCopy.t("Application", en: "App"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            syncLanguageFromProfileIfNeeded()
        }
    }

    private func syncLanguageFromProfileIfNeeded() {
        guard let profileLang = profileService.currentProfile?.preferences.language else { return }
        let normalized = ProcessAppLanguage.normalize(profileLang)
        if normalized != appLanguage.code {
            appLanguage.setLanguage(normalized)
        }
    }

    private func applyLanguage(_ language: ProcessAppLanguage.Code) async {
        appLanguage.setLanguage(language)

        guard let profile = profileService.currentProfile else { return }

        var preferences = profile.preferences
        preferences.language = language.rawValue

        do {
            try await profileService.updatePreferences(preferences)
        } catch {
            DebugLogger.error("\(error.localizedDescription)")
        }
    }
}

// MARK: - Aide & confidentialité

struct ProfileSettingsLegalDetailView: View {
    @Environment(\.openURL) private var openURL
    @State private var inAppSafariURL: URL?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ProfileSummarySectionHeader(title: AppCopy.t("Légal", en: "Legal"))

                AccountDetailsCard {
                    legalRow(title: AppCopy.t("Conditions d'utilisation", en: "Terms of Use"), url: ProcessLegalURLs.termsOfUse)
                    legalRow(title: AppCopy.t("Politique de confidentialité", en: "Privacy Policy"), url: ProcessLegalURLs.privacyPolicy)
                    legalRow(title: AppCopy.t("Données faciales", en: "Facial Data"), url: ProcessLegalURLs.privacyPolicyFaceData)
                    legalRow(title: AppCopy.t("Mentions légales", en: "Legal Notice"), url: ProcessLegalURLs.legalNotice)
                }
                .padding(.horizontal, AccountDetailsTheme.horizontalPadding)

                ProfileSummarySectionHeader(title: AppCopy.t("Aide", en: "Help"))

                AccountDetailsCard {
                    AccountDetailsGlassRow {
                        Button { openURL(ProcessAppStoreReviewPrompt.writeReviewURL) } label: {
                            ProfileEditListRow(
                                label: AppCopy.t("Noter Process", en: "Rate Process"),
                                value: nil,
                                placeholder: AppCopy.t("App Store", en: "App Store")
                            )
                        }
                        .buttonStyle(.processPlain)
                    }

                    NavigationLink {
                        ScrollView {
                            HealthMedicalSourcesView()
                                .padding(AccountDetailsTheme.horizontalPadding)
                                .padding(.vertical, 16)
                        }
                        .processTransparentScrollSurface()
                        .navigationTitle(AppCopy.t("Scores et recommandations", en: "Scores and Recommendations"))
                        .navigationBarTitleDisplayMode(.inline)
                        .processSettingsDetailPage()
                        .reportsProfileSubrouteActive(true)
                    } label: {
                        AccountDetailsGlassRow {
                            ProfileEditListRow(
                                label: AppCopy.t("Scores et recommandations", en: "Scores and Recommendations"),
                                value: nil,
                                placeholder: AppCopy.t("Sources et avertissements", en: "Sources and warnings")
                            )
                        }
                    }
                    .buttonStyle(.processPlain)

                    AccountDetailsGlassRow {
                        Button { inAppSafariURL = ProcessLegalURLs.supportPage } label: {
                            ProfileEditListRow(
                                label: AppCopy.t("Centre d'aide", en: "Help Center"),
                                value: nil,
                                placeholder: AppCopy.t("FAQ et assistance", en: "FAQ and support")
                            )
                        }
                        .buttonStyle(.processPlain)
                    }

                    AccountDetailsGlassRow {
                        Button { openURL(ProcessLegalURLs.supportMail) } label: {
                            ProfileEditListRow(
                                label: AppCopy.t("Contacter le support", en: "Contact Support"),
                                value: nil,
                                placeholder: AppCopy.t("E-mail à l'équipe", en: "Email the team")
                            )
                        }
                        .buttonStyle(.processPlain)
                    }
                }
                .padding(.horizontal, AccountDetailsTheme.horizontalPadding)

                ProfileSummarySectionHeader(title: AppCopy.t("Services intelligents", en: "Smart Services"))

                AccountDetailsCard {
                    AccountDetailsGlassRow {
                        ProfileEditListRow(
                            label: AppCopy.t("Coach IA", en: "AI Coach"),
                            value: AppCopy.t("Activé", en: "Enabled"),
                            placeholder: "—",
                            showsChevron: false,
                            valueIsMuted: true
                        )
                    }

                    AccountDetailsGlassRow {
                        ProfileEditListRow(
                            label: AppCopy.t("Analyse scan visage", en: "Face Scan Analysis"),
                            value: AppCopy.t("Activée", en: "Enabled"),
                            placeholder: "—",
                            showsChevron: false,
                            valueIsMuted: true
                        )
                    }
                }
                .padding(.horizontal, AccountDetailsTheme.horizontalPadding)
            }
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .processTransparentScrollSurface()
        .navigationTitle(AppCopy.t("Aide & confidentialité", en: "Help & Privacy"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: Binding(
            get: { inAppSafariURL != nil },
            set: { if !$0 { inAppSafariURL = nil } }
        )) {
            if let url = inAppSafariURL {
                ProfileSettingsSafariView(url: url)
                    .ignoresSafeArea()
            }
        }
    }

    private func legalRow(title: String, url: URL) -> some View {
        AccountDetailsGlassRow {
            Button { inAppSafariURL = url } label: {
                ProfileEditListRow(label: title, value: nil, placeholder: AppCopy.t("Ouvrir", en: "Open"))
            }
            .buttonStyle(.processPlain)
        }
    }
}

private struct ProfileSettingsSafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

/// Historique scans — depuis Paramètres profil.
struct BodyScanHistoryTabContent: View {
    @Environment(\.appTheme) private var theme
    @Bindable private var historyStore = BodyScanHistoryStore.shared

    var body: some View {
        List {
            if historyStore.history.isEmpty {
                ContentUnavailableView(
                    AppCopy.t("Aucun rapport", en: "No Reports"),
                    systemImage: "doc.text",
                    description: Text(AppCopy.t("Fais un scan pour générer ton premier rapport.", en: "Take a scan to generate your first report."))
                )
            } else {
                ForEach(historyStore.history) { result in
                    NavigationLink {
                        BodyScanReportView(result: result) {}
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(AppCopy.t("Score \(result.postureScore)/100", en: "Score \(result.postureScore)/100"))
                                .font(.headline)
                            Text(result.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(theme.secondaryText)
                        }
                    }
                }
            }
        }
        .navigationTitle(AppCopy.t("Rapports", en: "Reports"))
        .reportsProfileSubrouteActive(true)
    }
}
