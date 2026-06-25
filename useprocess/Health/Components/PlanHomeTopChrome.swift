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
    @State private var showStreakSheet = false

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
            PlanHomeGreetingLabel(firstName: greetingFirstName)
                .frame(maxWidth: .infinity, alignment: .leading)

            profileStreakCluster
        }
        .padding(.top, 14)
        .padding(.bottom, 4)
        .fullScreenCover(isPresented: $showStreakSheet) {
            ProcessStreakSheet(selectedDate: $selectedDate)
        }
        .onAppear {
            profileStore.bind(unified: profileService.currentProfile)
            streakStore.sync(from: planStore.plan)
        }
        .onChange(of: profileService.currentProfile?.userId) { _, _ in
            profileStore.bind(unified: profileService.currentProfile)
            streakStore.reload()
            streakStore.sync(from: planStore.plan)
        }
        .onChange(of: planStore.plan?.lastUpdated) { _, _ in
            streakStore.sync(from: planStore.plan)
        }
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
    let firstName: String

    @Environment(\.appTheme) private var theme

    @State private var displayedText = ""
    @State private var showsEmoji = false
    @State private var textVisible = false
    @State private var animationTask: Task<Void, Never>?

    private var fullGreeting: String {
        let raw = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty {
            return "Prêt ?"
        }
        return "Prêt, \(raw) ?"
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            ZStack(alignment: .leading) {
                Text(fullGreeting)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.clear)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .accessibilityHidden(true)

                Text(displayedText)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .opacity(textVisible ? 1 : 0)
                    .offset(y: textVisible ? 0 : 8)
                    .blur(radius: textVisible ? 0 : 6)
            }

            Text("👋")
                .font(.system(size: 24))
                .opacity(showsEmoji ? 1 : 0)
                .scaleEffect(showsEmoji ? 1 : 0.35)
                .rotationEffect(.degrees(showsEmoji ? 0 : -18))
                .offset(y: showsEmoji ? 0 : 6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(fullGreeting), salut")
        .onAppear {
            runGreetingAnimation()
        }
        .onChange(of: firstName) { _, _ in
            runGreetingAnimation()
        }
        .onDisappear {
            animationTask?.cancel()
            animationTask = nil
        }
    }

    private func runGreetingAnimation() {
        animationTask?.cancel()
        displayedText = ""
        showsEmoji = false
        textVisible = false

        animationTask = Task {
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                withAnimation(.spring(response: 0.52, dampingFraction: 0.84)) {
                    textVisible = true
                }
            }

            let text = fullGreeting
            for character in text {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(nanoseconds: typingDelay(for: character))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    displayedText.append(character)
                }
            }

            guard !Task.isCancelled else { return }
            try? await Task.sleep(nanoseconds: 90_000_000)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.62)) {
                    showsEmoji = true
                }
            }
        }
    }

    private func typingDelay(for character: Character) -> UInt64 {
        switch character {
        case " ", "\n", "\t":
            return 18_000_000
        case "?", "!", ".":
            return 72_000_000
        case ",":
            return 48_000_000
        default:
            return 30_000_000
        }
    }
}
