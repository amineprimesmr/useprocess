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
    @Bindable private var session = AppSession.shared

    @State private var viewModel = CoachChatViewModel()
    @FocusState private var isInputFocused: Bool
    @State private var thinkingBlobStart = Date.now
    @State private var showAttachmentMenu = false
    @State private var activeAttachmentSheet: CoachAttachmentSheet?
    @State private var showWelcomePlanPreview = false
    @State private var welcomePlanPreviewID = UUID()
    @State private var messageContextMenu: CoachUserMessageContextState?
    @State private var thinkingResponseAnchor: CGRect = .zero
    @State private var showFaceScan = false
    @State private var isSidebarExpanded = false
    @State private var planStore = WelcomePlanStore.shared

    private let messageFont = Font.system(size: 17, weight: .regular)
    private let messageLineSpacing: CGFloat = 4

    var body: some View {
        Group {
            if !session.hasCompletedWelcomePlanChat {
                WelcomePlanChatView(
                    embeddedInMainApp: true,
                    selectedSection: $selectedSection,
                    onComplete: dismissWelcomePlanChat
                )
            } else {
                coachMainContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: session.hasCompletedWelcomePlanChat) { _, completed in
            guard completed, !showWelcomePlanPreview else { return }
            Task {
                viewModel.bind(profile: profileService.currentProfile)
                await viewModel.loadThreadIfNeeded()
            }
        }
    }

    private func dismissWelcomePlanChat() {
        if showWelcomePlanPreview {
            WelcomePlanStore.shared.endPreviewSession(restore: true)
            showWelcomePlanPreview = false
            Task {
                viewModel.bind(profile: profileService.currentProfile)
                await viewModel.loadThreadIfNeeded()
            }
        } else {
            Task {
                viewModel.bind(profile: profileService.currentProfile)
                await viewModel.loadThreadIfNeeded()
            }
        }
    }

    private let coachSidebarWidth: CGFloat = 300

    /// Questionnaire accessible uniquement tant qu'aucun protocole n'existe encore.
    private var showsWelcomePlanMenuEntry: Bool {
        planStore.plan == nil && !planStore.isQuestionnaireComplete
    }

    private var welcomePlanMenuAction: (() -> Void)? {
        guard showsWelcomePlanMenuEntry else { return nil }
        return { openWelcomePlanPreview() }
    }

    private var hasWelcomePlan: Bool {
        planStore.plan != nil
    }

    private var coachMainContent: some View {
        CustomSideMenu(
            isEnabled: viewModel.isSidebarEnabled,
            sideBarWidth: coachSidebarWidth,
            isExpanded: $isSidebarExpanded
        ) { _ in
            coachSidebar
        } content: { _ in
            coachMainPane
        }
        .onAppear {
            planStore.reloadForCurrentUser()
        }
        .onChange(of: hasWelcomePlan) { _, hasPlan in
            guard hasPlan, showWelcomePlanPreview else { return }
            dismissWelcomePlanChat()
        }
        .overlay {
            coachMessageContextOverlay
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: messageContextMenu != nil)
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
        .fullScreenCover(isPresented: $showFaceScan) {
            FaceScanPrivacyGateView(
                onDismiss: { showFaceScan = false },
                onComplete: { _ in
                    showFaceScan = false
                    FaceScanHistoryStore.shared.reloadForUser(userId: profileService.currentProfile?.userId)
                }
            )
            .environmentObject(profileService)
        }
    }

    private var coachSidebar: some View {
        CoachConversationsSidebar(
            isExpanded: $isSidebarExpanded,
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
            onOpenWelcomePlan: welcomePlanMenuAction
        )
    }

    @ViewBuilder
    private var coachMainPane: some View {
        if showWelcomePlanPreview, showsWelcomePlanMenuEntry {
            WelcomePlanChatView(
                previewMode: true,
                embeddedInMainApp: true,
                selectedSection: $selectedSection,
                onComplete: dismissWelcomePlanChat
            )
            .id(welcomePlanPreviewID)
        } else {
            chatContent
        }
    }

    @ViewBuilder
    private var coachMessageContextOverlay: some View {
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

    private var chatContent: some View {
        ZStack(alignment: .topLeading) {
            if viewModel.showsContextualHome {
                CoachContextualHomeView(
                    prompt: viewModel.homePrompt,
                    startsComplete: viewModel.shouldSkipHomeAnimation,
                    onGreetingComplete: {
                        Task { @MainActor in
                            viewModel.onHomeGreetingComplete()
                        }
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.background.ignoresSafeArea())
                .transition(
                    .opacity
                        .combined(with: .offset(y: 6))
                )
            } else {
                activeConversationScroll
                    .transition(
                        .opacity
                            .combined(with: .offset(y: 8))
                    )
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.88), value: viewModel.showsContextualHome)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CoachChatBottomAccessory(
                showsContextualHome: viewModel.showsContextualHome,
                suggestions: viewModel.homePrompt.suggestions,
                homeActionsRevealed: viewModel.homeActionsRevealed,
                skipHomeAnimation: viewModel.shouldSkipHomeAnimation,
                showsHomeInsteadOfInput: viewModel.showsHomeInsteadOfInput,
                isSending: viewModel.isSending,
                onSelectSuggestion: { suggestion in
                    isInputFocused = false
                    Task { await viewModel.sendHomeSuggestion(suggestion) }
                },
                contextualHomeBottomBar: { contextualHomeBottomBar },
                chatInputBar: { coachChatInputBar }
            )
        }
        .overlay {
            if showAttachmentMenu,
               !viewModel.showsHomeInsteadOfInput,
               !viewModel.isVoiceRecording,
               !viewModel.isVoiceExiting {
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
            if showAttachmentMenu,
               !viewModel.showsHomeInsteadOfInput,
               !viewModel.isVoiceRecording,
               !viewModel.isVoiceExiting {
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
        .onChange(of: viewModel.activeConversationId) { _, _ in
            viewModel.onActiveConversationChanged()
        }
        .onChange(of: viewModel.homePrompt.greetingText) { old, new in
            guard old != new else { return }
            viewModel.syncHomePresentationFromCache()
        }
    }

    private var activeConversationScroll: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    processMainScrollableChrome(
                        selectedSection: $selectedSection,
                        pageSection: .coach,
                        dismissesKeyboard: .interactively,
                        scrollDisabled: messageContextMenu != nil
                    ) {
                        VStack(alignment: .leading, spacing: 14) {
                            if !viewModel.claudeConfigured {
                                configurationBanner
                            }

                            ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                                messageRow(message)
                                    .padding(.top, messageTopSpacing(at: index))
                                    .id(message.id)
                            }

                            if !viewModel.streamingText.isEmpty {
                                streamingText
                                    .padding(.top, pendingAssistantReplySpacing)
                                    .id("streaming")
                                    .coachMessageFadeIn()
                            } else if viewModel.isSending {
                                CoachThinkingBlobPlaceholder()
                                    .padding(.top, pendingAssistantReplySpacing)
                                    .id("thinking")
                            }

                            Color.clear
                                .frame(height: scrollBottomInset)
                                .id("bottom-spacer")
                        }
                        .id(viewModel.activeConversationId)
                        .padding(.leading, 16)
                        .padding(.trailing, 6)
                        .padding(.vertical, 12)
                        .animation(.spring(response: 0.38, dampingFraction: 0.88), value: viewModel.messages.count)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .simultaneousGesture(
                        TapGesture().onEnded {
                            isInputFocused = false
                        }
                    )
                    .onAppear {
                        scrollToBottom(proxy, animated: false)
                    }
                    .onChange(of: viewModel.messages.count) { _, _ in
                        scrollToBottom(proxy)
                    }
                    .onChange(of: viewModel.activeConversationId) { _, _ in
                        scrollToBottom(proxy, delay: 0.06, animated: false)
                    }
                    .onChange(of: viewModel.streamingText) { _, _ in
                        scrollToBottom(proxy, delay: 0.02)
                    }
                    .onChange(of: viewModel.isSending) { wasSending, sending in
                        if sending, !wasSending {
                            thinkingResponseAnchor = .zero
                            thinkingBlobStart = .now
                            isInputFocused = false
                            scrollToBottom(proxy, delay: 0.08)
                        } else if !sending {
                            thinkingResponseAnchor = .zero
                        }
                    }
                    .onChange(of: isInputFocused) { _, focused in
                        guard focused else { return }
                        scrollToBottom(proxy, delay: 0.04)
                        scrollToBottom(proxy, delay: 0.22)
                    }
                    .onChange(of: viewModel.inputText) { _, _ in
                        guard isInputFocused else { return }
                        scrollToBottom(proxy, animated: false)
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
            .background(theme.background.ignoresSafeArea())
            .coordinateSpace(name: "coachChatRoot")
            .onPreferenceChange(CoachResponseAnchorKey.self) { anchor in
                thinkingResponseAnchor = anchor
            }
            .overlay(alignment: .topLeading) {
                if viewModel.isSending,
                   viewModel.streamingText.isEmpty,
                   thinkingResponseAnchor.height > 0 {
                    CoachEdgeBlobOverlay(
                        mode: .thinking(start: thinkingBlobStart)
                    )
                    .padding(.top, CoachBlobLayout.overlayTopPadding(for: thinkingResponseAnchor))
                    .zIndex(2)
                }
            }
            .ignoresSafeArea(edges: .leading)
        }
    }

    private var coachChatInputBar: some View {
        CoachLiquidGlassInputBar(
            text: $viewModel.inputText,
            isFocused: $isInputFocused,
            pendingImage: viewModel.pendingAttachmentImage,
            isDisabled: viewModel.isSending,
            isRecording: viewModel.isVoiceRecording,
            isVoiceExiting: viewModel.isVoiceExiting,
            isAttachmentMenuOpen: showAttachmentMenu,
            voiceAudioLevel: viewModel.voiceAudioLevel,
            voiceAudioLevels: viewModel.voiceAudioLevels,
            onSend: {
                isInputFocused = false
                Task { await viewModel.sendCurrentMessage() }
            },
            onStartVoice: {
                withAnimation(ProcessGlass.spring) {
                    showAttachmentMenu = false
                }
                Task { await viewModel.startVoiceRecording() }
            },
            onCancelVoice: {
                viewModel.cancelVoiceRecording()
            },
            onConfirmVoice: {
                Task {
                    let inserted = await viewModel.confirmVoiceRecording()
                    if inserted {
                        isInputFocused = true
                    }
                }
            },
            onOpenMenu: {
                let keepKeyboard = isInputFocused
                withAnimation(ProcessGlass.spring) {
                    showAttachmentMenu.toggle()
                }
                if keepKeyboard {
                    isInputFocused = true
                }
            },
            onRemovePendingImage: {
                viewModel.clearPendingAttachment()
            }
        )
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
        .animation(ProcessGlass.spring, value: viewModel.isVoiceRecording)
        .animation(ProcessGlass.spring, value: viewModel.isVoiceExiting)
    }

    private var contextualHomeBottomBar: some View {
        VStack(spacing: 14) {
            if let title = viewModel.homePrompt.primaryActionTitle {
                Button {
                    HapticManager.shared.impact(.medium)
                    showFaceScan = true
                } label: {
                    Text(title)
                        .font(.system(size: OnboardingProfileChatDepthStyle.answerFontSize + 1, weight: .bold))
                        .foregroundStyle(theme.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .processGlassEffect(in: Capsule())
                .buttonStyle(ProcessGlassPressStyle())
                .onboardingChatAnswerReveal(isRevealed: viewModel.homeActionsRevealed)
            }

            Button {
                HapticManager.shared.selection()
                viewModel.unlockHomeChatInput()
                isInputFocused = true
            } label: {
                Text("Écrire un message")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(theme.secondaryText)
            }
            .buttonStyle(.plain)
            .onboardingChatAnswerReveal(isRevealed: viewModel.homeActionsRevealed)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, LayoutConstants.safeAreaBottom + 10)
    }

    private enum CoachMessageSpacing {
        /// Espace après un message utilisateur, avant la réponse coach.
        static let userToAssistant: CGFloat = 24
        static let assistantToUser: CGFloat = 10
    }

    private var pendingAssistantReplySpacing: CGFloat {
        viewModel.messages.last?.role == .user ? CoachMessageSpacing.userToAssistant : 0
    }

    private func messageTopSpacing(at index: Int) -> CGFloat {
        guard index > 0 else { return 0 }
        let previous = viewModel.messages[index - 1]
        let current = viewModel.messages[index]
        if previous.role == .user, current.role == .assistant {
            return CoachMessageSpacing.userToAssistant
        }
        if previous.role == .assistant, current.role == .user {
            return CoachMessageSpacing.assistantToUser
        }
        return 0
    }

    private func handleAttachmentOption(_ option: CoachAttachmentOption) {
        switch option {
        case .camera:
            activeAttachmentSheet = .camera
        case .photos:
            activeAttachmentSheet = .photos
        }
    }

    private var scrollBottomInset: CGFloat { 12 }

    private func scrollToBottom(
        _ proxy: ScrollViewProxy,
        delay: TimeInterval = 0.04,
        animated: Bool = true
    ) {
        let performScroll = {
            if animated {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.9)) {
                    proxy.scrollTo("bottom-spacer", anchor: .bottom)
                }
            } else {
                proxy.scrollTo("bottom-spacer", anchor: .bottom)
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
            Text("Le coach est momentanément indisponible. Réessaie dans quelques instants.")
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
                profile: profileService.currentProfile,
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
            .transition(
                .opacity
                    .combined(with: .offset(y: 10))
                    .combined(with: .scale(scale: 0.98, anchor: .bottomTrailing))
            )
        } else if let meal = CoachMealMessageDetector.mealContent(from: message.text) {
            CoachMealSuggestionMessageView(content: meal)
                .transition(
                    .opacity
                        .combined(with: .offset(y: 8))
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
        guard showsWelcomePlanMenuEntry else { return }
        if showWelcomePlanPreview {
            dismissWelcomePlanChat()
            return
        }
        WelcomePlanStore.shared.beginPreviewSession()
        welcomePlanPreviewID = UUID()
        withAnimation(ProcessGlass.spring) {
            selectedSection = .coach
            showWelcomePlanPreview = true
        }
    }
}

private struct CoachChatBottomAccessory<ContextualBar: View, InputBar: View>: View {
    let showsContextualHome: Bool
    let suggestions: [CoachHomeSuggestion]
    let homeActionsRevealed: Bool
    let skipHomeAnimation: Bool
    let showsHomeInsteadOfInput: Bool
    let isSending: Bool
    let onSelectSuggestion: (CoachHomeSuggestion) -> Void
    @ViewBuilder var contextualHomeBottomBar: () -> ContextualBar
    @ViewBuilder var chatInputBar: () -> InputBar

    var body: some View {
        VStack(spacing: 12) {
            if showsContextualHome, !suggestions.isEmpty {
                CoachHomeSuggestionBar(
                    suggestions: suggestions,
                    isRevealed: homeActionsRevealed,
                    instantReveal: skipHomeAnimation,
                    isDisabled: isSending,
                    onSelect: onSelectSuggestion
                )
                .padding(.horizontal, 20)
                .transition(
                    .opacity
                        .combined(with: .offset(y: 10))
                        .combined(with: .scale(scale: 0.98, anchor: .bottom))
                )
            }

            if showsHomeInsteadOfInput {
                contextualHomeBottomBar()
                    .transition(
                        .opacity
                            .combined(with: .offset(y: 8))
                    )
            } else {
                chatInputBar()
                    .transition(
                        .opacity
                            .combined(with: .offset(y: 8))
                    )
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.88), value: showsContextualHome)
        .animation(.spring(response: 0.4, dampingFraction: 0.88), value: showsHomeInsteadOfInput)
    }
}
