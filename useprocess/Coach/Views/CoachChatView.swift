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
    @State private var showWelcomePlanPreview = false
    @State private var welcomePlanPreviewID = UUID()
    @State private var messageContextMenu: CoachUserMessageContextState?
    @State private var viewportHeight: CGFloat = 0

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
                onOpenProfile: onOpenProfile,
                onOpenWelcomePlan: openWelcomePlanPreview
            )
        } content: { _ in
            chatContent
        }
        .overlay {
            if let context = messageContextMenu {
                CoachUserMessageContextOverlay(
                    message: context.message,
                    bubbleFrame: context.bubbleFrame,
                    font: messageFont,
                    lineSpacing: messageLineSpacing,
                    bubbleColor: theme.coachUserBubble,
                    textColor: theme.primaryText,
                    onEdit: {
                        let msg = context.message
                        messageContextMenu = nil
                        Task {
                            await viewModel.beginEditingMessage(msg)
                            try? await Task.sleep(nanoseconds: 280_000_000)
                            isInputFocused = true
                        }
                    },
                    onDismiss: { messageContextMenu = nil }
                )
                .zIndex(999)
                .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: messageContextMenu != nil)
        .fullScreenCover(isPresented: $showWelcomePlanPreview) {
            WelcomePlanChatView(previewMode: true) {
                showWelcomePlanPreview = false
            }
            .id(welcomePlanPreviewID)
            .environment(\.appTheme, theme)
            .environmentObject(profileService)
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
        .onChange(of: CoachPlanNavigationBridge.shared.shouldOpenCoach) { _, should in
            guard should else { return }
            Task { await viewModel.consumePendingPlanPromptIfNeeded() }
        }
    }

    private var chatContent: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    processMainScrollableChrome(
                        selectedSection: $selectedSection,
                        pageSection: .coach,
                        dismissesKeyboard: .interactively,
                        scrollDisabled: messageContextMenu != nil
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
                                .frame(height: scrollBottomInset)
                                .id("bottom-spacer")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .padding(.bottom, viewModel.isVoiceRecording ? 80 : 0)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .simultaneousGesture(
                        TapGesture().onEnded {
                            isInputFocused = false
                        }
                    )
                    .onChange(of: viewModel.messages.count) { oldCount, newCount in
                        if newCount < oldCount {
                            scrollToConversationTop(proxy, delay: 0.05)
                        } else {
                            scrollToActiveTurn(proxy)
                        }
                    }
                    .onChange(of: viewModel.streamingText) { _, _ in
                        scrollToActiveTurn(proxy)
                    }
                    .onChange(of: viewModel.isSending) { _, sending in
                        if sending {
                            thinkingBlobStart = .now
                            isInputFocused = false
                            scrollToActiveTurn(proxy, delay: 0.08)
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
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background {
                GeometryReader { geo in
                    Color.clear
                        .onAppear { viewportHeight = geo.size.height }
                        .onChange(of: geo.size.height) { _, height in
                            viewportHeight = height
                        }
                }
            }
            .background(theme.background.ignoresSafeArea())
            .overlay(alignment: .topLeading) {
                if viewModel.isSending && viewModel.streamingText.isEmpty {
                    CoachEdgeBlobOverlay(
                        isDark: theme.isDark,
                        mode: .thinking(start: thinkingBlobStart)
                    )
                    .padding(.top, blobVerticalCenter - 36)
                } else if viewModel.isVoiceRecording || viewModel.isVoiceExiting {
                    CoachEdgeBlobOverlay(
                        isDark: theme.isDark,
                        mode: .voice(
                            elapsed: viewModel.voiceElapsed,
                            total: viewModel.voiceMaxDuration
                        )
                    )
                    .padding(.top, blobVerticalCenter - 36)
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
                    .frame(maxWidth: .infinity)
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
        .safeAreaInset(edge: .bottom, spacing: 0) {
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

    private var blobVerticalCenter: CGFloat {
        max(viewportHeight * 0.42, 180)
    }

    private var scrollBottomInset: CGFloat { 24 }

    private func scrollToConversationTop(
        _ proxy: ScrollViewProxy,
        delay: TimeInterval = 0.04
    ) {
        let performScroll = {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.9)) {
                if let first = viewModel.messages.first {
                    proxy.scrollTo(first.id, anchor: .top)
                } else {
                    proxy.scrollTo("bottom-spacer", anchor: .top)
                }
            }
        }

        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: performScroll)
        } else {
            performScroll()
        }
    }

    private func scrollToActiveTurn(
        _ proxy: ScrollViewProxy,
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
        CoachFormattedText(
            text: viewModel.streamingText,
            font: messageFont,
            lineSpacing: messageLineSpacing,
            color: theme.primaryText
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func messageRow(_ message: CoachMessage) -> some View {
        let isUser = message.role == .user

        if isUser {
            CoachUserMessageBubbleView(
                message: message,
                font: messageFont,
                lineSpacing: messageLineSpacing,
                bubbleColor: theme.coachUserBubble,
                textColor: theme.primaryText,
                onLongPress: { frame in
                    isInputFocused = false
                    messageContextMenu = CoachUserMessageContextState(
                        message: message,
                        bubbleFrame: frame
                    )
                }
            )
        } else {
            CoachFormattedText(
                text: message.text,
                font: messageFont,
                lineSpacing: messageLineSpacing,
                color: theme.primaryText
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
        }
    }

    private func openWelcomePlanPreview() {
        WelcomePlanStore.shared.resetQuestionnaireForPreview()
        welcomePlanPreviewID = UUID()
        showWelcomePlanPreview = true
    }
}
