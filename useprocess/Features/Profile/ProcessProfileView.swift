import AuthenticationServices
import SwiftUI

/// Profil — hero photo, poids, rétention et parrainage.
struct ProcessProfileView: View {
    @Binding var selectedSection: ProcessMainSection

    @EnvironmentObject private var profileService: UnifiedProfileService
    @EnvironmentObject private var healthManager: HealthManager
    @Bindable private var session = AppSession.shared
    @Bindable private var streakStore = ProcessStreakStore.shared
    @State private var profileStore = SocialProfileStore.shared

    @State private var showSettings = false
    @State private var showReferral = false
    @State private var showUsernameEditor = false
    @State private var showPhotoFlow = false
    @State private var photoMenuAnchor: CGPoint = .zero
    @State private var pendingAccountConfirmation: AccountConfirmation?

    @State private var weightHistory: [ProfileAnalyticsPoint] = []
    @State private var retentionHistory: [ProfileAnalyticsPoint] = []

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
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 0) {
                    profileHero(resolvedProfile)
                        .animation(ProfileTheme.spring, value: profileStore.profile?.coverPhotoFilename)

                    profileScrollContent(resolvedProfile)
                }
                .processReportsTabBarScrollOffset()
            }
            .coordinateSpace(name: "processMainScroll")
            .scrollClipDisabled()
            .ignoresSafeArea(edges: .top)
            .scrollIndicators(.hidden)
            .processTransparentScrollSurface()

            profileTopChrome
                .padding(.top, ProcessMainChromeMetrics.topSafeInset + ProfileTopChromeMetrics.topPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .processClearUIKitHostingBackground()
        .refreshable {
            await refreshProfile(forceHealthRefresh: true)
        }
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
            await refreshProfile(forceHealthRefresh: false)
        }
        .onAppear {
            ProcessPerformanceTrace.endProfileOpen()
            Task { await reloadChartHistories() }
        }
        .onChange(of: profileService.currentProfile?.userId) { _, _ in
            profileStore.bind(unified: profileService.currentProfile)
        }
    }

    @ViewBuilder
    private func profileHero(_ profile: SocialProfile) -> some View {
        if profileStore.hasCoverPhoto, let cover = profileStore.coverPhoto {
            ProfileCoverPhotoSection(
                image: cover,
                displayName: profile.displayName,
                username: profile.username,
                isPrivate: profile.isPrivate,
                onPhotoTap: { presentPhotoMenu(at: $0) },
                onEditUsername: { showUsernameEditor = true }
            )
            .transition(.opacity.combined(with: .scale(scale: 0.985)))
        } else {
            ProfileEmptyHeroSection(onPhotoTap: { presentPhotoMenu(at: $0) })
                .transition(.opacity.combined(with: .scale(scale: 0.985)))
        }
    }

    private var profileTopChrome: some View {
        HStack {
            Spacer(minLength: 0)

            ProfileTopChromeActionButton(
                systemName: "gearshape.fill",
                accessibilityLabel: "Paramètres"
            ) {
                openSettings()
            }
        }
        .padding(.horizontal, ProfileTopChromeMetrics.horizontalPadding)
    }

    @ViewBuilder
    private func profileScrollContent(_ profile: SocialProfile) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            if !profileStore.hasCoverPhoto {
                ProfileIdentityBlock(
                    displayName: profile.displayName,
                    username: profile.username,
                    isPrivate: profile.isPrivate,
                    onEditUsername: { showUsernameEditor = true }
                )
            }

            ProfileMetricChartSection(
                metric: .weight,
                points: chartPoints(for: .weight),
                latestValue: latestValue(for: .weight),
                deltaVsPrevious: deltaVsPrevious(for: .weight)
            )

            ProfileMetricChartSection(
                metric: .retention,
                points: chartPoints(for: .retention),
                latestValue: latestValue(for: .retention),
                deltaVsPrevious: deltaVsPrevious(for: .retention)
            )

            ProfileActionButtons(onReferral: { showReferral = true })
        }
        .padding(.horizontal, ProfileTheme.horizontalPadding)
        .padding(.top, 20)
        .padding(.bottom, 32)
        .safeAreaPadding(.bottom, 8)
    }

    private var settingsSheet: some View {
        NavigationStack {
            EditProfileView(
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
                profileSettingsDetail(for: category, onShareProfile: {})
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

    private func history(for metric: ProfileChartMetric) -> [ProfileAnalyticsPoint] {
        switch metric {
        case .weight: return weightHistory
        case .retention: return retentionHistory
        }
    }

    private func chartPoints(for metric: ProfileChartMetric) -> [ProfileAnalyticsPoint] {
        let points = ProfileChartHistoryBuilder.visiblePoints(
            history: history(for: metric),
            range: .profileDefault,
            weekOffset: 0
        )
        if !points.isEmpty { return points }
        return fallbackChartPoints(for: metric)
    }

    private func fallbackChartPoints(for metric: ProfileChartMetric) -> [ProfileAnalyticsPoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        switch metric {
        case .weight:
            if healthManager.todaySnapshot.vitals.bodyMass > 0 {
                return [
                    ProfileAnalyticsPoint(
                        id: "weight-today",
                        date: today,
                        value: healthManager.todaySnapshot.vitals.bodyMass
                    )
                ]
            }
            let profileWeight = profileService.currentProfile?.weight ?? 0
            if profileWeight > 0 {
                return [
                    ProfileAnalyticsPoint(
                        id: "profile-weight",
                        date: today,
                        value: profileWeight
                    )
                ]
            }

        case .retention:
            if let latest = FaceScanHistoryStore.shared.latestResult {
                let value = Double(FaceScanIndicators.displayPercent(for: .retention, result: latest))
                if value > 0 {
                    return [
                        ProfileAnalyticsPoint(
                            id: "retention-latest",
                            date: calendar.startOfDay(for: latest.createdAt),
                            value: value
                        )
                    ]
                }
            }
        }

        return []
    }

    private func latestValue(for metric: ProfileChartMetric) -> Double? {
        chartPoints(for: metric).last?.value
    }

    private func deltaVsPrevious(for metric: ProfileChartMetric) -> Double? {
        let currentAverage = ProfileChartHistoryBuilder.average(
            in: ProfileChartHistoryBuilder.visiblePoints(
                history: history(for: metric),
                range: .week,
                weekOffset: 0
            )
        )
        let previousAverage = ProfileChartHistoryBuilder.previousPeriodAverage(
            history: history(for: metric),
            range: .week,
            weekOffset: 0
        )

        guard let currentAverage, let previousAverage else { return nil }
        return currentAverage - previousAverage
    }

    private func openSettings() {
        HapticManager.shared.impact(.light)
        showSettings = true
    }

    private func presentPhotoMenu(at point: CGPoint) {
        photoMenuAnchor = point
        HapticManager.shared.impact(.light)
        showPhotoFlow = true
    }

    private func refreshProfile(forceHealthRefresh: Bool) async {
        streakStore.reload()
        streakStore.sync(from: WelcomePlanStore.shared.plan)
        if forceHealthRefresh {
            await ProfileHealthSection.refreshAll(force: true)
        }
        await reloadChartHistories()
    }

    private func reloadChartHistories() async {
        FaceScanHistoryStore.shared.reloadForUser(userId: profileService.currentProfile?.userId)

        let weightSamples = await healthManager.fetchBodyMassHistory(days: 90)
        let profileWeight = profileService.currentProfile?.weight ?? 0

        weightHistory = ProfileChartHistoryBuilder.mergeWithProfileFallback(
            history: weightSamples,
            profileWeight: profileWeight
        )
        retentionHistory = ProfileChartHistoryBuilder.retentionHistory(
            from: FaceScanHistoryStore.shared.history
        )
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
