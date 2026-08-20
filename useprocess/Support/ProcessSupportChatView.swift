import SwiftUI

struct ProcessCrispChatView: View {
    var body: some View {
        ProcessSupportChatView()
    }
}

struct ProcessSupportChatView: View {
    var initialDraftMessage: String? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var viewModel = ProcessSupportChatViewModel()
    @FocusState private var isInputFocused: Bool

    private let messageFont = Font.system(size: 17, weight: .regular)
    private let barShape = RoundedRectangle(cornerRadius: 26, style: .continuous)

    var body: some View {
        NavigationStack {
            chatScroll
                .processSettingsStandardToolbar(
                    title: AppCopy.t("Discuter avec l'assistance", en: "Chat with Support"),
                    onBack: closeChat
                )
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    composer
                }
                .processSettingsOpalPage()
        }
        .processAppPresentationBackground()
        .onAppear {
            viewModel.start()
            if let initialDraftMessage,
               viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                viewModel.inputText = initialDraftMessage
            }
        }
        .onDisappear { viewModel.stop() }
    }

    private func closeChat() {
        isInputFocused = false
        dismiss()
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
                            .foregroundStyle(ProcessSettingsOpalTheme.valueTint)
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
                .padding(.top, 8)
                .padding(.bottom, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            .processTransparentScrollSurface()
            .onChange(of: viewModel.messages.count) { _, _ in
                withAnimation(ProcessSettingsOpalTheme.spring) {
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
        VStack(alignment: .leading, spacing: 12) {
            Text(introMessage)
                .font(messageFont)
                .foregroundStyle(.white)
                .lineSpacing(5)
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(ProcessSettingsOpalTheme.cardFillDark)
                )
                .padding(.trailing, 36)

            HStack(spacing: 18) {
                Button {} label: {
                    Image(systemName: "hand.thumbsup")
                        .font(.system(size: 16, weight: .regular))
                }
                .buttonStyle(.processPlain)
                .foregroundStyle(ProcessSettingsOpalTheme.valueTint)

                Button {} label: {
                    Image(systemName: "hand.thumbsdown")
                        .font(.system(size: 16, weight: .regular))
                }
                .buttonStyle(.processPlain)
                .foregroundStyle(ProcessSettingsOpalTheme.valueTint)
            }
            .padding(.leading, 6)
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 8)
    }

    private var introMessage: AttributedString {
        var base = AttributedString(AppCopy.t(
            "Bonjour, je suis Process et je réponds immédiatement. Notre équipe humaine examine les messages et peut répondre sous ",
            en: "Hi, I'm Process and I reply immediately. Our human team reviews messages and can respond within "
        ))
        var bold = AttributedString(AppCopy.t("4 jours ouvrés", en: "4 business days"))
        bold.font = .system(size: 17, weight: .semibold)
        bold.foregroundColor = .white
        base.append(bold)
        base.append(AttributedString("."))
        return base
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
            Text(message.text)
                .font(messageFont)
                .foregroundStyle(.white)
                .lineSpacing(4)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white.opacity(0.10))
                )
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.leading, 56)

            if message.status == .sending {
                Text(AppCopy.t("Envoi…", en: "Sending…"))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(ProcessSettingsOpalTheme.valueTint)
            } else if message.status == .failed {
                Button {
                    Task { await viewModel.retry(message) }
                } label: {
                    Text(AppCopy.t("Échec — réessayer", en: "Failed — retry"))
                        .font(.caption2.weight(.semibold))
                }
                .buttonStyle(.processPlain)
                .foregroundStyle(.red.opacity(0.85))
            }
        }
    }

    private func operatorBubble(_ message: ProcessSupportMessage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(message.text)
                .font(messageFont)
                .foregroundStyle(.white)
                .lineSpacing(4)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(ProcessSettingsOpalTheme.cardFillDark)
                )
                .padding(.trailing, 56)
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
                Button {} label: {
                    Image(systemName: "photo")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(ProcessSettingsOpalTheme.valueTint)
                        .frame(width: 36, height: 44)
                }
                .buttonStyle(.processPlain)
                .disabled(true)
                .opacity(0.45)

                HStack(alignment: .bottom, spacing: 8) {
                    TextField(
                        "",
                        text: $viewModel.inputText,
                        prompt: Text(AppCopy.t("Écris un message…", en: "Write a message…"))
                            .foregroundStyle(ProcessSettingsOpalTheme.valueTint),
                        axis: .vertical
                    )
                    .lineLimit(1...6)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.white)
                    .focused($isInputFocused)
                    .disabled(viewModel.isSending)
                    .submitLabel(.send)
                    .onSubmit {
                        guard !trimmedEmpty else { return }
                        isInputFocused = false
                        Task { await viewModel.sendCurrentMessage() }
                    }
                    .padding(.leading, 16)
                    .padding(.trailing, 4)
                    .padding(.vertical, 14)

                    Button {
                        isInputFocused = false
                        Task { await viewModel.sendCurrentMessage() }
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white.opacity(trimmedEmpty || viewModel.isSending ? 0.35 : 0.92))
                            .frame(width: 34, height: 34)
                            .background(Color.white.opacity(0.14), in: Circle())
                    }
                    .buttonStyle(.processPlain)
                    .disabled(trimmedEmpty || viewModel.isSending)
                    .padding(.trailing, 8)
                    .padding(.bottom, 8)
                }
                .frame(minHeight: 52)
                .background {
                    barShape
                        .fill(ProcessSettingsOpalTheme.cardFillDark)
                        .overlay {
                            barShape.strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                        }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, isInputFocused ? 8 : 6)
        .padding(.top, 4)
        .background(Color.black.opacity(0.92))
    }

    private var trimmedEmpty: Bool {
        viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
