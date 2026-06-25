import SwiftUI

struct CoachConversationsSidebar: View {
    @Binding var isExpanded: Bool
    var conversations: [CoachConversation]
    var activeConversationId: UUID?
    var profile: UnifiedUserProfile?
    var onSelect: (UUID) -> Void
    var onCreate: () -> Void
    var onDelete: (UUID) -> Void
    var onOpenProfile: () -> Void
    var onOpenWelcomePlan: (() -> Void)? = nil

    @Environment(\.appTheme) private var theme
    @State private var profileStore = SocialProfileStore.shared
    @State private var showSettings = false

    private var resolvedSocialProfile: SocialProfile {
        if let saved = profileStore.profile {
            return saved
        }
        if let unified = profile {
            return SocialProfile.from(unified: unified)
        }
        return .guest
    }

    private var displayName: String {
        let name = resolvedSocialProfile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Profil" : name
    }

    private var handle: String {
        "@\(resolvedSocialProfile.username)"
    }

    private var avatarInitials: String {
        let parts = displayName.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? "?"
        let last = parts.dropFirst().first?.first.map(String.init) ?? ""
        return (first + last).uppercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            conversationsList
                .padding(.top, 12)

            Spacer(minLength: 0)

            if onOpenWelcomePlan != nil {
                welcomePlanButton
                    .padding(.top, 12)
            }

            newConversationButton
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 15)
        .padding(.top, ProcessMainChromeMetrics.topSafeInset + 12)
        .padding(.bottom, 20)
        .background(theme.background)
        .onAppear {
            profileStore.bind(unified: profile)
        }
        .onChange(of: profile?.userId) { _, _ in
            profileStore.bind(unified: profile)
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                ProcessSettingsView()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            Button {
                isExpanded = false
                onOpenProfile()
            } label: {
                HStack(spacing: 12) {
                    profileAvatar

                    VStack(alignment: .leading, spacing: 2) {
                        Text(displayName)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(theme.primaryText)
                        Text(handle)
                            .font(.subheadline)
                            .foregroundStyle(theme.secondaryText)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            ProcessGlassIconButton(systemName: "gearshape.fill", iconSize: 18) {
                isExpanded = false
                showSettings = true
            }
        }
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private var profileAvatar: some View {
        Group {
            if let image = profileStore.profilePhoto {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle().fill(ProfileTheme.avatarAccent)
                    Text(avatarInitials.prefix(2))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(Circle())
    }

    private var welcomePlanButton: some View {
        ProcessGlassWideButton(
            title: "Protocole Origine",
            icon: "leaf.fill"
        ) {
            isExpanded = false
            onOpenWelcomePlan?()
        }
    }

    private var newConversationButton: some View {
        ProcessGlassWideButton(
            title: "Nouvelle conversation",
            icon: "square.and.pencil"
        ) {
            isExpanded = false
            onCreate()
        }
    }

    private var conversationsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Historique")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.secondaryText)
                .textCase(.uppercase)
                .padding(.bottom, 8)

            Group {
                ScrollView(.vertical, showsIndicators: false) {
                    conversationRows
                }
                .scrollClipDisabled()
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var conversationRows: some View {
        LazyVStack(spacing: 4) {
            if conversations.isEmpty {
                Text("Aucune conversation")
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
            } else {
                ForEach(conversations) { conversation in
                    conversationRow(conversation)
                }
            }
        }
    }

    private func conversationRow(_ conversation: CoachConversation) -> some View {
        let isActive = conversation.id == activeConversationId

        return Button {
            isExpanded = false
            onSelect(conversation.id)
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Text(conversation.sidebarSubject)
                    .font(.subheadline.weight(isActive ? .semibold : .regular))
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(conversation.updatedAt.coachRelativeLabel)
                    .font(.caption2)
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                if isActive {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(theme.isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.06))
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                onDelete(conversation.id)
            } label: {
                Label("Supprimer", systemImage: "trash")
            }
        }
    }
}

private extension Date {
    var coachRelativeLabel: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
