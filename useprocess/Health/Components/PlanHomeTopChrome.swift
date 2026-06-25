import SwiftUI

/// En-tête accueil Plan — salutation + cluster glass profil / réglages.
struct PlanHomeTopChrome: View {
    @Binding var selectedSection: ProcessMainSection

    @EnvironmentObject private var profileService: UnifiedProfileService
    @Environment(\.appTheme) private var theme

    @State private var profileStore = SocialProfileStore.shared
    @State private var showSettings = false

    private var greetingFirstName: String {
        let raw = profileService.currentProfile?.firstName
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !raw.isEmpty else { return "toi" }
        return raw
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
        HStack(alignment: .center, spacing: 12) {
            Text("Salut \(greetingFirstName)")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(theme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Spacer(minLength: 8)

            profileSettingsCluster
        }
        .padding(.bottom, 4)
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                ProcessSettingsView()
            }
            .environmentObject(profileService)
            .environmentObject(HealthManager.shared)
        }
        .onAppear {
            profileStore.bind(unified: profileService.currentProfile)
        }
        .onChange(of: profileService.currentProfile?.userId) { _, _ in
            profileStore.bind(unified: profileService.currentProfile)
        }
    }

    private enum GlassClusterMetrics {
        static let tileSize: CGFloat = 40
        static let spacing: CGFloat = 20
        static let mergeOffset: CGFloat = -20
        static let iconSize: CGFloat = 18
        static let initialsSize: CGFloat = 14
    }

    @ViewBuilder
    private var profileSettingsCluster: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: GlassClusterMetrics.spacing) {
                HStack(spacing: GlassClusterMetrics.spacing) {
                    Button(action: openSettings) {
                        Image(systemName: "gearshape.fill")
                            .frame(width: GlassClusterMetrics.tileSize, height: GlassClusterMetrics.tileSize)
                            .font(.system(size: GlassClusterMetrics.iconSize))
                            .glassEffect()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Réglages")

                    Button(action: openProfile) {
                        profileGlassTile
                    }
                    .buttonStyle(.plain)
                    .offset(x: GlassClusterMetrics.mergeOffset, y: 0.0)
                    .accessibilityLabel("Profil")
                }
            }
        } else {
            HStack(spacing: 8) {
                ProcessGlassIconButton(systemName: "gearshape.fill", iconSize: 17) {
                    openSettings()
                }
                .accessibilityLabel("Réglages")

                legacyProfileButton
            }
        }
    }

    @available(iOS 26.0, *)
    private var profileGlassTile: some View {
        Group {
            if let image = profileStore.profilePhoto {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle().fill(ProfileTheme.avatarAccent)
                    Text(avatarInitials.prefix(2))
                        .font(.system(size: GlassClusterMetrics.initialsSize, weight: .bold))
                        .foregroundStyle(.white.opacity(0.95))
                }
            }
        }
        .frame(width: GlassClusterMetrics.tileSize, height: GlassClusterMetrics.tileSize)
        .clipShape(Circle())
        .glassEffect()
    }

    private var legacyProfileButton: some View {
        Button(action: openProfile) {
            profileAvatar(size: 36)
        }
        .buttonStyle(.plain)
        .processGlassCircle(interactive: true)
        .accessibilityLabel("Profil")
    }

    @ViewBuilder
    private func profileAvatar(size: CGFloat) -> some View {
        Group {
            if let image = profileStore.profilePhoto {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle().fill(ProfileTheme.avatarAccent)
                    Text(avatarInitials.prefix(2))
                        .font(.system(size: size * 0.34, weight: .bold))
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

    private func openSettings() {
        HapticManager.shared.impact(.light)
        showSettings = true
    }
}
