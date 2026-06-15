import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var profileService: UnifiedProfileService
    @State private var profileStore = SocialProfileStore.shared
    @State private var showPhotoFlow = false

    private var profile: UnifiedUserProfile? {
        profileService.currentProfile
    }

    private var sections: [ProfileSummarySection] {
        UserProfileOnboardingSummary.sections(from: profile)
    }

    private var initials: String {
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

                        if sections.isEmpty {
                            emptyState
                        } else {
                            profileSections
                        }
                    }
                    .padding(.bottom, 32)
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

    private var profileSections: some View {
        ForEach(sections) { section in
            VStack(spacing: 0) {
                ProfileSummarySectionHeader(title: section.title)

                ForEach(Array(section.rows.enumerated()), id: \.element.id) { index, item in
                    if item.isEditable {
                        NavigationLink(value: ProfileEditDestination.firstName) {
                            ProfileEditListRow(
                                label: item.label,
                                value: item.value,
                                placeholder: "Non renseigné"
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        ProfileSummaryInfoRow(item: item)
                    }

                    if index < section.rows.count - 1 {
                        divider
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("Aucune donnée onboarding")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.primary)
            Text("Termine l'onboarding pour voir ici ton profil personnalisé.")
                .font(.system(size: 15))
                .foregroundStyle(ProfileEditTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
        }
        .padding(.vertical, 36)
    }

    private var editHeader: some View {
        ZStack {
            Text("Mon profil")
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

    private var divider: some View {
        Rectangle()
            .fill(ProfileEditTheme.separator)
            .frame(height: 1)
            .padding(.leading, 16)
    }
}
