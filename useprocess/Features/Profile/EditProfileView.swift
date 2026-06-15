import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var profileService: UnifiedProfileService
    @State private var profileStore = SocialProfileStore.shared
    @State private var showPhotoFlow = false

    private var initials: String {
        let profile = profileService.currentProfile
        let first = profile?.firstName.first.map(String.init) ?? "?"
        let last = profile?.lastName?.first.map(String.init) ?? ""
        return (first + last).uppercased()
    }

    var body: some View {
        ZStack {
            ProfileEditTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                editHeader

                ScrollView {
                    VStack(spacing: 0) {
                        ProfileEditAvatarButton(
                            initials: initials,
                            image: profileStore.profilePhoto,
                            action: { showPhotoFlow = true }
                        )

                        editRow(.name)
                        divider
                        editRow(.username)
                        divider
                        editRow(.bio)
                        divider
                        editRow(.education)
                        divider
                        editRow(.interests)
                    }
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .profilePhotoFlow(
            isPresented: $showPhotoFlow,
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
        .onAppear {
            profileStore.bind(unified: profileService.currentProfile)
        }
    }

    private var editHeader: some View {
        ZStack {
            Text("Modifier le profil")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.primary)

            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.primary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 8)
        }
        .padding(.top, 4)
        .padding(.bottom, 6)
    }

    private func editRow(_ destination: ProfileEditDestination) -> some View {
        NavigationLink(value: destination) {
            ProfileEditListRow(
                label: label(for: destination),
                value: value(for: destination),
                placeholder: placeholder(for: destination),
                showsAccentDot: destination == .interests && (profileStore.profile?.interestTags.isEmpty ?? true)
            )
        }
        .buttonStyle(.plain)
    }

    private func label(for destination: ProfileEditDestination) -> String {
        switch destination {
        case .name: "Nom"
        case .username: "Nom d'Utilisateur"
        case .bio: "Bio"
        case .education: "Éducation"
        case .interests: "Intérêts"
        }
    }

    private func placeholder(for destination: ProfileEditDestination) -> String {
        switch destination {
        case .name: "Ton nom"
        case .username: "nom_utilisateur"
        case .bio: "Ajoute ta bio"
        case .education: "Ajoute ton école"
        case .interests: "Ajoute des intérêts"
        }
    }

    private func value(for destination: ProfileEditDestination) -> String? {
        guard let profile = profileStore.profile else { return nil }
        switch destination {
        case .name: return profile.displayName
        case .username: return profile.username
        case .bio: return profile.bio
        case .education: return profile.education
        case .interests:
            return ProfileInterestsCatalog.summary(for: profile.interestTags) ?? profile.interests
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(ProfileEditTheme.separator)
            .frame(height: 1)
            .padding(.leading, 16)
    }
}
