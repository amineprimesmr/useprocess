import SwiftUI

/// Onglet Profil — scans + évolution du score debloat.
struct ProcessProfileHomeView: View {
    @Binding var selectedSection: ProcessMainSection
    var isTabActive: Bool = true

    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var profileService: UnifiedProfileService
    @State private var profileStore = SocialProfileStore.shared
    @State private var showSettings = false

    private var profile: UnifiedUserProfile? {
        profileService.currentProfile
    }

    private var initials: String {
        let first = profile?.firstName.first.map(String.init) ?? "?"
        return first.uppercased()
    }

    var body: some View {
        processMainScrollableChrome(
            selectedSection: $selectedSection,
            pageSection: .profile
        ) {
            VStack(alignment: .leading, spacing: 20) {
                profileHeader

                identityBlock

                ProfileDebloatScoreSection()
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
        .fullScreenCover(isPresented: $showSettings) {
            ProcessSettingsFullScreenView()
                .environmentObject(profileService)
                .environmentObject(HealthManager.shared)
        }
    }

    private var profileHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(AppCopy.t("Tes progrès", en: "Your progress"))
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(theme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Spacer(minLength: 8)

            Button {
                HapticManager.shared.impact(.light)
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.primaryText)
                    .frame(width: 40, height: 40)
            }
            .processGlassIconButtonStyle()
            .accessibilityLabel(AppCopy.settings)
        }
    }

    private var identityBlock: some View {
        ProfileScanEvolutionPair(
            isPlaybackActive: isTabActive,
            initials: initials
        )
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
        .padding(.bottom, 4)
    }
}
