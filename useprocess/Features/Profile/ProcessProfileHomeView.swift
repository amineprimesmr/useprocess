import SwiftUI

/// Onglet Profil — scans + évolution du score debloat.
struct ProcessProfileHomeView: View {
    @Binding var selectedSection: ProcessMainSection
    var isTabActive: Bool = true
    var isOnboardingPreview: Bool = false
    var onOpenSettings: () -> Void = {}

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

    var body: some View {
        processMainScrollableChrome(
            selectedSection: $selectedSection,
            pageSection: .profile,
            adoptsFloatingTabBar: !isOnboardingPreview
        ) {
            VStack(alignment: .leading, spacing: 20) {
                identityBlock

                ProfileDebloatScoreSection()
            }
            .padding(.horizontal, AccountDetailsTheme.horizontalPadding)
            .padding(.bottom, 32)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            profileHeader
                .padding(.horizontal, AccountDetailsTheme.horizontalPadding)
                .padding(.top, 16)
                .padding(.bottom, 4)
                .background(Color.clear)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .processClearUIKitHostingBackground()
        .task {
            guard !isOnboardingPreview else { return }
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
            guard !isOnboardingPreview else { return }
            profileStore.bind(unified: profileService.currentProfile)
            ProcessCreatorModeStore.shared.syncFromCurrentProfile()
            clearTransientInteractionBlockers()
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

            ProcessGlassIconButton(
                systemName: "gearshape",
                size: 44,
                iconSize: 17,
                action: openSettings
            )
            .accessibilityLabel(AppCopy.settings)
        }
    }

    private func openSettings() {
        clearTransientInteractionBlockers()
        HapticManager.shared.impact(.light)
        onOpenSettings()
    }

    private func clearTransientInteractionBlockers() {
        FaceScanScreenFlash.shared.deactivate(animated: false)
        ProcessEveningCheckInPresenter.shared.dismissImmediately()
        PlanHomeTutorialStore.shared.cancelScheduledPresentation()
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
