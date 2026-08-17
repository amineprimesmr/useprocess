import SwiftUI

struct ProcessCrispChatView: View {
    var body: some View {
        ProcessSupportChatView()
    }
}

struct ProcessSupportChatView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    @State private var viewModel = ProcessSupportChatViewModel()
    @FocusState private var isInputFocused: Bool

    private let messageFont = Font.system(size: 17, weight: .regular)
    private let barShape = RoundedRectangle(cornerRadius: 26, style: .continuous)

    var body: some View {
        NavigationStack {
            chatScroll
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    composer
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        VStack(spacing: 1) {
                            Text(AppCopy.t("Équipe Process", en: "Process team"))
                                .font(.headline.weight(.semibold))
                            Text(AppCopy.t("Réponse dans l'app", en: "Replies in the app"))
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(theme.secondaryText)
                        }
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(theme.primaryText)
                                .frame(width: 34, height: 34)
                                .background(
                                    Circle()
                                        .fill(theme.cardBackgroundStrong.opacity(theme.isDark ? 0.95 : 0.82))
                                )
                        }
                        .accessibilityLabel(AppCopy.close)
                    }
                }
        }
        .processAppPageBackground()
        .processAppPresentationBackground()
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }

    private var chatScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if viewModel.messages.isEmpty {
                        emptyIntro
                    }

                    if let errorMessage = viewModel.errorMessage, viewModel.messages.isEmpty {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(theme.secondaryText)
                            .padding(.horizontal, 20)
                    }

                    ForEach(viewModel.messages) { message in
                        messageRow(message)
                            .id(message.id)
                    }

                    Color.clear
                        .frame(height: 8)
                        .id("support-bottom")
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            .processTransparentScrollSurface()
            .onChange(of: viewModel.messages.count) { _, _ in
                withAnimation(.spring(response: 0.38, dampingFraction: 0.9)) {
                    proxy.scrollTo("support-bottom", anchor: .bottom)
                }
            }
            .onAppear {
                proxy.scrollTo("support-bottom", anchor: .bottom)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { isInputFocused = false }
    }

    private var emptyIntro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppCopy.t("Salut, c'est l'équipe Process.", en: "Hey, this is the Process team."))
                .font(messageFont)
                .foregroundStyle(theme.primaryText)
            Text(AppCopy.t(
                "Un bug, une idée, une question — écris-nous ici. On te répond dans cette conversation.",
                en: "A bug, an idea, a question — write us here. We'll reply in this thread."
            ))
            .font(.subheadline)
            .foregroundStyle(theme.secondaryText)
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private func messageRow(_ message: ProcessSupportMessage) -> some View {
        if message.role == .user {
            userBubble(message)
        } else {
            operatorBubble(message)
        }
    }

    private func userBubble(_ message: ProcessSupportMessage) -> some View {
        VStack(alignment: .trailing, spacing: 6) {
            HStack(alignment: .bottom, spacing: 0) {
                Spacer(minLength: 48)

                CoachUserThoughtBubbleBody(bubbleColor: theme.coachUserBubble) {
                    Text(message.text)
                        .font(messageFont)
                        .foregroundStyle(theme.primaryText)
                        .lineSpacing(4)
                        .multilineTextAlignment(.leading)
                }

                CoachThoughtBubbleTailView(color: theme.coachUserBubble)
                    .padding(.leading, -7)

                CoachUserChatAvatarView(
                    profile: UnifiedProfileService.shared.currentProfile,
                    bubbleColor: theme.coachUserBubble,
                    textColor: theme.primaryText
                )
            }

            if message.status == .sending {
                Text(AppCopy.t("Envoi…", en: "Sending…"))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(theme.secondaryText)
                    .padding(.trailing, 52)
            } else if message.status == .failed {
                Button {
                    Task { await viewModel.retry(message) }
                } label: {
                    Text(AppCopy.t("Échec — réessayer", en: "Failed — retry"))
                        .font(.caption2.weight(.semibold))
                }
                .buttonStyle(.processPlain)
                .foregroundStyle(.red.opacity(0.85))
                .padding(.trailing, 52)
            }
        }
    }

    private func operatorBubble(_ message: ProcessSupportMessage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(AppCopy.t("Équipe", en: "Team"))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(theme.secondaryText)
                .padding(.leading, 8)

            Text(message.text)
                .font(messageFont)
                .foregroundStyle(theme.primaryText)
                .lineSpacing(4)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(theme.coachAssistantBubble)
                )
                .padding(.trailing, 48)
        }
    }

    private var composer: some View {
        VStack(spacing: 8) {
            if let errorMessage = viewModel.errorMessage, !viewModel.messages.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
            }

            HStack(alignment: .bottom, spacing: 10) {
                TextField(
                    "",
                    text: $viewModel.inputText,
                    prompt: Text(AppCopy.t("Écris-nous un message…", en: "Write us a message…"))
                        .foregroundStyle(Color.primary.opacity(0.38)),
                    axis: .vertical
                )
                .lineLimit(1...6)
                .font(.system(size: 16, weight: .regular))
                .focused($isInputFocused)
                .disabled(viewModel.isSending)
                .submitLabel(.send)
                .onSubmit {
                    guard !trimmedEmpty else { return }
                    isInputFocused = false
                    Task { await viewModel.sendCurrentMessage() }
                }
                .padding(.leading, 18)
                .padding(.trailing, 8)
                .padding(.vertical, 14)

                Button {
                    isInputFocused = false
                    Task { await viewModel.sendCurrentMessage() }
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 44, height: 44)
                }
                .processNativeGlassCircleButtonStyle()
                .disabled(trimmedEmpty || viewModel.isSending)
                .opacity(trimmedEmpty || viewModel.isSending ? 0.38 : 1)
                .padding(.trailing, 6)
                .padding(.bottom, 6)
            }
            .frame(minHeight: 56)
            .processGlassEffect(in: barShape, interactive: false)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, isInputFocused ? 8 : 6)
        .padding(.top, 4)
    }

    private var trimmedEmpty: Bool {
        viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
