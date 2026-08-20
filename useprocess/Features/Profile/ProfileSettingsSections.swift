import SafariServices
import SwiftUI
import UIKit
import FirebaseAuth

// MARK: - Mon compte (Opal)

struct ProfileSettingsAccountDetailView: View {
    @EnvironmentObject private var profileService: UnifiedProfileService
    @Environment(\.profileAccountDeletionHandler) private var onDeleteConfirmed

    @State private var showsLogoutConfirmation = false
    @State private var isRestoringPurchases = false
    @State private var isOpeningManageSubscriptions = false
    @State private var restoreMessage: String?
    @State private var manageSubscriptionsMessage: String?

    private var profile: UnifiedUserProfile? { profileService.currentProfile }
    private let sectionBlockSpacing: CGFloat = 22

    var body: some View {
        ProcessSettingsOpalScrollPage(
            title: AppCopy.t("Mon compte", en: "My Account")
        ) {
            VStack(spacing: sectionBlockSpacing) {
                ProcessSettingsOpalCard {
                        NavigationLink(value: ProfileEditDestination.firstName) {
                            ProcessSettingsOpalAccountRow(
                                icon: "person.fill",
                                title: AppCopy.t("Ton prénom", en: "Your first name"),
                                value: profile?.firstName,
                                placeholder: AppCopy.t("Non renseigné", en: "Not provided")
                            )
                        }
                        .processSettingsOpalRowButton()

                        ProcessSettingsOpalRowDivider()

                        NavigationLink(value: ProfileEditDestination.gender) {
                            ProcessSettingsOpalAccountRow(
                                icon: "briefcase.fill",
                                title: AppCopy.t("Sexe", en: "Gender"),
                                value: profile?.gender.displayName,
                                placeholder: AppCopy.t("Non renseigné", en: "Not provided")
                            )
                        }
                        .processSettingsOpalRowButton()

                        if let ageText {
                            ProcessSettingsOpalRowDivider()

                            ProcessSettingsOpalAccountRow(
                                icon: "hourglass.circle.fill",
                                title: AppCopy.t("Mon âge", en: "My Age"),
                                value: ageText,
                                trailingIcon: .none
                            )
                        }
                    }
                    .padding(.horizontal, ProcessSettingsOpalTheme.horizontalPadding)

                    ProcessSettingsOpalCard {
                        ProcessSettingsOpalAccountRow(
                            icon: "envelope.fill",
                            title: AppCopy.t("E-mail", en: "Email"),
                            value: profile?.email,
                            placeholder: AppCopy.t("Non renseigné", en: "Not provided"),
                            trailingIcon: .chevron
                        )

                        ProcessSettingsOpalRowDivider()

                        ProcessSettingsOpalRow(
                            icon: "apple.logo",
                            title: AppCopy.t("Se connecter avec Apple", en: "Sign in with Apple"),
                            trailingIcon: .status(appleLinkedLabel)
                        )

                        ProcessSettingsOpalRowDivider()

                        ProcessSettingsOpalRow(
                            icon: "phone.fill",
                            title: AppCopy.t("Numéro de téléphone", en: "Phone Number"),
                            trailingIcon: .status(AppCopy.t("Ajouter", en: "Add"))
                        )
                    }
                    .padding(.horizontal, ProcessSettingsOpalTheme.horizontalPadding)

                    ProcessSettingsOpalCard {
                        Button {
                            Task { await openManageSubscriptions() }
                        } label: {
                            ProcessSettingsOpalRow(
                                icon: "creditcard.fill",
                                title: AppCopy.t("Gérer mon abonnement", en: "Manage Subscription"),
                                trailingIcon: isOpeningManageSubscriptions ? .status("…") : .chevron
                            )
                        }
                        .processSettingsOpalRowButton()
                        .disabled(isOpeningManageSubscriptions || isRestoringPurchases)

                        ProcessSettingsOpalRowDivider()

                        Button {
                            Task { await restorePurchases() }
                        } label: {
                            ProcessSettingsOpalRow(
                                icon: "arrow.clockwise.circle.fill",
                                title: AppCopy.t("Restaurer l'achat", en: "Restore Purchase"),
                                trailingIcon: isRestoringPurchases ? .status("…") : .none,
                                showsDivider: false
                            )
                        }
                        .processSettingsOpalRowButton()
                        .disabled(isRestoringPurchases || isOpeningManageSubscriptions)
                    }
                    .padding(.horizontal, ProcessSettingsOpalTheme.horizontalPadding)

                    ProcessSettingsOpalCard {
                        ProcessSettingsOpalActionRow(
                            icon: "rectangle.portrait.and.arrow.right.fill",
                            title: AppCopy.t("Se déconnecter", en: "Log Out")
                        ) {
                            showsLogoutConfirmation = true
                        }
                    }
                    .padding(.horizontal, ProcessSettingsOpalTheme.horizontalPadding)

                    Text(AppCopy.t(
                        "Tu pourrais perdre l'accès à certaines fonctionnalités comme la série, la communauté et d'autres.",
                        en: "You might lose access to some features like your streak, community, and more."
                    ))
                    .font(.system(size: 13))
                    .foregroundStyle(ProcessSettingsOpalTheme.valueTint)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.top, 8)

                    AccountDeleteAnimatedButton(onConfirm: handleAccountDeletion)
                    .padding(.top, 12)
            }
        }
        .task {
            FaceScanHistoryStore.shared.reloadForUser(userId: profileService.currentProfile?.userId)
        }
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
        .alert(
            AppCopy.t("Restaurer l'achat", en: "Restore Purchase"),
            isPresented: Binding(
                get: { restoreMessage != nil },
                set: { if !$0 { restoreMessage = nil } }
            )
        ) {
            Button(AppCopy.close, role: .cancel) { restoreMessage = nil }
        } message: {
            Text(restoreMessage ?? "")
        }
        .alert(
            AppCopy.t("Gérer mon abonnement", en: "Manage Subscription"),
            isPresented: Binding(
                get: { manageSubscriptionsMessage != nil },
                set: { if !$0 { manageSubscriptionsMessage = nil } }
            )
        ) {
            Button(AppCopy.close, role: .cancel) { manageSubscriptionsMessage = nil }
        } message: {
            Text(manageSubscriptionsMessage ?? "")
        }
    }

    private var ageText: String? {
        guard let profile, profile.age > 0 else { return nil }
        return profile.ageFormatted
    }

    private var appleLinkedLabel: String {
        guard FirebaseBootstrap.isConfigured else {
            return AppCopy.t("Non lié", en: "Not linked")
        }
        let linked = Auth.auth().currentUser?.providerData.contains { $0.providerID == "apple.com" } == true
        return linked
            ? AppCopy.t("Lié", en: "Linked")
            : AppCopy.t("Non lié", en: "Not linked")
    }

    private func handleAccountDeletion() {
        if let onDeleteConfirmed {
            onDeleteConfirmed()
            return
        }
        AppSession.shared.enqueueAccountDeletionFromUI()
    }

    private func openManageSubscriptions() async {
        guard !isOpeningManageSubscriptions else { return }
        isOpeningManageSubscriptions = true
        defer { isOpeningManageSubscriptions = false }

        do {
            try await SubscriptionService.shared.showManageSubscriptions()
        } catch {
            manageSubscriptionsMessage = error.localizedDescription
        }
    }

    private func restorePurchases() async {
        guard !isRestoringPurchases else { return }
        isRestoringPurchases = true
        defer { isRestoringPurchases = false }

        do {
            try await SubscriptionService.shared.restorePurchases()
            restoreMessage = AppCopy.t(
                "Achats restaurés. Si tu as un abonnement actif, il sera disponible sous peu.",
                en: "Purchases restored. If you have an active subscription, it will be available shortly."
            )
        } catch {
            restoreMessage = AppCopy.t(
                "Impossible de restaurer pour l'instant. Réessaie ou contacte le support.",
                en: "Couldn't restore right now. Try again or contact support."
            )
        }
    }
}

