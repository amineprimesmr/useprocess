import SwiftUI

struct CoachConversationsSidebar: View {
    @Binding var isExpanded: Bool
    var conversations: [CoachConversation]
    var activeConversationId: UUID?
    var integrationProgress: Double
    var isIntegrationComplete: Bool
    var onSelect: (UUID) -> Void
    var onCreate: () -> Void
    var onDelete: (UUID) -> Void
    var onOpenIntegration: () -> Void
    var onDeleteAllConversations: () async -> Void
    var onDeleteAllFiles: () -> Void
    var onResyncHistory: () async -> Void

    /// Ligne surlignée uniquement quand sa sheet / flow est ouvert(e).
    var activeDestination: CoachSidebarDestination?

    @Environment(\.appTheme) private var theme
    @FocusState private var isSearchFocused: Bool

    @State private var searchText = ""
    @State private var showSettings = false
    @Binding var presentedSheet: CoachSidebarDestination?

    private let chromeShape = RoundedRectangle(cornerRadius: 12, style: .continuous)

    private var filteredConversations: [CoachConversation] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return conversations }
        return conversations.filter {
            $0.sidebarSubject.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topChrome
                .padding(.bottom, 18)

            navigationSection
                .padding(.bottom, 22)

            conversationsSection

            Spacer(minLength: 12)

            settingsFooter
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, ProcessMainChromeMetrics.topSafeInset + 10)
        .padding(.bottom, 20)
        .background(theme.background)
        .sheet(isPresented: $showSettings) {
            CoachIntelligenceSettingsView(
                onDeleteAllConversations: onDeleteAllConversations,
                onDeleteAllFiles: onDeleteAllFiles,
                onResyncHistory: onResyncHistory
            )
        }
        .sheet(item: $presentedSheet) { destination in
            destinationSheet(for: destination)
        }
    }

    // MARK: - Top chrome

    private var topChrome: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(theme.secondaryText)

                TextField("Rechercher", text: $searchText)
                    .font(.body)
                    .foregroundStyle(theme.primaryText)
                    .focused($isSearchFocused)
                    .submitLabel(.search)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(theme.secondaryText)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(theme.secondaryText.opacity(0.18)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .frame(maxWidth: .infinity)
            .processGlassEffect(in: chromeShape, interactive: false)

            Button {
                isExpanded = false
                onCreate()
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.primaryText)
                    .frame(width: 40, height: 40)
            }
            .processGlassButton(in: chromeShape)
            .accessibilityLabel("Nouvelle conversation")
        }
    }

    // MARK: - Navigation

    private var navigationSection: some View {
        VStack(spacing: 2) {
            ForEach(CoachSidebarDestination.allCases) { destination in
                navigationRow(destination)
            }
        }
    }

    private func navigationRow(_ destination: CoachSidebarDestination) -> some View {
        let isHighlighted = activeDestination == destination

        return Button {
            isExpanded = false
            handleDestinationTap(destination)
        } label: {
            HStack(spacing: 12) {
                if destination == .integration {
                    CoachIntegrationProgressIcon(
                        progress: integrationProgress,
                        isComplete: isIntegrationComplete
                    )
                    .frame(width: 22, height: 22)
                } else {
                    Image(systemName: destination.icon)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(theme.primaryText.opacity(0.92))
                        .frame(width: 22, height: 22)
                }

                Text(destination.title)
                    .font(.body.weight(isHighlighted ? .semibold : .regular))
                    .foregroundStyle(theme.primaryText)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background {
                if isHighlighted {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(theme.primaryText.opacity(theme.isDark ? 0.1 : 0.06))
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func handleDestinationTap(_ destination: CoachSidebarDestination) {
        switch destination {
        case .integration:
            onOpenIntegration()
        case .healthRecords, .files, .tracking:
            presentedSheet = destination
        }
    }

    @ViewBuilder
    private func destinationSheet(for destination: CoachSidebarDestination) -> some View {
        switch destination {
        case .healthRecords:
            CoachHealthRecordsSheet()
        case .files:
            CoachFilesSheet()
        case .tracking:
            CoachTrackingSheet()
        case .integration:
            EmptyView()
        }
    }

    // MARK: - Conversations

    private var conversationsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Conversations")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.secondaryText)
                .padding(.bottom, 10)

            if filteredConversations.isEmpty {
                emptyConversationsState
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 2) {
                        ForEach(filteredConversations) { conversation in
                            conversationRow(conversation)
                        }
                    }
                }
                .scrollClipDisabled()
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var emptyConversationsState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Aucune conversation pour l'instant.")
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)

            Text("Commencez une conversation pour la voir ici.")
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
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
            .padding(.vertical, 9)
            .background {
                if isActive {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(theme.primaryText.opacity(theme.isDark ? 0.1 : 0.06))
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

    // MARK: - Settings footer

    private var settingsFooter: some View {
        Button {
            isExpanded = false
            showSettings = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(theme.primaryText.opacity(0.92))
                    .frame(width: 22)

                Text("Paramètres")
                    .font(.body.weight(.medium))
                    .foregroundStyle(theme.primaryText)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.secondaryText.opacity(0.65))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Integration progress icon

private struct CoachIntegrationProgressIcon: View {
    let progress: Double
    let isComplete: Bool

    @Environment(\.appTheme) private var theme

    var body: some View {
        ZStack {
            if isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.green.opacity(0.92))
            } else {
                Circle()
                    .stroke(theme.secondaryText.opacity(0.28), lineWidth: 2)

                Circle()
                    .trim(from: 0.08, to: 0.08 + max(0.04, progress * 0.84))
                    .stroke(theme.primaryText.opacity(0.9), lineWidth: 2)
                    .rotationEffect(.degrees(-90))
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