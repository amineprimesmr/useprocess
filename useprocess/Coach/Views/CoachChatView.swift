import SwiftUI

private enum CoachAttachmentSheet: Identifiable {
    case camera
    case photos

    var id: String {
        switch self {
        case .camera: "camera"
        case .photos: "photos"
        }
    }
}

struct CoachChatView: View {
    @Binding var selectedSection: ProcessMainSection
    var onOpenProfile: () -> Void

    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var profileService: UnifiedProfileService

    @State private var viewModel = CoachChatViewModel()
    @FocusState private var isInputFocused: Bool
    @State private var thinkingBlobStart = Date.now
    @State private var showAttachmentMenu = false
    @State private var activeAttachmentSheet: CoachAttachmentSheet?

    private let messageFont = Font.system(size: 18, weight: .regular)
    private let messageLineSpacing: CGFloat = 5
    private let responseScrollAnchor = UnitPoint(x: 0.5, y: 0.02)

    var body: some View {
        CustomSideMenu(
            isEnabled: viewModel.isSidebarEnabled,
            sideBarWidth: 300,
            isExpanded: $viewModel.isSidebarExpanded
        ) { _ in
            CoachConversationsSidebar(
                isExpanded: $viewModel.isSidebarExpanded,
                conversations: viewModel.conversations,
                activeConversationId: viewModel.activeConversationId,
                profile: profileService.currentProfile,
                onSelect: { id in
                    Task { await viewModel.selectConversation(id) }
                },
                onCreate: {
                    Task { await viewModel.createNewConversation() }
                },
                onDelete: { id in
                    Task { await viewModel.deleteConversation(id) }
                },
                onOpenProfile: onOpenProfile
            )
        } content: { _ in
            chatContent
        }
        .reportsCoachSidebarExpanded(viewModel.isSidebarExpanded)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            viewModel.bind(profile: profileService.currentProfile)
            await viewModel.loadThreadIfNeeded()
        }
        .onChange(of: profileService.currentProfile?.userId) { _, _ in
            viewModel.bind(profile: profileService.currentProfile)
            Task { await viewModel.loadThreadIfNeeded() }
        }
    }

    private var chatContent: some View {
        GeometryReader { rootGeo in
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    processMainScrollableChrome(
                        selectedSection: $selectedSection,
                        pageSection: .coach,
                        dismissesKeyboard: .interactively
                    ) {
                        LazyVStack(alignment: .leading, spacing: 20) {
                            if !viewModel.claudeConfigured {
                                configurationBanner
                            }

                            ForEach(viewModel.messages) { message in
                                messageRow(message)
                                    .id(message.id)
                                    .coachMessageFadeIn()
                            }

                            if !viewModel.streamingText.isEmpty {
                                streamingText
                                    .id("streaming")
                                    .coachMessageFadeIn()
                            } else if viewModel.isSending {
                                CoachThinkingBlobPlaceholder()
                                    .id("thinking")
                            }

                            Color.clear
                                .frame(height: scrollBottomInset(for: rootGeo.size.height))
                                .id("bottom-spacer")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .padding(.bottom, viewModel.isVoiceRecording ? 80 : 0)
                    }
                    .simultaneousGesture(
                        TapGesture().onEnded {
                            isInputFocused = false
                        }
                    )
                    .onChange(of: viewModel.messages.count) { _, _ in
                        scrollToActiveTurn(proxy, viewportHeight: rootGeo.size.height)
                    }
                    .onChange(of: viewModel.streamingText) { _, _ in
                        scrollToActiveTurn(proxy, viewportHeight: rootGeo.size.height)
                    }
                    .onChange(of: viewModel.isSending) { _, sending in
                        if sending {
                            thinkingBlobStart = .now
                            isInputFocused = false
                            scrollToActiveTurn(proxy, viewportHeight: rootGeo.size.height, delay: 0.08)
                        }
                    }
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 4)
                }
            }
            .background(theme.background.ignoresSafeArea())
            .overlay(alignment: .topLeading) {
                if viewModel.isSending && viewModel.streamingText.isEmpty {
                    CoachEdgeBlobOverlay(
                        isDark: theme.isDark,
                        mode: .thinking(start: thinkingBlobStart)
                    )
                    .padding(.top, blobVerticalCenter(in: rootGeo.size.height) - 36)
                } else if viewModel.isVoiceRecording || viewModel.isVoiceExiting {
                    CoachEdgeBlobOverlay(
                        isDark: theme.isDark,
                        mode: .voice(
                            elapsed: viewModel.voiceElapsed,
                            total: viewModel.voiceMaxDuration
                        )
                    )
                    .padding(.top, blobVerticalCenter(in: rootGeo.size.height) - 36)
                }
            }
            .ignoresSafeArea(edges: .leading)
            .overlay(alignment: .bottom) {
                if viewModel.isVoiceRecording || viewModel.isVoiceExiting {
                    CoachVoiceRecorderPill(
                        elapsed: viewModel.voiceElapsed,
                        total: viewModel.voiceMaxDuration,
                        isExiting: viewModel.isVoiceExiting,
                        onCancel: { viewModel.cancelVoiceRecording() }
                    )
                    .frame(width: rootGeo.size.width)
                    .padding(.bottom, 148)
                    .ignoresSafeArea(edges: .leading)
                    .transition(
                        .asymmetric(
                            insertion: .opacity,
                            removal: .opacity.combined(with: .scale(scale: 0.92, anchor: .leading))
                        )
                    )
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            CoachLiquidGlassInputBar(
                text: $viewModel.inputText,
                isFocused: $isInputFocused,
                pendingImage: viewModel.pendingAttachmentImage,
                isDisabled: viewModel.isSending,
                isRecording: viewModel.isVoiceRecording,
                isAttachmentMenuOpen: showAttachmentMenu,
                onSend: {
                    isInputFocused = false
                    Task { await viewModel.sendCurrentMessage() }
                },
                onStartVoice: {
                    Task { await viewModel.startVoiceRecording() }
                },
                onOpenMenu: {
                    isInputFocused = false
                    withAnimation(ProcessGlass.spring) {
                        showAttachmentMenu.toggle()
                    }
                },
                onRemovePendingImage: {
                    viewModel.clearPendingAttachment()
                }
            )
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
            .animation(ProcessGlass.spring, value: viewModel.isVoiceRecording)
        }
        .overlay {
            if showAttachmentMenu {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(ProcessGlass.spring) {
                            showAttachmentMenu = false
                        }
                    }
            }
        }
        .overlay(alignment: .bottomLeading) {
            if showAttachmentMenu {
                CoachAttachmentGlassPopover { option in
                    withAnimation(ProcessGlass.spring) {
                        showAttachmentMenu = false
                    }
                    handleAttachmentOption(option)
                }
                .padding(.leading, 28)
                .padding(.bottom, 132)
                .transition(
                    .scale(scale: 0.88, anchor: .bottomLeading)
                        .combined(with: .opacity)
                )
            }
        }
        .animation(ProcessGlass.spring, value: showAttachmentMenu)
        .fullScreenCover(item: $activeAttachmentSheet) { sheet in
            switch sheet {
            case .camera:
                CoachChatCameraSheet(
                    onCapture: { image in
                        activeAttachmentSheet = nil
                        viewModel.stageImageAttachment(image)
                        isInputFocused = true
                    },
                    onCancel: { activeAttachmentSheet = nil }
                )
            case .photos:
                CoachChatPhotoLibrarySheet(
                    onSelect: { image in
                        activeAttachmentSheet = nil
                        viewModel.stageImageAttachment(image)
                        isInputFocused = true
                    },
                    onCancel: { activeAttachmentSheet = nil }
                )
            }
        }
    }

    private func handleAttachmentOption(_ option: CoachAttachmentOption) {
        switch option {
        case .camera:
            activeAttachmentSheet = .camera
        case .photos:
            activeAttachmentSheet = .photos
        }
    }

    private func blobVerticalCenter(in viewportHeight: CGFloat) -> CGFloat {
        viewportHeight * 0.42
    }

    private func scrollBottomInset(for viewportHeight: CGFloat) -> CGFloat {
        max(0, viewportHeight * 0.58)
    }

    private func scrollToActiveTurn(
        _ proxy: ScrollViewProxy,
        viewportHeight: CGFloat,
        delay: TimeInterval = 0.04
    ) {
        let performScroll = {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.9)) {
                if !viewModel.streamingText.isEmpty {
                    proxy.scrollTo("streaming", anchor: responseScrollAnchor)
                } else if viewModel.isSending {
                    proxy.scrollTo("thinking", anchor: responseScrollAnchor)
                } else if let lastAssistant = viewModel.messages.last(where: { $0.role == .assistant }) {
                    proxy.scrollTo(lastAssistant.id, anchor: responseScrollAnchor)
                } else if let last = viewModel.messages.last {
                    proxy.scrollTo(last.id, anchor: responseScrollAnchor)
                }
            }
        }

        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: performScroll)
        } else {
            performScroll()
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
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var streamingText: some View {
        Text(viewModel.streamingText)
            .font(messageFont)
            .foregroundStyle(theme.primaryText)
            .lineSpacing(messageLineSpacing)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
    }

    @ViewBuilder
    private func messageRow(_ message: CoachMessage) -> some View {
        let isUser = message.role == .user

        if isUser {
            HStack {
                Spacer(minLength: 56)
                Text(message.text)
                    .font(messageFont)
                    .foregroundStyle(theme.primaryText)
                    .lineSpacing(messageLineSpacing)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(theme.coachUserBubble, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .textSelection(.enabled)
            }
        } else {
            Text(message.text)
                .font(messageFont)
                .foregroundStyle(theme.primaryText)
                .lineSpacing(messageLineSpacing)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }
}