// MARK: - Santé

struct ProfileSettingsHealthDetailView: View {
    @EnvironmentObject private var healthManager: HealthManager

    var body: some View {
        ProcessSettingsOpalScrollPage(
            title: AppCopy.t("Santé & données", en: "Health & Data")
        ) {
            ProcessSettingsOpalSectionTitle(
                title: AppCopy.t("Santé & outils", en: "Health & Tools")
            )

            ProcessSettingsOpalCard {
                NavigationLink {
                    BodyScanHistoryTabContent()
                        .reportsProfileSubrouteActive(true)
                } label: {
                    ProcessSettingsOpalRow(
                        icon: "doc.text.fill",
                        title: AppCopy.t("Mes rapports de scan", en: "My Scan Reports"),
                        subtitle: AppCopy.t("Historique posture", en: "Posture history"),
                        showsDivider: false
                    )
                }
                .processSettingsOpalRowButton()

                ProcessSettingsOpalRowDivider()

                Button {
                    Task {
                        if healthManager.isAuthorized {
                            await healthManager.performFullSync()
                        } else {
                            await healthManager.requestAuthorizationAsync(analyticsSource: "profile_settings")
                        }
                    }
                } label: {
                    ProcessSettingsOpalRow(
                        icon: "heart.text.square.fill",
                        title: healthManager.isAuthorized
                            ? AppCopy.t("Synchroniser Santé", en: "Sync Health")
                            : AppCopy.t("Connecter Apple Santé", en: "Connect Apple Health"),
                        trailingIcon: .status(
                            healthManager.isAuthorized
                                ? (healthManager.hasAppleWatch ? "Apple Watch" : AppCopy.t("Connecté", en: "Connected"))
                                : AppCopy.t("Connecter", en: "Connect")
                        ),
                        showsDivider: false
                    )
                }
                .processSettingsOpalRowButton()

                ProcessSettingsOpalRowDivider()

                NavigationLink {
                    HealthConnectedSourcesSettingsView()
                        .environmentObject(healthManager)
                        .reportsProfileSubrouteActive(true)
                } label: {
                    ProcessSettingsOpalRow(
                        icon: "link.circle.fill",
                        title: AppCopy.t("Sources connectées", en: "Connected Sources"),
                        subtitle: AppCopy.t("Apps et appareils", en: "Apps and devices"),
                        showsDivider: false
                    )
                }
                .processSettingsOpalRowButton()
            }
            .padding(.horizontal, ProcessSettingsOpalTheme.horizontalPadding)
        }
    }
}

