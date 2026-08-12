import SwiftUI

/// Onglet Réglages — scans + hub paramètres.
struct ProcessProfileHomeView: View {
    @Binding var selectedSection: ProcessMainSection
    var isTabActive: Bool = true

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
        processMainScrollableChrome(
            selectedSection: $selectedSection,
            pageSection: .profile
        ) {
            VStack(alignment: .leading, spacing: 20) {
                identityBlock

                ProcessSettingsPlanProgramSections()

                ProfileSettingsHubLinksSection()
            }
            .padding(.horizontal, AccountDetailsTheme.horizontalPadding)
            .padding(.top, 16)
            .padding(.bottom, 32)
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
            WelcomePlanStore.shared.reloadForCurrentUser()
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
                isPlaybackActive: isTabActive,
                initials: initials
            )

            Text(firstName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(theme.primaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
        .padding(.bottom, 4)
    }
}
