import AuthenticationServices
import SwiftUI

/// Profil performance — identité, progression Process et activité du programme.
struct ProcessProfileView: View {
    @Binding var selectedSection: ProcessMainSection

    @EnvironmentObject private var profileService: UnifiedProfileService
    @EnvironmentObject private var healthManager: HealthManager
    @Bindable private var session = AppSession.shared
    @Bindable private var streakStore = ProcessStreakStore.shared
    @State private var profileStore = SocialProfileStore.shared

    @State private var showSettings = false
    @State private var showUsernameEditor = false
    @State private var showShareSheet = false
    @State private var showReferral = false
    @State private var showPhotoFlow = false
    @State private var photoMenuAnchor: CGPoint = .zero
    @State private var pendingAccountConfirmation: AccountConfirmation?
    @State private var selectedRange: ProfileAnalyticsRange = .week
    @State private var weekOffset = 0
    @State private var profileScrollOffset: CGFloat = 0

    private var avatarCollapseProgress: CGFloat {
        min(1, max(0, -profileScrollOffset / 160))
    }

    private var resolvedProfile: SocialProfile {
        if let profile = profileStore.profile {
            return profile
        }
        if let unified = profileService.currentProfile {
            return SocialProfile.from(unified: unified)
        }
        return .guest
    }

    private var visiblePoints: [ProfileAnalyticsPoint] {
        let all = streakStore.snapshot.month.map { day in
            ProfileAnalyticsPoint(
                id: day.id,
                date: day.date,
                value: day.isComplete
                    ? 100
                    : (day.isToday ? streakStore.snapshot.todayProgress * 100 : 0)
            )
        }

        switch selectedRange {
        case .week:
            let end = max(0, all.count - weekOffset * 7)
            let start = max(0, end - 7)
            return Array(all[start..<end])
        case .month, .all:
            return all
        }
    }

    private var averageRegularity: Int {
        guard !visiblePoints.isEmpty else { return 0 }
        return Int((visiblePoints.map(\.value).reduce(0, +) / Double(visiblePoints.count)).rounded())
    }

    private var previousPeriodAverage: Int? {
        guard selectedRange == .week else { return nil }
        let all = streakStore.snapshot.month
        let currentEnd = max(0, all.count - weekOffset * 7)
        let previousEnd = max(0, currentEnd - 7)
        let previousStart = max(0, previousEnd - 7)
        guard previousEnd - previousStart == 7 else { return nil }
        let values = all[previousStart..<previousEnd].map { $0.isComplete ? 100.0 : 0.0 }
        return Int((values.reduce(0, +) / Double(values.count)).rounded())
    }

    var body: some View {
        ZStack(alignment: .top) {
            ProfilePerformanceBackground()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ProfileScrollOffsetReader()

                    ProfilePerformanceHero(
                        profile: resolvedProfile,
                        totalDays: streakStore.snapshot.totalCompletedDays,
                        streak: streakStore.snapshot.currentStreak,
                        healthScore: healthManager.readinessScore
                    )

                    ProfileRegularitySection(
                        selectedRange: $selectedRange,
                        points: visiblePoints,
                        average: averageRegularity,
                        comparison: previousPeriodAverage.map { averageRegularity - $0 },
                        canGoForward: weekOffset > 0,
                        canGoBackward: selectedRange == .week && weekOffset < 3,
                        onBackward: { moveWeek(by: 1) },
                        onForward: { moveWeek(by: -1) }
                    )
                    .padding(.top, 34)

                    ProfileReferralSection(onOpen: { showReferral = true })
                        .padding(.top, 48)
                        .padding(.bottom, 38)
                }
                .processReportsTabBarScrollOffset()
            }
            .coordinateSpace(name: "profileScroll")
            .ignoresSafeArea(edges: .top)
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .processTransparentScrollSurface()
            .onPreferenceChange(ProfileScrollOffsetPreferenceKey.self) { value in
                profileScrollOffset = value
            }
            .refreshable {
                await refreshProfile()
            }

            ProfilePerformanceStickyTopBar(
                collapseProgress: avatarCollapseProgress,
                onShare: { showShareSheet = true },
                onSettings: {
                    HapticManager.shared.impact(.light)
                    showSettings = true
                }
            )

            ProfilePerformanceFloatingAvatar(
                image: profileStore.profilePhoto,
                collapseProgress: avatarCollapseProgress,
                onPhotoTap: presentPhotoMenu
            )
        }
        .preferredColorScheme(.dark)
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
        .sheet(isPresented: $showShareSheet) {
            ProfileShareSheet(items: [profileStore.shareText])
        }
        .fullScreenCover(isPresented: $showReferral) {
            ProcessReferralProgramView()
                .environmentObject(profileService)
                .processAppPresentationBackground()
        }
        .sheet(isPresented: $showSettings) {
            settingsSheet
        }
        .sheet(isPresented: $showUsernameEditor) {
            NavigationStack {
                ProfileUsernameEditorView(initialValue: resolvedProfile.username)
            }
            .processAppPageBackground()
            .processAppPresentationBackground()
            .environmentObject(profileService)
        }
        .onChange(of: selectedRange) { _, newRange in
            weekOffset = 0
            HapticManager.shared.selection()
            if newRange != .week {
                weekOffset = 0
            }
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
            await refreshProfile()
        }
        .onAppear {
            profileStore.bind(unified: profileService.currentProfile)
            streakStore.reload()
            streakStore.sync(from: WelcomePlanStore.shared.plan)
        }
        .onChange(of: profileService.currentProfile?.userId) { _, _ in
            profileStore.bind(unified: profileService.currentProfile)
        }
    }

    private var settingsSheet: some View {
        NavigationStack {
            EditProfileView(
                onShareProfile: { showShareSheet = true },
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
                    showShareSheet = true
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

    private func presentPhotoMenu(at point: CGPoint) {
        photoMenuAnchor = point
        HapticManager.shared.impact(.light)
        showPhotoFlow = true
    }

    private func moveWeek(by delta: Int) {
        let next = min(3, max(0, weekOffset + delta))
        guard next != weekOffset else { return }
        HapticManager.shared.selection()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            weekOffset = next
        }
    }

    private func refreshProfile() async {
        streakStore.reload()
        streakStore.sync(from: WelcomePlanStore.shared.plan)
        await ProfileHealthSection.refreshAll(force: true)
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
