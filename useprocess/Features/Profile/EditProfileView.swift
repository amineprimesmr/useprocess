import SwiftUI

/// Hub réglages — uniquement les catégories de paramètres.
struct EditProfileView: View {
    var showsDismissHeader: Bool = true

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var profileService: UnifiedProfileService
    @State private var profileStore = SocialProfileStore.shared

    var body: some View {
        VStack(spacing: 0) {
            if showsDismissHeader {
                AccountDetailsGlassHeader(
                    title: AppCopy.settings,
                    onBack: { dismiss() },
                    showsSave: false
                )
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ProcessCreatorStudioHubLink()
                    ProfileSettingsHubLinksSection()
                }
                .padding(.horizontal, AccountDetailsTheme.horizontalPadding)
                .padding(.top, showsDismissHeader ? 8 : 16)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .processTransparentScrollSurface()
            .processAdoptForIGTabBar()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .toolbar(showsDismissHeader ? .hidden : .visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationTitle(showsDismissHeader ? "" : AppCopy.settings)
        .navigationBarTitleDisplayMode(.large)
        .processClearUIKitHostingBackground()
        .task {
            if profileService.currentProfile == nil {
                await profileService.loadProfile()
            }
            profileStore.bind(unified: profileService.currentProfile)
            ProcessCreatorModeStore.shared.syncFromCurrentProfile()
        }
        .onAppear {
            profileStore.bind(unified: profileService.currentProfile)
            ProcessCreatorModeStore.shared.syncFromCurrentProfile()
        }
    }
}
