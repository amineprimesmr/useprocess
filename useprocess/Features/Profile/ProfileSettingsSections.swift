import SafariServices
import SwiftUI
import UIKit

// MARK: - Profil

struct ProfileSettingsProfileDetailView: View {
    var onShareProfile: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ProfileSummarySectionHeader(title: "Profil")

                AccountDetailsCard {
                    AccountDetailsGlassRow {
                        Button(action: onShareProfile) {
                            ProfileEditListRow(
                                label: "Partager mon profil",
                                value: nil,
                                placeholder: "Lien et @tag"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AccountDetailsTheme.horizontalPadding)
            }
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .processTransparentScrollSurface()
        .navigationTitle("Profil")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Compte

struct ProfileSettingsAccountDetailView: View {
    @EnvironmentObject private var profileService: UnifiedProfileService

    private var profile: UnifiedUserProfile? {
        profileService.currentProfile
    }

    private var usernameDisplay: String? {
        let tag = ProcessUsernameTag.normalize(
            SocialProfileStore.shared.profile?.username
                ?? profile?.username
                ?? ""
        )
        return tag.isEmpty ? nil : "@\(tag)"
    }

    private var ageText: String? {
        guard let profile, profile.age > 0 else { return nil }
        return profile.ageFormatted
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ProfileSummarySectionHeader(title: "Identité")

                AccountDetailsCard {
                    NavigationLink(value: ProfileEditDestination.username) {
                        AccountDetailsGlassRow {
                            ProfileEditListRow(
                                label: "Tag Process",
                                value: usernameDisplay,
                                placeholder: "Choisir ton @",
                                showsChevron: false
                            )
                        }
                    }
                    .buttonStyle(.plain)

                    NavigationLink(value: ProfileEditDestination.findUser) {
                        AccountDetailsGlassRow {
                            ProfileEditListRow(
                                label: "Trouver un utilisateur",
                                value: nil,
                                placeholder: "Rechercher par @"
                            )
                        }
                    }
                    .buttonStyle(.plain)

                    NavigationLink(value: ProfileEditDestination.firstName) {
                        AccountDetailsGlassRow {
                            ProfileEditListRow(
                                label: "Prénom",
                                value: profile?.firstName,
                                placeholder: "Non renseigné",
                                showsChevron: false
                            )
                        }
                    }
                    .buttonStyle(.plain)

                    NavigationLink(value: ProfileEditDestination.gender) {
                        AccountDetailsGlassRow {
                            ProfileEditListRow(
                                label: "Sexe",
                                value: profile?.gender.displayName,
                                placeholder: "Non renseigné"
                            )
                        }
                    }
                    .buttonStyle(.plain)

                    NavigationLink(value: ProfileEditDestination.birthDate) {
                        AccountDetailsGlassRow {
                            ProfileEditListRow(
                                label: "Date de naissance",
                                value: birthDateDisplay,
                                placeholder: "Non renseigné"
                            )
                        }
                    }
                    .buttonStyle(.plain)

                    AccountDetailsGlassRow {
                        ProfileEditListRow(
                            label: "Âge",
                            value: ageText,
                            placeholder: "—",
                            showsChevron: false,
                            valueIsMuted: true
                        )
                    }
                }
                .padding(.horizontal, AccountDetailsTheme.horizontalPadding)

                ProfileSummarySectionHeader(title: "Informations")

                AccountDetailsCard {
                    if let profile = profile {
                        AccountDetailsGlassRow {
                            ProfileEditListRow(
                                label: "E-mail",
                                value: profile.email,
                                placeholder: "Non renseigné",
                                showsChevron: false,
                                valueIsMuted: true
                            )
                        }
                    }

                    if let score = BodyScanHistoryStore.shared.latestResult?.postureScore {
                        AccountDetailsGlassRow {
                            ProfileEditListRow(
                                label: "Dernier scan",
                                value: "\(score)/100",
                                placeholder: "—",
                                showsChevron: false,
                                valueIsMuted: true
                            )
                        }
                    }

                    AccountDetailsGlassRow {
                        ProfileEditListRow(
                            label: "Appareil",
                            value: deviceLine,
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
        .navigationTitle("Compte")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var birthDateDisplay: String? {
        guard let profile else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: profile.birthDate)
    }

    private var deviceLine: String {
        "\(UIDevice.current.model) · iOS \(UIDevice.current.systemVersion)"
    }
}

// MARK: - Santé

struct ProfileSettingsHealthDetailView: View {
    @EnvironmentObject private var healthManager: HealthManager

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ProfileSummarySectionHeader(title: "Santé & outils")

                AccountDetailsCard {
                    NavigationLink {
                        BodyScanHistoryTabContent()
                    } label: {
                        AccountDetailsGlassRow {
                            ProfileEditListRow(
                                label: "Mes rapports de scan",
                                value: nil,
                                placeholder: "Historique posture"
                            )
                        }
                    }
                    .buttonStyle(.plain)

                    AccountDetailsGlassRow {
                        Button {
                            Task {
                                if healthManager.isAuthorized {
                                    await healthManager.performFullSync()
                                } else {
                                    await healthManager.requestAuthorizationAsync()
                                }
                            }
                        } label: {
                            ProfileEditListRow(
                                label: healthManager.isAuthorized ? "Synchroniser Santé" : "Connecter Apple Santé",
                                value: healthManager.isAuthorized
                                    ? (healthManager.hasAppleWatch ? "Apple Watch" : "App Santé")
                                    : nil,
                                placeholder: "Autoriser l'accès"
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    NavigationLink {
                        HealthConnectedSourcesSettingsView()
                            .environmentObject(healthManager)
                    } label: {
                        AccountDetailsGlassRow {
                            ProfileEditListRow(
                                label: "Sources connectées",
                                value: healthManager.connectedSources.isEmpty
                                    ? nil
                                    : "\(healthManager.connectedSources.count)",
                                placeholder: "Apps et appareils"
                            )
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, AccountDetailsTheme.horizontalPadding)
            }
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .processTransparentScrollSurface()
        .navigationTitle("Santé & données")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Application

struct ProfileSettingsAppDetailView: View {
    @Bindable private var session = AppSession.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ProfileSummarySectionHeader(title: "Apparence")

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
                                        value: session.appearance == mode ? "Actif" : nil,
                                        placeholder: "",
                                        showsChevron: false,
                                        valueIsMuted: session.appearance != mode
                                    )
                                }
                                .buttonStyle(.plain)
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
        .navigationTitle("Application")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Aide & confidentialité

struct ProfileSettingsLegalDetailView: View {
    @Environment(\.openURL) private var openURL
    @State private var inAppSafariURL: URL?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ProfileSummarySectionHeader(title: "Légal")

                AccountDetailsCard {
                    legalRow(title: "Conditions d'utilisation", url: ProcessLegalURLs.termsOfUse)
                    legalRow(title: "Politique de confidentialité", url: ProcessLegalURLs.privacyPolicy)
                    legalRow(title: "Données faciales (TrueDepth)", url: ProcessLegalURLs.privacyPolicyFaceData)
                    legalRow(title: "Mentions légales", url: ProcessLegalURLs.legalNotice)
                }
                .padding(.horizontal, AccountDetailsTheme.horizontalPadding)

                ProfileSummarySectionHeader(title: "Aide")

                AccountDetailsCard {
                    NavigationLink {
                        ScrollView {
                            HealthMedicalSourcesView()
                                .padding(AccountDetailsTheme.horizontalPadding)
                                .padding(.vertical, 16)
                        }
                        .processTransparentScrollSurface()
                        .navigationTitle("Scores et recommandations")
                        .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        AccountDetailsGlassRow {
                            ProfileEditListRow(
                                label: "Scores et recommandations",
                                value: nil,
                                placeholder: "Sources et avertissements"
                            )
                        }
                    }
                    .buttonStyle(.plain)

                    AccountDetailsGlassRow {
                        Button { inAppSafariURL = ProcessLegalURLs.supportPage } label: {
                            ProfileEditListRow(
                                label: "Centre d'aide",
                                value: nil,
                                placeholder: "FAQ et assistance"
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    AccountDetailsGlassRow {
                        Button { openURL(ProcessLegalURLs.supportMail) } label: {
                            ProfileEditListRow(
                                label: "Contacter le support",
                                value: nil,
                                placeholder: "E-mail à l'équipe"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AccountDetailsTheme.horizontalPadding)

                ProfileSummarySectionHeader(title: "Services intelligents")

                AccountDetailsCard {
                    AccountDetailsGlassRow {
                        ProfileEditListRow(
                            label: "Coach IA",
                            value: "Activé",
                            placeholder: "—",
                            showsChevron: false,
                            valueIsMuted: true
                        )
                    }

                    AccountDetailsGlassRow {
                        ProfileEditListRow(
                            label: "Analyse scan visage",
                            value: "Activée",
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
        .navigationTitle("Aide & confidentialité")
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
                ProfileEditListRow(label: title, value: nil, placeholder: "Ouvrir")
            }
            .buttonStyle(.plain)
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
                    "Aucun rapport",
                    systemImage: "doc.text",
                    description: Text("Fais un scan pour générer ton premier rapport.")
                )
            } else {
                ForEach(historyStore.history) { result in
                    NavigationLink {
                        BodyScanReportView(result: result) {}
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Score \(result.postureScore)/100")
                                .font(.headline)
                            Text(result.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(theme.secondaryText)
                        }
                    }
                }
            }
        }
        .navigationTitle("Rapports")
    }
}
