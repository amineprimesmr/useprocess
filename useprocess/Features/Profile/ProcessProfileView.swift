import AuthenticationServices
import SwiftUI

/// Page streak — flamme, calendrier de série, historique des scans. Rien d'autre.
struct ProcessProfileView: View {
    @Binding var selectedSection: ProcessMainSection
    var isTabActive: Bool = true
    var isOnboardingPreview: Bool = false
    var showsCloseButton: Bool = true

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var profileService: UnifiedProfileService
    @Bindable private var faceHistoryStore = FaceScanHistoryStore.shared
    @State private var profileStore = SocialProfileStore.shared

    @State private var selectedAnalysisScan: FaceScanResult?
    @State private var selectedProfileDate = Calendar.current.startOfDay(for: Date())
    @ObservedObject private var creatorMode = ProcessCreatorModeStore.shared

    private var isFlamePlaybackActive: Bool {
        isTabActive && scenePhase == .active
    }

    var body: some View {
        streakScroll
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .processAppPageBackground()
        .background {
            if colorScheme == .dark {
                Color.black.ignoresSafeArea()
            }
        }
        .fullScreenCover(item: $selectedAnalysisScan) { scan in
            FaceScanResultContent(
                result: scan,
                previous: previousScan(before: scan),
                history: faceHistoryStore.history
            )
        }
        .task(id: profileService.currentProfile?.userId) {
            guard !isOnboardingPreview else { return }
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            if profileService.currentProfile == nil {
                await profileService.loadProfile()
            }
            profileStore.bind(unified: profileService.currentProfile)
            ProcessDebloatTrajectoryStore.shared.sync(from: WelcomePlanStore.shared.plan)
            ProcessPlanProgressStore.shared.reload(plan: WelcomePlanStore.shared.plan)
            FaceScanHistoryStore.shared.reloadForUser(userId: profileService.currentProfile?.userId)
        }
        .onAppear {
            guard !isOnboardingPreview else { return }
            ProcessPerformanceTrace.endProfileOpen()
            ProcessDebloatTrajectoryStore.shared.reload()
            ProcessDebloatTrajectoryStore.shared.sync(from: WelcomePlanStore.shared.plan)
            ProcessPlanProgressStore.shared.reload(plan: WelcomePlanStore.shared.plan)
        }
        .onChange(of: profileService.currentProfile?.userId) { _, _ in
            profileStore.bind(unified: profileService.currentProfile)
        }
    }

    private var streakScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                // VStack (pas LazyVStack) en tête : TimelineView de la flamme doit rester actif.
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: 0)
                        .id(ProfileOnboardingPreviewTopAnchor.id)

                    ProfileStreakAchievementsSection(
                        selectedDate: $selectedProfileDate,
                        isPlaybackActive: isFlamePlaybackActive,
                        isOnboardingPreview: isOnboardingPreview,
                        showsSectionHeader: true,
                        onClose: (isOnboardingPreview || !showsCloseButton) ? nil : { dismiss() }
                    )
                }
                .frame(maxWidth: .infinity, alignment: .top)
                .processReportsTabBarScrollOffset()
            }
            .coordinateSpace(name: "processMainScroll")
            .scrollIndicators(.hidden)
            .modifier(ProcessProfileTabBarAdoption(enabled: !isOnboardingPreview))
            .processTransparentScrollSurface()
            .simultaneousGesture(profileDaySwipeGesture)
            .onAppear {
                selectedProfileDate = Calendar.current.startOfDay(for: creatorMode.effectiveNow)
                if isOnboardingPreview {
                    bootstrapOnboardingPreview()
                    focusOnboardingPreviewStreakTop(using: proxy)
                }
            }
            .onChange(of: isTabActive) { _, active in
                guard isOnboardingPreview, active else { return }
                bootstrapOnboardingPreview()
                focusOnboardingPreviewStreakTop(using: proxy)
            }
        }
    }

    private struct ProcessProfileTabBarAdoption: ViewModifier {
        let enabled: Bool

        func body(content: Content) -> some View {
            if enabled {
                content.processAdoptForIGTabBar()
            } else {
                content
            }
        }
    }

    private func focusOnboardingPreviewStreakTop(using proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            proxy.scrollTo(ProfileOnboardingPreviewTopAnchor.id, anchor: .top)
        }
    }

    private func bootstrapOnboardingPreview() {
        ProcessDebloatTrajectoryStore.shared.reload()
        ProcessDebloatTrajectoryStore.shared.sync(from: WelcomePlanStore.shared.plan)
        ProcessPlanProgressStore.shared.reload(plan: WelcomePlanStore.shared.plan)
        ProcessStreakStore.shared.sync(from: WelcomePlanStore.shared.plan)
    }

    private func previousScan(before scan: FaceScanResult) -> FaceScanResult? {
        let ordered = faceHistoryStore.history
        guard let index = ordered.firstIndex(where: { $0.id == scan.id }),
              index + 1 < ordered.count else { return nil }
        return ordered[index + 1]
    }

    private var profileDaySwipeGesture: some Gesture {
        DragGesture(minimumDistance: 28, coordinateSpace: .local)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) > 70, abs(horizontal) > abs(vertical) * 1.2 else { return }

                if horizontal < 0 {
                    moveSelectedProfileDate(by: -1)
                } else {
                    moveSelectedProfileDate(by: 1)
                }
            }
    }

    private func moveSelectedProfileDate(by dayDelta: Int) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: creatorMode.effectiveNow)
        let current = calendar.startOfDay(for: selectedProfileDate)
        guard let candidate = calendar.date(byAdding: .day, value: dayDelta, to: current) else { return }
        let minDate = earliestSelectableProfileDate(calendar: calendar, today: today)
        let clamped = max(min(candidate, today), minDate)
        guard clamped != selectedProfileDate else { return }

        HapticManager.shared.selection()
        selectedProfileDate = clamped
    }

    private func earliestSelectableProfileDate(calendar: Calendar, today: Date) -> Date {
        if let startedAt = WelcomePlanStore.shared.plan?.calendar.startedAt {
            return calendar.startOfDay(for: startedAt)
        }

        let scanDates = faceHistoryStore.history
            .map { calendar.startOfDay(for: $0.createdAt) }

        if let earliest = scanDates.min() {
            return earliest
        }

        return calendar.date(byAdding: .day, value: -30, to: today) ?? today
    }
}

private enum ProfileOnboardingPreviewTopAnchor {
    static let id = "profileOnboardingPreviewTop"
}
