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

private struct CoachBottomChromeHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 110

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
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
    @State private var messageContextMenu: CoachUserMessageContextState?
    @State private var showFaceScan = false
    @State private var isSidebarExpanded = false
    @State private var planStore = WelcomePlanStore.shared
    @State private var bottomChromeHeight: CGFloat = 110

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
            guard completed else { return }
            Task {
                viewModel.bind(profile: profileService.currentProfile)
                await viewModel.loadThreadIfNeeded()
            }
        }
    }

    private func dismissWelcomePlanChat() {
        Task {
            viewModel.bind(profile: profileService.currentProfile)
            await viewModel.loadThreadIfNeeded()
        }
    }

    private let coachSidebarWidth: CGFloat = 300

    private var coachMainContent: some View {
        ZStack(alignment: .bottom) {
            CustomSideMenu(
                isEnabled: viewModel.isSidebarEnabled,
                sideBarWidth: coachSidebarWidth,
                isExpanded: $isSidebarExpanded
            ) { _ in
                coachSidebar
            } content: { _ in
                chatScrollLayer
            }
            .overlay {
                coachMessageContextOverlay
            }
            .ios26SafeAnimation(.spring(response: 0.32, dampingFraction: 0.86), value: messageContextMenu != nil)

            coachBottomAccessoryView
                .background {
                    GeometryReader { proxy in
                        Color.clear
                            .preference(key: CoachBottomChromeHeightKey.self, value: proxy.size.height)
                    }
                }
                .zIndex(5)
        }
        .onPreferenceChange(CoachBottomChromeHeightKey.self) { height in
            if height > 0 {
                bottomChromeHeight = height
            }
        }
        .overlay {
            if showAttachmentMenu,
               !viewModel.showsHomeInsteadOfInput,
               !viewModel.isVoiceRecording,
               !viewModel.isVoiceExiting {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showAttachmentMenu = false
                    }
            }
        }
        .overlay(alignment: .bottomLeading) {
            if showAttachmentMenu,
               !viewModel.showsHomeInsteadOfInput,
               !viewModel.isVoiceRecording,
               !viewModel.isVoiceExiting {
                CoachAttachmentGlassPopover { option in
                    showAttachmentMenu = false
                    handleAttachmentOption(option)
                }
                .padding(.leading, 28)
                .padding(.bottom, bottomChromeHeight + 18)
                .transition(
                    .scale(scale: 0.88, anchor: .bottomLeading)
                        .combined(with: .opacity)
                )
            }
        }
        .ios26SafeAnimation(ProcessGlass.spring, value: showAttachmentMenu)
        .onAppear {
            planStore.reloadForCurrentUser()
        }
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
                messageContextMenu = nil
                isInputFocused = false
                Task { await viewModel.deleteConversation(id) }
            },
            onOpenProfile: onOpenProfile
        )
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

    @ViewBuilder
    private var coachBottomAccessoryView: some View {
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

    private var chatScrollLayer: some View {
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
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: bottomChromeHeight)
        }
        .ios26SafeAnimation(.spring(response: 0.42, dampingFraction: 0.88), value: viewModel.showsContextualHome)
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
                                CoachChatThinkingBlobRow(start: thinkingBlobStart)
                                    .padding(.top, pendingAssistantReplySpacing)
                                    .id("thinking")
                            }

                            Color.clear
                                .frame(height: scrollBottomInset)
                                .id("bottom-spacer")
                        }
                        .id(viewModel.activeConversationId?.uuidString ?? "coach-no-conversation")
                        .padding(.leading, 16)
                        .padding(.trailing, 6)
                        .padding(.vertical, 12)
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
                            thinkingBlobStart = .now
                            isInputFocused = false
                            scrollToBottom(proxy, delay: 0.08)
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
                showAttachmentMenu = false
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
                showAttachmentMenu.toggle()
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
                .processGlassButton(in: Capsule())
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
        .ios26SafeAnimation(.spring(response: 0.4, dampingFraction: 0.88), value: showsHomeInsteadOfInput)
    }
}