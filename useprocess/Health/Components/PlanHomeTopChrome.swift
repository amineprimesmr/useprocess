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
    @State private var showDatePicker = false
    @Namespace private var streakZoomNamespace

    private static let frenchLocale = Locale(identifier: "fr_FR")

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
            VStack(alignment: .leading, spacing: 4) {
                PlanHomeGreetingLabel(greeting: homeGreeting)

                homeDatePickerButton
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            profileStreakCluster
        }
        .padding(.top, 14)
        .padding(.bottom, 4)
        .sheet(isPresented: $showDatePicker) {
            homeDatePickerSheet
        }
        .fullScreenCover(isPresented: $showStreakSheet) {
            ProcessStreakSheet(selectedDate: $selectedDate)
                .environmentObject(profileService)
                .processZoomTransition(id: .streak, namespace: streakZoomNamespace)
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

    private var homeGreeting: PlanHomeGreeting {
        PlanHomeGreetingBuilder.make(firstName: greetingFirstName)
    }

    private var homeDateLabel: String {
        let calendar = Calendar.current
        let date = calendar.startOfDay(for: selectedDate)
        return formattedWeekdayDayMonth(date)
    }

    private var homeDatePickerButton: some View {
        Button {
            HapticManager.shared.impact(.light)
            showDatePicker = true
        } label: {
            HStack(spacing: 5) {
                Text(homeDateLabel)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(theme.secondaryText)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Changer le jour affiché")
        .accessibilityHint("Ouvre le sélecteur de date")
    }

  @ViewBuilder
    private var homeDatePickerSheet: some View {
        NavigationStack {
            DatePicker(
                "Jour",
                selection: $selectedDate,
                in: homeDatePickerRange,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .environment(\.locale, Self.frenchLocale)
            .padding(.horizontal, 12)
            .navigationTitle("Choisir un jour")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") {
                        normalizeSelectedDate()
                        showDatePicker = false
                    }
                }
            }
            .onAppear {
                normalizeSelectedDate()
            }
        }
        .processAppPageBackground()
        .processAppPresentationBackground()
        .presentationDetents([.medium, .large])
    }

    private var homeDatePickerRange: ClosedRange<Date> {
        let dates: [Date] = {
            guard let plan = planStore.plan else {
                return OriginPlanPresenter.journalStripDates()
            }
            return OriginPlanPresenter.journalStripDates(in: plan)
        }()
        if let first = dates.first, let last = dates.last {
            return first...last
        }
        let today = Calendar.current.startOfDay(for: Date())
        return today...today
    }

    private func normalizeSelectedDate() {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: selectedDate)
        let range = homeDatePickerRange
        if day < range.lowerBound {
            selectedDate = range.lowerBound
        } else if day > range.upperBound {
            selectedDate = range.upperBound
        } else {
            selectedDate = day
        }
    }

    private func formattedWeekdayDayMonth(_ date: Date) -> String {
        date.formatted(
            .dateTime.weekday(.wide).day().month(.wide)
                .locale(Self.frenchLocale)
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

    @Environment(\.appTheme) private var theme

    private var greetingGradient: LinearGradient {
        if theme.isDark {
            LinearGradient(
                colors: [
                    Color.white,
                    Color.white.opacity(0.58)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.92),
                    Color.black.opacity(0.42)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    var body: some View {
        Text(greeting.line)
            .font(.system(size: 28, weight: .bold))
            .foregroundStyle(greetingGradient)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
