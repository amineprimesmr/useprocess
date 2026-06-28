import SwiftUI

/// Hub paramètres — catégories + sous-pages.
struct EditProfileView: View {
    var onShareProfile: () -> Void = {}
    var onLogout: () -> Void = {}
    var onDeleteConfirmed: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var profileService: UnifiedProfileService
    @State private var profileStore = SocialProfileStore.shared
    @State private var showPhotoFlow = false
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

    private var fullName: String {
        if let profile {
            return profile.fullName
        }
        return profileStore.profile?.displayName ?? "Mon profil"
    }

    var body: some View {
        VStack(spacing: 0) {
                AccountDetailsGlassHeader(
                    title: "Paramètres",
                    onBack: { dismiss() },
                    onSave: { dismiss() },
                    saveDisabled: true
                )

                ScrollView {
                    VStack(spacing: 0) {
                        AccountDetailsAvatarSection(
                            fullName: fullName,
                            initials: initials,
                            image: profileStore.profilePhoto,
                            onChangePhoto: { showPhotoFlow = true }
                        )

                        ProfileSummarySectionHeader(title: "Sections")

                        AccountDetailsCard {
                            ForEach(Array(ProfileSettingsCategory.allCases.enumerated()), id: \.element.id) { index, category in
                                Group {
                                    if index > 0 {
                                        Color.clear.frame(height: AccountDetailsTheme.rowSpacing)
                                    }
                                    NavigationLink(value: category) {
                                        AccountDetailsGlassRow {
                                            ProfileSettingsCategoryHubRow(category: category)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal, AccountDetailsTheme.horizontalPadding)

                        VStack(spacing: AccountDetailsTheme.rowSpacing) {
                            AccountDetailsActionButton(title: "Se déconnecter") {
                                onLogout()
                            }

                            AccountDeleteAnimatedButton {
                                onDeleteConfirmed()
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
        .navigationDestination(for: ProfileSettingsCategory.self) { category in
            profileSettingsDetail(for: category, onShareProfile: onShareProfile)
        }
        .profilePhotoFlow(
            isPresented: $showPhotoFlow,
            menuAnchor: photoMenuAnchor,
            hasExistingPhoto: profileStore.hasProfilePhoto,
            onApply: { image in
                withAnimation(ProfileEditTheme.spring) {
                    profileStore.applyPhotos(image)
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
        }
    }
}
