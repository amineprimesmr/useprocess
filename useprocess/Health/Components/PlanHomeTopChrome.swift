import SwiftUI

/// En-tête accueil Plan — salutation + cluster glass streak / profil.
struct PlanHomeTopChrome: View {
    @Binding var selectedSection: ProcessMainSection
    @Binding var selectedDate: Date

    @EnvironmentObject private var profileService: UnifiedProfileService
    @Environment(\.appTheme) private var theme

    @State private var profileStore = SocialProfileStore.shared
    @Bindable private var streakStore = ProcessStreakStore.shared
    @Bindable private var planStore = WelcomePlanStore.shared
    @State private var faceHistoryStore = FaceScanHistoryStore.shared
    @State private var showStreakSheet = false
    @Namespace private var streakZoomNamespace

    private var greetingFirstName: String {
        profileService.currentProfile?.firstName
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var avatarInitials: String {
        let name: String = {
            if let displayName = profileStore.profile?.displayName,
               !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return displayName
            }
            if let profile = profileService.currentProfile {
                let parts = [profile.firstName, profile.lastName ?? ""]
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                if !parts.isEmpty {
                    return parts.joined(separator: " ")
                }
            }
            return "?"
        }()

        let parts = name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? "?"
        let last = parts.dropFirst().first?.first.map(String.init) ?? ""
        return (first + last).uppercased()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            PlanHomeGreetingLabel(
                greeting: homeGreeting,
                isActive: selectedSection == .plan
            )
                .frame(maxWidth: .infinity, alignment: .leading)

            profileStreakCluster
        }
        .padding(.top, 14)
        .padding(.bottom, 4)
        .fullScreenCover(isPresented: $showStreakSheet) {
            ProcessStreakSheet(selectedDate: $selectedDate)
                .processZoomTransition(id: .streak, namespace: streakZoomNamespace)
        }
        .onAppear {
            profileStore.bind(unified: profileService.currentProfile)
            streakStore.sync(from: planStore.plan)
            faceHistoryStore = FaceScanHistoryStore.shared
        }
        .onChange(of: profileService.currentProfile?.userId) { _, _ in
            profileStore.bind(unified: profileService.currentProfile)
            streakStore.reload()
            streakStore.sync(from: planStore.plan)
            faceHistoryStore = FaceScanHistoryStore.shared
        }
        .onChange(of: planStore.plan?.lastUpdated) { _, _ in
            streakStore.sync(from: planStore.plan)
        }
        .onChange(of: selectedDate) { _, _ in
            faceHistoryStore = FaceScanHistoryStore.shared
        }
    }

    private var homeGreeting: PlanHomeGreeting {
        PlanHomeGreetingBuilder.make(
            firstName: greetingFirstName,
            selectedDate: selectedDate,
            plan: planStore.plan,
            isScanDue: faceHistoryStore.isScanDue,
            hasAnyFaceScan: faceHistoryStore.latestResult != nil
        )
    }

    private enum GlassClusterMetrics {
        static let streakTileWidth: CGFloat = 54
        static let tileSize: CGFloat = 50
        static let photoSize: CGFloat = 36
        static let spacing: CGFloat = 22
        static let mergeOffset: CGFloat = -22
        static let iconSize: CGFloat = 15
        static let initialsSize: CGFloat = 13
    }

    @ViewBuilder
    private var profileStreakCluster: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: GlassClusterMetrics.spacing) {
                HStack(spacing: GlassClusterMetrics.spacing) {
                    Button(action: openStreak) {
                        streakGlassTile
                            .processZoomSource(id: .streak, namespace: streakZoomNamespace)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Streak, \(streakStore.displayStreak) jours")

                    Button(action: openProfile) {
                        profileGlassTile
                    }
                    .buttonStyle(.plain)
                    .offset(x: GlassClusterMetrics.mergeOffset, y: 0.0)
                    .accessibilityLabel("Profil")
                }
            }
        } else {
            HStack(spacing: 10) {
                Button(action: openStreak) {
                    legacyStreakButton
                        .processZoomSource(id: .streak, namespace: streakZoomNamespace)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Streak, \(streakStore.displayStreak) jours")

                legacyProfileButton
            }
        }
    }

    @available(iOS 26.0, *)
    private var streakGlassTile: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.system(size: GlassClusterMetrics.iconSize, weight: .semibold))
                .foregroundStyle(streakFlameColor)

            Text("\(streakStore.displayStreak)")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(theme.primaryText)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(width: GlassClusterMetrics.streakTileWidth, height: GlassClusterMetrics.tileSize)
        .glassEffect()
    }

    @available(iOS 26.0, *)
    private var profileGlassTile: some View {
        profileAvatarContent(
            size: GlassClusterMetrics.photoSize,
            initialsSize: GlassClusterMetrics.initialsSize
        )
        .frame(width: GlassClusterMetrics.tileSize, height: GlassClusterMetrics.tileSize)
        .glassEffect()
    }

    private var legacyStreakButton: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(streakFlameColor)
            Text("\(streakStore.displayStreak)")
                .font(.system(size: 15, weight: .bold))
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .processGlassCircle(interactive: true)
    }

    private var legacyProfileButton: some View {
        Button(action: openProfile) {
            profileAvatar(size: 40)
        }
        .buttonStyle(.plain)
        .processGlassCircle(interactive: true)
        .accessibilityLabel("Profil")
    }

    private var streakFlameColor: Color {
        streakStore.displayStreak > 0 ? ProcessStreakPalette.flame : theme.secondaryText.opacity(0.65)
    }

    @ViewBuilder
    private func profileAvatar(size: CGFloat) -> some View {
        profileAvatarContent(size: size, initialsSize: size * 0.34)
    }

    @ViewBuilder
    private func profileAvatarContent(size: CGFloat, initialsSize: CGFloat) -> some View {
        Group {
            if let image = profileStore.profilePhoto {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle().fill(ProfileTheme.avatarAccent)
                    Text(avatarInitials.prefix(2))
                        .font(.system(size: initialsSize, weight: .bold))
                        .foregroundStyle(.white.opacity(0.95))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private func openProfile() {
        HapticManager.shared.impact(.light)
        withAnimation(ProcessGlass.spring) {
            selectedSection = .profile
        }
    }

    private func openStreak() {
        HapticManager.shared.impact(.light)
        streakStore.sync(from: planStore.plan)
        showStreakSheet = true
    }
}

// MARK: - Salutation accueil

private struct PlanHomeGreetingLabel: View {
    let greeting: PlanHomeGreeting
    let isActive: Bool

    @Environment(\.appTheme) private var theme

    @State private var typewriter = CoachTypewriterController()
    @State private var showsEmoji = false
    @State private var textVisible = false
    @State private var hasPlayedLaunchGreeting = false

    private var greetingLine: String { greeting.line }

    private var greetingTaskID: String {
        "\(isActive)|\(greetingLine)|\(greeting.emoji)|played:\(hasPlayedLaunchGreeting)"
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            ZStack(alignment: .leading) {
                Text(greetingLine)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.clear)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .accessibilityHidden(true)

                Text(typewriter.displayedText)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .opacity(textVisible ? 1 : 0)
                    .offset(y: textVisible ? 0 : 8)
                    .blur(radius: textVisible ? 0 : 6)
            }

            Text(greeting.emoji)
                .font(.system(size: 24))
                .opacity(showsEmoji ? 1 : 0)
                .scaleEffect(showsEmoji ? 1 : 0.35)
                .rotationEffect(.degrees(showsEmoji ? 0 : -18))
                .offset(y: showsEmoji ? 0 : 6)
                .animation(.spring(response: 0.42, dampingFraction: 0.62), value: showsEmoji)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(greetingLine)
        .task(id: greetingTaskID) {
            guard isActive else {
                stopGreetingAnimation()
                return
            }

            if hasPlayedLaunchGreeting {
                showGreetingImmediately()
                return
            }

            await runLaunchGreetingAnimation()
            if !Task.isCancelled && isActive {
                hasPlayedLaunchGreeting = true
            }
        }
        .onDisappear {
            stopGreetingAnimation()
        }
    }

    private func showGreetingImmediately() {
        typewriter.showImmediately(text: greetingLine)
        textVisible = true
        showsEmoji = true
    }

    private func stopGreetingAnimation() {
        typewriter.reset()
        HapticManager.shared.endTypewriterSession()
    }

    private func runLaunchGreetingAnimation() async {
        showsEmoji = false
        textVisible = false
        typewriter.reset()

        try? await Task.sleep(nanoseconds: 280_000_000)
        guard !Task.isCancelled, isActive else { return }

        withAnimation(.spring(response: 0.52, dampingFraction: 0.84)) {
            textVisible = true
        }

        try? await Task.sleep(nanoseconds: 120_000_000)
        guard !Task.isCancelled, isActive else { return }

        await typewriter.run(text: greetingLine, leadingDelayNanoseconds: 0)

        guard !Task.isCancelled, isActive else { return }
        try? await Task.sleep(nanoseconds: 90_000_000)
        guard !Task.isCancelled, isActive else { return }

        withAnimation(.spring(response: 0.42, dampingFraction: 0.62)) {
            showsEmoji = true
        }
    }
}
