import SwiftUI

struct CoachChatView: View {
    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var profileService: UnifiedProfileService

    @State private var viewModel = CoachChatViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !viewModel.claudeConfigured {
                    configurationBanner
                }

                toolStrip

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(viewModel.messages) { message in
                                messageBubble(message)
                                    .id(message.id)
                            }

                            if !viewModel.streamingText.isEmpty {
                                streamingBubble
                                    .id("streaming")
                            } else if viewModel.isSending {
                                HStack(spacing: 8) {
                                    ProgressView().tint(theme.primaryText)
                                    Text("Claude réfléchit…")
                                        .font(.caption)
                                        .foregroundStyle(theme.secondaryText)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .onChange(of: viewModel.messages.count) { _, _ in scrollToBottom(proxy) }
                    .onChange(of: viewModel.streamingText) { _, _ in scrollToBottom(proxy) }
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 4)
                }

                inputBar
            }
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Coach Claude")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Nouvelle conversation", role: .destructive) {
                            Task { await viewModel.resetConversation() }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(theme.primaryText)
                    }
                }
            }
            .task {
                viewModel.bind(profile: profileService.currentProfile)
                await viewModel.loadThreadIfNeeded()
            }
            .onChange(of: profileService.currentProfile?.userId) { _, _ in
                viewModel.bind(profile: profileService.currentProfile)
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            if !viewModel.streamingText.isEmpty {
                proxy.scrollTo("streaming", anchor: .bottom)
            } else if let last = viewModel.messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    private var toolStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CoachTool.allCases) { tool in
                    Button {
                        Task { await viewModel.runTool(tool) }
                    } label: {
                        Label(tool.label, systemImage: tool.icon)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(theme.primaryText.opacity(0.1), in: Capsule())
                            .foregroundStyle(theme.primaryText)
                    }
                    .disabled(viewModel.isSending)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private var configurationBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "key.fill")
                .foregroundStyle(.orange)
            Text("Connecte Firebase + déploie les Cloud Functions, ou ajoute ANTHROPIC_API_KEY dans CoachSecrets.plist.")
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12))
    }

    private var streamingBubble: some View {
        HStack {
            Text(viewModel.streamingText)
                .font(.subheadline)
                .foregroundStyle(theme.primaryText)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(theme.primaryText.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
            Spacer(minLength: 48)
        }
    }

    @ViewBuilder
    private func messageBubble(_ message: CoachMessage) -> some View {
        let isUser = message.role == .user

        HStack {
            if isUser { Spacer(minLength: 48) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(.subheadline)
                    .foregroundStyle(isUser ? theme.background : theme.primaryText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        isUser ? theme.primaryText : theme.primaryText.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                    .textSelection(.enabled)

                if let model = message.modelUsed, !isUser {
                    Text(ClaudeModel(rawValue: model)?.displayName ?? "Claude")
                        .font(.caption2)
                        .foregroundStyle(theme.secondaryText)
                }
            }

            if !isUser { Spacer(minLength: 48) }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Pose une question à Claude…", text: $viewModel.inputText, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(theme.primaryText.opacity(0.08), in: RoundedRectangle(cornerRadius: 22))

            Button {
                Task { await viewModel.sendCurrentMessage() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending
                        ? theme.secondaryText : theme.primaryText)
            }
            .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(theme.background.opacity(0.95))
    }
}