// MARK: - Application

struct ProfileSettingsAppDetailView: View {
    @Bindable private var session = AppSession.shared
    @State private var highlightedAppearance: AppAppearance?

    var body: some View {
        ProcessSettingsOpalScrollPage(
            title: AppCopy.t("Apparence", en: "Appearance")
        ) {
            ProcessSettingsOpalSectionTitle(title: AppCopy.t("Apparence", en: "Appearance"))

            ProcessSettingsOpalCard {
                ForEach(Array(AppAppearance.allCases.enumerated()), id: \.element.id) { index, mode in
                    if index > 0 { ProcessSettingsOpalRowDivider() }

                    Button {
                        ProcessSettingsChangeFeedback.performRowSelection(
                            highlight: $highlightedAppearance,
                            value: mode,
                            isSameValue: session.appearance == mode
                        ) {
                            session.setAppearance(mode)
                        }
                    } label: {
                        ProcessSettingsOpalRow(
                            icon: appearanceIcon(for: mode),
                            title: mode.label,
                            trailingIcon: session.appearance == mode
                                ? .status(AppCopy.t("Actif", en: "Active"))
                                : .none,
                            showsDivider: false
                        )
                        .processSettingsSelectionHighlight(
                            isHighlighted: highlightedAppearance == mode,
                            isActive: session.appearance == mode
                        )
                    }
                    .processSettingsOpalRowButton()
                }
            }
            .padding(.horizontal, ProcessSettingsOpalTheme.horizontalPadding)
        }
    }

    private func appearanceIcon(for mode: AppAppearance) -> String {
        switch mode {
        case .system: return "circle.lefthalf.filled"
        case .dark: return "moon.fill"
        case .light: return "sun.max.fill"
        }
    }
}

// MARK: - Langue

struct ProfileSettingsLanguageDetailView: View {
    var body: some View {
        ProcessSettingsOpalScrollPage(
            title: AppCopy.t("Langue", en: "Language")
        ) {
            ProcessSettingsOpalSectionTitle(title: AppCopy.t("Langue", en: "Language"))

            ProcessSettingsOpalCard {
                ProcessSettingsInlineLanguageRows()
            }
            .padding(.horizontal, ProcessSettingsOpalTheme.horizontalPadding)
        }
    }
}

// MARK: - Aide & confidentialité

struct ProfileSettingsLegalDetailView: View {
    @Environment(\.openURL) private var openURL
    @State private var inAppSafariURL: URL?
    @State private var showsSupportChat = false

