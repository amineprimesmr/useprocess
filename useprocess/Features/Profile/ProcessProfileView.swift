import SwiftUI

/// Page profil — hero edge-to-edge + menu sticky partagé (comme Coach / Santé / Scan).
struct ProcessProfileView: View {
    @Binding var selectedSection: ProcessMainSection

    @EnvironmentObject private var profileService: UnifiedProfileService
    @Bindable private var session = AppSession.shared
    @State private var profileStore = SocialProfileStore.shared
    @State private var showEditProfile = false
    @State private var showShareSheet = false
    @State private var showAddPin = false
    @State private var showPhotoFlow = false
    @State private var newPinTitle = ""
    @State private var newPinEmoji = "📌"
    @State private var pinToRemove: SocialProfilePin?

    private var resolvedProfile: SocialProfile {
        if let profile = profileStore.profile {
            return profile
        }
        if let unified = profileService.currentProfile {
            return SocialProfile.from(unified: unified)
        }
        return .guest
    }

    var body: some View {
        processProfileScrollableChrome(selectedSection: $selectedSection) {
            profileContent(resolvedProfile)
                .frame(maxWidth: .infinity)
        }
        .reportsProfileSubrouteActive(showEditProfile)
        .background(ProfileTheme.background.ignoresSafeArea())
        .profilePhotoFlow(
            isPresented: $showPhotoFlow,
            hasExistingPhoto: profileStore.hasCoverPhoto,
            onApply: { image in
                withAnimation(ProfileTheme.spring) {
                    profileStore.applyPhotos(image)
                }
            },
            onDelete: {
                withAnimation(ProfileTheme.spring) {
                    profileStore.removeAllPhotos()
                }
            }
        )
        .sheet(isPresented: $showShareSheet) {
            ProfileShareSheet(items: [profileStore.shareText])
        }
        .sheet(isPresented: $showEditProfile) {
            NavigationStack {
                EditProfileView()
                    .navigationDestination(for: ProfileEditDestination.self) { destination in
                        profileFieldEditor(for: destination)
                    }
            }
            .environmentObject(profileService)
            .environmentObject(AuthenticationManager.shared)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(AccountDetailsTheme.pageBackground)
        }
        .onChange(of: session.hasCompletedOnboarding) { _, completed in
            if !completed {
                showEditProfile = false
            }
        }
        .sheet(isPresented: $showAddPin) {
            ProfileAddPinSheet(title: $newPinTitle, emoji: $newPinEmoji) {
                let title = newPinTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty else { return }
                withAnimation(ProfileTheme.spring) {
                    profileStore.addPin(title: title, emoji: newPinEmoji.isEmpty ? "📌" : newPinEmoji)
                }
                newPinTitle = ""
                newPinEmoji = "📌"
            }
        }
        .confirmationDialog("Supprimer ce pin ?", isPresented: .init(
            get: { pinToRemove != nil },
            set: { if !$0 { pinToRemove = nil } }
        )) {
            Button("Supprimer", role: .destructive) {
                if let pin = pinToRemove {
                    withAnimation(ProfileTheme.spring) {
                        profileStore.removePin(pin.id)
                    }
                }
                pinToRemove = nil
            }
        }
        .task(id: profileService.currentProfile?.userId) {
            if profileService.currentProfile == nil {
                await profileService.loadProfile()
            }
            profileStore.bind(unified: profileService.currentProfile)
        }
        .onAppear {
            profileStore.bind(unified: profileService.currentProfile)
        }
        .onChange(of: profileService.currentProfile?.userId) { _, _ in
            profileStore.bind(unified: profileService.currentProfile)
        }
    }

    @ViewBuilder
    private func profileContent(_ profile: SocialProfile) -> some View {
        if profileStore.hasCoverPhoto, let cover = profileStore.coverPhoto {
            ProfileCoverPhotoSection(
                image: cover,
                displayName: profile.displayName,
                isPrivate: profile.isPrivate
            )
            .transition(.opacity.combined(with: .scale(scale: 0.985)))
        } else {
            ProfileEmptyHeroSection(onAddPhoto: { showPhotoFlow = true })
                .transition(.opacity.combined(with: .scale(scale: 0.985)))
        }

        VStack(alignment: .leading, spacing: 14) {
            if !profileStore.hasCoverPhoto {
                ProfileIdentityBlock(
                    displayName: profile.displayName,
                    isPrivate: profile.isPrivate
                )
                .padding(.top, 8)
            }

            ProfileActionButtons(
                onShare: { showShareSheet = true },
                onEdit: { showEditProfile = true }
            )

            WelcomePlanProfileSection()

            if let bio = profile.bio, !bio.isEmpty {
                Text(bio)
                    .font(.system(size: 15))
                    .foregroundStyle(ProfileTheme.textSecondary)
            }

            ProfilePinsSection(
                pins: profile.pins,
                onAdd: { showAddPin = true },
                onRemove: { pin in pinToRemove = pin }
            )
        }
        .padding(.horizontal, ProfileTheme.horizontalPadding)
        .padding(.bottom, 32)
        .safeAreaPadding(.bottom, 8)
    }
}
