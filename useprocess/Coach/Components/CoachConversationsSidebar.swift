import SwiftUI

struct CoachConversationsSidebar: View {
    @Binding var isExpanded: Bool
    var conversations: [CoachConversation]
    var activeConversationId: UUID?
    var profile: UnifiedUserProfile?
    var onSelect: (UUID) -> Void
    var onCreate: () -> Void
    var onDelete: (UUID) -> Void

    @Environment(\.appTheme) private var theme

    private var displayName: String {
        let first = profile?.firstName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !first.isEmpty { return first }
        return "Coach"
    }

    private var handle: String {
        if let uid = profile?.userId, !uid.isEmpty {
            return "@\(String(uid.prefix(8)))"
        }
        return "@useprocess"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            header

            newConversationButton
                .padding(.top, 8)

            conversationsList
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding([.horizontal, .top], 15)
        .background(theme.background)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image("ProcessIA")
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.primaryText)
                Text(handle)
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .padding(.bottom, 6)
    }

    private var newConversationButton: some View {
        Button {
            isExpanded = false
            onCreate()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "square.and.pencil")
                    .font(.title3)
                    .frame(width: 30)
                Text("Nouvelle conversation")
                    .font(.title3.weight(.bold))
            }
            .foregroundStyle(theme.primaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private var conversationsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Historique")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.secondaryText)
                .textCase(.uppercase)
                .padding(.bottom, 8)

            Group {
                if isExpanded {
                    ScrollView(.vertical) {
                        conversationRows
                    }
                    .mask { Rectangle().ignoresSafeArea() }
                    .scrollClipDisabled()
                } else {
                    conversationRows
                }
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
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(conversation.title)
                        .font(.body.weight(isActive ? .semibold : .medium))
                        .foregroundStyle(theme.primaryText)
                        .lineLimit(1)

                    Text(conversation.preview)
                        .font(.subheadline)
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(conversation.updatedAt.coachRelativeLabel)
                        .font(.caption2)
                        .foregroundStyle(theme.secondaryText.opacity(0.85))
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
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
