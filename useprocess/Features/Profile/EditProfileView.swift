import SwiftUI

/// Hub réglages modal (depuis Accueil) — même contenu que l’onglet, avec en-tête fermer.
struct EditProfileView: View {
    var showsDismissHeader: Bool = true

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var profileService: UnifiedProfileService
    @State private var profileStore = SocialProfileStore.shared

    private var profile: UnifiedUserProfile? {
        profileService.currentProfile
    }

    private var initials: String {
        let first = profile?.firstName.first.map(String.init) ?? "?"
        return first.uppercased()
    }

    private var firstName: String {
        let name = profile?.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? profileStore.profile?.displayName
            ?? AppCopy.settings
        return name.isEmpty ? AppCopy.settings : name
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsDismissHeader {
                AccountDetailsGlassHeader(
                    title: nil,
                    onBack: { dismiss() },
                    showsSave: false
                )
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    identityBlock

                    ProcessCreatorStudioHubLink()

                    ProfileSettingsHubLinksSection()
                }
                .padding(.horizontal, AccountDetailsTheme.horizontalPadding)
                .padding(.top, showsDismissHeader ? 0 : 16)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .processTransparentScrollSurface()
            .processAdoptForIGTabBar()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .processClearUIKitHostingBackground()
        .task {
            if profileService.currentProfile == nil {
                await profileService.loadProfile()
            }
            profileStore.bind(unified: profileService.currentProfile)
            ProcessCreatorModeStore.shared.syncFromCurrentProfile()
            FaceScanHistoryStore.shared.reloadForUser(
                userId: UserScopedStorage.currentUserId()
            )
        }
        .onAppear {
            profileStore.bind(unified: profileService.currentProfile)
            ProcessCreatorModeStore.shared.syncFromCurrentProfile()
        }
    }

    private var identityBlock: some View {
        VStack(spacing: 12) {
            ProfileScanHistoryCarousel(
                size: 132,
                isPlaybackActive: true,
                initials: initials
            )

            Text(firstName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(theme.primaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, showsDismissHeader ? 4 : 2)
        .padding(.bottom, 4)
    }
}
