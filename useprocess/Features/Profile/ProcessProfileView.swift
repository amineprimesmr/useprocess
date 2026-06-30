import AuthenticationServices
import SwiftUI

/// Page profil — identité + santé (données Apple Santé).
struct ProcessProfileView: View {
    @Binding var selectedSection: ProcessMainSection

    @EnvironmentObject private var profileService: UnifiedProfileService
    @EnvironmentObject private var healthManager: HealthManager
    @Bindable private var session = AppSession.shared
    @State private var profileStore = SocialProfileStore.shared
    @State private var showSettings = false
    @State private var showUsernameEditor = false
    @State private var showShareSheetFromSettings = false
    @State private var showReferral = false
    @State private var showPhotoFlow = false
    @State private var photoMenuAnchor: CGPoint = .zero
    @State private var pendingAccountConfirmation: AccountConfirmation?

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
        ZStack {
            ProcessScreenBackground()

            ScrollView {
                VStack(spacing: 0) {
                    profileHeaderBlock(resolvedProfile)
                        .id("profileTop")

                    profileScrollContent(resolvedProfile)
                }
                .processReportsTabBarScrollOffset()
            }
            .coordinateSpace(name: "profileScroll")
            .scrollClipDisabled()
            .ignoresSafeArea(edges: .top)
            .scrollIndicators(.hidden)
            .processTransparentScrollSurface()
        }
        .refreshable {
            await ProfileHealthSection.refreshAll(force: true)
        }
        .processClearUIKitHostingBackground()
        .reportsProfileSubrouteActive(showSettings)
        .profilePhotoFlow(
            isPresented: $showPhotoFlow,
            menuAnchor: photoMenuAnchor,
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
        .sheet(isPresented: $showShareSheetFromSettings) {
            ProfileShareSheet(items: [profileStore.shareText])
        }
        .fullScreenCover(isPresented: $showReferral) {
            ProcessReferralProgramView()
                .environmentObject(profileService)
                .processAppPresentationBackground()
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                EditProfileView(
                    onShareProfile: {
                        showShareSheetFromSettings = true
                    },
                    onLogout: { pendingAccountConfirmation = .logout },
                    onDeleteConfirmed: {
                        Task { @MainActor in
                            showSettings = false
                            try? await Task.sleep(for: .milliseconds(450))
                            await performAccountDeletion()
                        }
                    }
                )
                .navigationDestination(for: ProfileEditDestination.self) { destination in
                    profileFieldEditor(for: destination)
                }
                .navigationDestination(for: ProfileSettingsCategory.self) { category in
                    profileSettingsDetail(for: category, onShareProfile: {
                        showShareSheetFromSettings = true
                    })
                }
            }
            .processAppPageBackground()
            .environmentObject(profileService)
            .environmentObject(AuthenticationManager.shared)
            .environmentObject(healthManager)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground {
                ProcessScreenBackground()
            }
            .alert(
                "Se déconnecter ?",
                isPresented: Binding(
                    get: { pendingAccountConfirmation == .logout },
                    set: { if !$0 { pendingAccountConfirmation = nil } }
                )
            ) {
                Button("Se déconnecter", role: .destructive) {
                    pendingAccountConfirmation = nil
                    AuthenticationManager.shared.signOut()
                    showSettings = false
                }
                Button("Annuler", role: .cancel) {
                    pendingAccountConfirmation = nil
                }
            } message: {
                Text("Tu pourras te reconnecter à tout moment.")
            }
        }
        .sheet(isPresented: $showUsernameEditor) {
            NavigationStack {
                ProfileUsernameEditorView(
                    initialValue: resolvedProfile.username
                )
            }
            .processAppPageBackground()
            .processAppPresentationBackground()
            .environmentObject(profileService)
        }
        .onChange(of: session.hasCompletedOnboarding) { _, completed in
            if !completed {
                showSettings = false
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

    private var profileTopChrome: some View {
        HStack {
            Spacer(minLength: 0)

            ProfileTopChromeActionButton(
                systemName: "gearshape.fill",
                accessibilityLabel: "Paramètres"
            ) {
                HapticManager.shared.impact(.light)
                showSettings = true
            }
        }
        .padding(.horizontal, ProfileTopChromeMetrics.horizontalPadding)
    }

    @ViewBuilder
    private func profileHeaderBlock(_ profile: SocialProfile) -> some View {
        ZStack(alignment: .top) {
            profileHero(profile)

            profileTopChrome
                .padding(.top, ProcessMainChromeMetrics.topSafeInset + ProfileTopChromeMetrics.topPadding)
                .zIndex(1)
        }
        .frame(maxWidth: .infinity)
    }

    private func presentPhotoMenu(at anchor: CGPoint) {
        photoMenuAnchor = anchor
        showPhotoFlow = true
    }

    @ViewBuilder
    private func profileHero(_ profile: SocialProfile) -> some View {
        if profileStore.hasCoverPhoto, let cover = profileStore.coverPhoto {
            ProfileCoverPhotoSection(
                image: cover,
                displayName: profile.displayName,
                username: profile.username,
                isPrivate: profile.isPrivate,
                onPhotoTap: { point in
                    presentPhotoMenu(at: point)
                },
                onEditUsername: { showUsernameEditor = true }
            )
        } else {
            ProfileEmptyHeroSection(onPhotoTap: { point in
                presentPhotoMenu(at: point)
            })
        }
    }

    @ViewBuilder
    private func profileScrollContent(_ profile: SocialProfile) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            if !profileStore.hasCoverPhoto {
                ProfileIdentityBlock(
                    displayName: profile.displayName,
                    username: profile.username,
                    isPrivate: profile.isPrivate,
                    onEditUsername: { showUsernameEditor = true }
                )
                .padding(.top, 8)
            }

            ProfileActionButtons(onReferral: { showReferral = true })

            if let bio = profile.bio, !bio.isEmpty {
                Text(bio)
                    .font(.system(size: 15))
                    .foregroundStyle(ProfileTheme.textSecondary)
            }

            ProfileHealthSection()

            LiquidTransitionCard()
                .padding(.top, 8)
        }
        .padding(.horizontal, ProfileTheme.horizontalPadding)
        .padding(.top, 20)
        .padding(.bottom, 32)
        .safeAreaPadding(.bottom, 8)
    }

    private func performAccountDeletion() async {
        session.accountDeletionErrorMessage = nil

        do {
            try await session.deleteAccount()
        } catch let error as AccountDeletionError {
            if case .cancelled = error { return }
            session.accountDeletionErrorMessage = error.localizedDescription
        } catch {
            session.accountDeletionErrorMessage = error.localizedDescription
        }
    }
}
