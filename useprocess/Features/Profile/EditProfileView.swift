import SwiftUI

/// Hub paramètres — catégories + sous-pages.
struct EditProfileView: View {
    var onLogout: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var profileService: UnifiedProfileService
    @Bindable private var activityStatusStore = ProcessActivityStatusStore.shared
    @State private var profileStore = SocialProfileStore.shared
    @State private var showPhotoFlow = false
    @State private var showActivityStatusSheet = false
    @State private var activityStatusDate = Calendar.current.startOfDay(for: Date())
    @State private var photoMenuAnchor = CGPoint(
        x: UIScreen.main.bounds.midX,
        y: UIScreen.main.bounds.height * 0.22
    )

    private var profile: UnifiedUserProfile? {
        profileService.currentProfile
    }

    private var initials: String {
        let first = profile?.firstName.first.map(String.init) ?? "?"
        let last = profile?.lastName?.first.map(String.init) ?? ""
        return (first + last).uppercased()
    }

    private var firstName: String {
        let name = profile?.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? profileStore.profile?.displayName
            ?? "Mon profil"
        return name.isEmpty ? "Mon profil" : name
    }

    private var currentActivityStatus: ProcessActivityStatus {
        activityStatusStore.status(for: activityStatusDate)
    }

    var body: some View {
        VStack(spacing: 0) {
                AccountDetailsGlassHeader(
                    title: nil,
                    onBack: { dismiss() },
                    onSave: { dismiss() },
                    saveDisabled: true
                )

                ScrollView {
                    VStack(spacing: 0) {
                    VStack(spacing: 14) {
                        AccountDetailsAvatarSection(
                            displayName: firstName,
                            initials: initials,
                            image: profileStore.profilePhoto,
                            onChangePhoto: { showPhotoFlow = true }
                        )

                        ProfileSettingsActivityStatusPill(
                            status: currentActivityStatus,
                            action: openActivityStatusSheet
                        )
                        .padding(.horizontal, AccountDetailsTheme.horizontalPadding)
                    }
                    .frame(maxWidth: .infinity)

                    ProfileSettingsHubLinksSection()
                        .padding(.horizontal, AccountDetailsTheme.horizontalPadding)
                        .padding(.top, 20)

                        VStack(spacing: AccountDetailsTheme.rowSpacing) {
                            AccountDetailsActionButton(title: "Se déconnecter") {
                                onLogout()
                            }
                        }
                        .padding(.horizontal, AccountDetailsTheme.horizontalPadding)
                        .padding(.top, 28)
                    }
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
                .processTransparentScrollSurface()
        }
        .toolbar(.hidden, for: .navigationBar)
        .profilePhotoFlow(
            isPresented: $showPhotoFlow,
            menuAnchor: photoMenuAnchor,
            hasExistingPhoto: profileStore.hasProfilePhoto,
            onApply: { image in
                withAnimation(ProfileEditTheme.spring) {
                    profileStore.applyProfilePhoto(image)
                }
            },
            onDelete: {
                withAnimation(ProfileEditTheme.spring) {
                    profileStore.removeAllPhotos()
                }
            }
        )
        .task {
            if profileService.currentProfile == nil {
                await profileService.loadProfile()
            }
            profileStore.bind(unified: profileService.currentProfile)
        }
        .onAppear {
            profileStore.bind(unified: profileService.currentProfile)
            activityStatusStore.reload()
        }
        .sheet(isPresented: $showActivityStatusSheet) {
            ProcessActivityStatusSheet(selectedDate: $activityStatusDate)
        }
    }

    private func openActivityStatusSheet() {
        HapticManager.shared.impact(.light)
        activityStatusDate = Calendar.current.startOfDay(for: Date())
        showActivityStatusSheet = true
    }
}