    var body: some View {
        ProcessSettingsOpalScrollPage(
            title: AppCopy.t("Aide & confidentialité", en: "Help & Privacy")
        ) {
            ProcessSettingsOpalSectionTitle(title: AppCopy.t("Légal", en: "Legal"))

            ProcessSettingsOpalCard {
                legalRow(
                    icon: "doc.text.fill",
                    title: AppCopy.t("Conditions d'utilisation", en: "Terms of Use"),
                    url: ProcessLegalURLs.termsOfUse,
                    showsDivider: false
                )
                ProcessSettingsOpalRowDivider()
                legalRow(icon: "hand.raised.fill", title: AppCopy.t("Politique de confidentialité", en: "Privacy Policy"), url: ProcessLegalURLs.privacyPolicy)
                ProcessSettingsOpalRowDivider()
                legalRow(icon: "face.smiling.fill", title: AppCopy.t("Données faciales", en: "Facial Data"), url: ProcessLegalURLs.privacyPolicyFaceData)
                ProcessSettingsOpalRowDivider()
                legalRow(icon: "building.columns.fill", title: AppCopy.t("Mentions légales", en: "Legal Notice"), url: ProcessLegalURLs.legalNotice)
            }
            .padding(.horizontal, ProcessSettingsOpalTheme.horizontalPadding)

            ProcessSettingsOpalSectionTitle(title: AppCopy.t("Aide", en: "Help"))

            ProcessSettingsOpalCard {
                NavigationLink {
                    ProcessSettingsNestedScrollPage(
                        title: AppCopy.t("Scores et recommandations", en: "Scores and Recommendations")
                    ) {
                        HealthMedicalSourcesView()
                            .padding(.horizontal, ProcessSettingsOpalTheme.horizontalPadding)
                            .padding(.vertical, 16)
                    }
                    .reportsProfileSubrouteActive(true)
                } label: {
                    ProcessSettingsOpalRow(icon: "chart.bar.doc.horizontal.fill", title: AppCopy.t("Scores et recommandations", en: "Scores and Recommendations"), showsDivider: false)
                }
                .processSettingsOpalRowButton()

                ProcessSettingsOpalRowDivider()

                Button { openSupportChat() } label: {
                    ProcessSettingsOpalRow(icon: "bubble.left.and.bubble.right.fill", title: AppCopy.t("Discuter avec l'équipe", en: "Chat with the team"), showsDivider: false)
                }
                .processSettingsOpalRowButton()

                ProcessSettingsOpalRowDivider()

                Button { openURL(ProcessLegalURLs.supportMail) } label: {
                    ProcessSettingsOpalRow(icon: "envelope.fill", title: AppCopy.t("Écrire un e-mail", en: "Send an email"), trailingIcon: .external, showsDivider: false)
                }
                .processSettingsOpalRowButton()
            }
            .padding(.horizontal, ProcessSettingsOpalTheme.horizontalPadding)

            ProcessSettingsOpalSectionTitle(title: AppCopy.t("Services intelligents", en: "Smart Services"))

            ProcessSettingsOpalCard {
                ProcessSettingsOpalRow(
                    icon: "sparkles",
                    title: AppCopy.t("Coach IA", en: "AI Coach"),
                    trailingIcon: .status(AppCopy.t("Activé", en: "Enabled")),
                    showsDivider: false
                )
                ProcessSettingsOpalRowDivider()
                ProcessSettingsOpalRow(
                    icon: "viewfinder.circle.fill",
                    title: AppCopy.t("Analyse scan visage", en: "Face Scan Analysis"),
                    trailingIcon: .status(AppCopy.t("Activée", en: "Enabled")),
                    showsDivider: false
                )
            }
            .padding(.horizontal, ProcessSettingsOpalTheme.horizontalPadding)
        }
        .sheet(isPresented: Binding(
            get: { inAppSafariURL != nil },
            set: { if !$0 { inAppSafariURL = nil } }
        )) {
            if let url = inAppSafariURL {
                ProfileSettingsSafariView(url: url).ignoresSafeArea()
            }
        }
        .fullScreenCover(isPresented: $showsSupportChat) {
            ProcessSupportChatView()
        }
    }

    private func openSupportChat() {
        ProcessAnalytics.trackSupportChatOpened(source: "settings_legal")
        if ProcessCrispSupport.isReady {
            showsSupportChat = true
        } else {
            openURL(ProcessLegalURLs.supportMail)
        }
    }

    private func legalRow(icon: String, title: String, url: URL, showsDivider: Bool = false) -> some View {
        Button { inAppSafariURL = url } label: {
            ProcessSettingsOpalRow(icon: icon, title: title, trailingIcon: .external, showsDivider: showsDivider)
        }
        .processSettingsOpalRowButton()
    }
}

struct ProfileSettingsSafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

/// Historique scans — depuis Paramètres profil.
struct BodyScanHistoryTabContent: View {
    @Environment(\.dismiss) private var dismiss
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
                            .processSettingsSubpageToolbar(
                                title: AppCopy.t("Rapport", en: "Report")
                            )
                            .processSettingsOpalPage()
                            .reportsProfileSubrouteActive(true)
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
        .scrollContentBackground(.hidden)
        .processSettingsStandardToolbar(
            title: AppCopy.t("Rapports", en: "Reports"),
            onBack: { dismiss() }
        )
        .processSettingsOpalPage()
        .reportsProfileSubrouteActive(true)
    }
}
