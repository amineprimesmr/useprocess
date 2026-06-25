import SwiftUI
import UIKit

struct CoachChatView: View {
    @Binding var selectedSection: ProcessMainSection
    var onOpenProfile: () -> Void
    var onOpenWelcomePlan: (() -> Void)? = nil

    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var profileService: UnifiedProfileService
    @Bindable private var sidebarPresentation = CoachSidebarPresentation.shared

    @State private var viewModel = CoachChatViewModel()
    @FocusState private var isInputFocused: Bool
    @State private var thinkingBlobStart = Date.now
    @State private var isCompactCameraPresented = false
    @State private var attachmentFlyImage: UIImage?
    @State private var messageContextMenu: CoachUserMessageContextState?
    @State private var showFaceScan = false
    @State private var isSidebarExpanded = false
    @State private var showsIntegrationFlow = false
    @State private var sidebarPresentedSheet: CoachSidebarDestination?
    @Bindable private var planStore = WelcomePlanStore.shared
    @Bindable private var session = AppSession.shared

    private let messageFont = Font.system(size: 17, weight: .regular)
    private let messageLineSpacing: CGFloat = 4

    private var isCoachSidebarPresenting: Bool {
        isSidebarExpanded || sidebarPresentation.progress > 0.01
    }

    var body: some View {
        coachMainContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: selectedSection) { _, section in
                guard section != .coach else { return }
                dismissCoachKeyboard()
            }
            .onDisappear {
                dismissCoachKeyboard()
            }
    }

    private let coachSidebarWidth: CGFloat = 300

    private var coachMainContent: some View {
        CustomSideMenu(
            isEnabled: viewModel.isSidebarEnabled,
            sideBarWidth: coachSidebarWidth,
            isExpanded: $isSidebarExpanded
        ) { _ in
            coachSidebar
        } content: { _ in
            coachContentLayer
        }
        .overlay {
            if !isCoachSidebarPresenting {
                coachMessageContextOverlay
            }
        }
        .overlay {
            if let image = attachmentFlyImage {
                CoachPhotoShrinkToInputAnimation(
                    image: image,
                    cameraPanelHeight: coachInlineCameraHeight,
                    onComplete: {
                        attachmentFlyImage = nil
                        viewModel.stageImageAttachment(image)
                        isInputFocused = true
                    }
                )
                .zIndex(300)
            }
        }
        .ios26SafeAnimation(.spring(response: 0.32, dampingFraction: 0.86), value: messageContextMenu != nil)
        .onAppear {
            planStore.reloadForCurrentUser()
            CoachPresentationTracker.shared.isCoachChatActive = true
            CoachPresentationTracker.shared.activeConversationId = viewModel.activeConversationId
        }
        .onDisappear {
            CoachPresentationTracker.shared.isCoachChatActive = false
        }
        .onChange(of: viewModel.activeConversationId) { _, id in
            CoachPresentationTracker.shared.activeConversationId = id
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            viewModel.bind(profile: profileService.currentProfile)
            await viewModel.loadThreadIfNeeded()
            await viewModel.consumePendingNavigationIfNeeded()
        }
        .onChange(of: profileService.currentProfile?.userId) { _, _ in
            viewModel.bind(profile: profileService.currentProfile)
            Task { await viewModel.loadThreadIfNeeded() }
        }
        .onChange(of: isSidebarExpanded) { _, expanded in
            guard expanded else { return }
            isCompactCameraPresented = false
            messageContextMenu = nil
            dismissCoachKeyboard()
        }
        .onChange(of: CoachPlanNavigationBridge.shared.shouldOpenCoach) { _, should in
            guard should else { return }
            Task { await viewModel.consumePendingNavigationIfNeeded() }
        }
        .onChange(of: CoachPlanNavigationBridge.shared.shouldOpenFaceScan) { _, should in
            guard should else { return }
            showFaceScan = true
            CoachPlanNavigationBridge.shared.shouldOpenFaceScan = false
        }
        .onChange(of: CoachPlanNavigationBridge.shared.shouldOpenIntegration) { _, should in
            guard should else { return }
            showsIntegrationFlow = true
            CoachPlanNavigationBridge.shared.shouldOpenIntegration = false
        }
        .onChange(of: CoachPlanNavigationBridge.shared.shouldOpenTracking) { _, should in
            guard should else { return }
            isSidebarExpanded = true
            sidebarPresentedSheet = .tracking
            CoachPlanNavigationBridge.shared.shouldOpenTracking = false
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
        .fullScreenCover(isPresented: $showsIntegrationFlow) {
            coachIntegrationFlow
        }
    }

    private var coachIntegrationFlow: some View {
        NavigationStack {
            WelcomePlanChatView(
                embeddedInMainApp: true,
                selectedSection: nil,
                onComplete: {
                    planStore.reloadForCurrentUser()
                    showsIntegrationFlow = false
                }
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        planStore.reloadForCurrentUser()
                        showsIntegrationFlow = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(theme.primaryText)
                            .frame(width: 34, height: 34)
                            .background(
                                Circle()
                                    .fill(theme.cardBackgroundStrong.opacity(theme.isDark ? 0.95 : 0.82))
                            )
                    }
                    .accessibilityLabel("Fermer l'intégration")
                }
            }
        }
        .environmentObject(profileService)
    }

    private func handleCapturedPhoto(_ image: UIImage) {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            isCompactCameraPresented = false
        }
        attachmentFlyImage = image
    }

    private var coachInlineCameraHeight: CGFloat {
        max(320, UIScreen.main.bounds.height * 0.55)
    }

    private var coachContentLayer: some View {
        chatScrollLayer
            .overlay {
                if isCompactCameraPresented {
                    Color.black.opacity(0.14)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if isCompactCameraPresented,
                   !isCoachSidebarPresenting,
                   !viewModel.showsHomeInsteadOfInput,
                   !viewModel.isVoiceRecording,
                   !viewModel.isVoiceExiting {
                    CoachInlineBottomCameraPanel(
                        panelHeight: coachInlineCameraHeight,
                        onCapture: { image in
                            handleCapturedPhoto(image)
                        },
                        onCancel: {
                            withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                                isCompactCameraPresented = false
                            }
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    coachBottomAccessoryView
                        .padding(.bottom, isInputFocused ? 12 : 8)
                }
            }
            .ios26SafeAnimation(.spring(response: 0.34, dampingFraction: 0.86), value: isCompactCameraPresented)
            .overlay(alignment: .topLeading) {
            if viewModel.isSidebarEnabled, !isCoachSidebarPresenting {
                coachMenuButton
                    .padding(.top, ProcessMainChromeMetrics.topSafeInset + 2)
                    .padding(.leading, 16)
                    .zIndex(20)
            }
        }
    }

    private var coachMenuButton: some View {
        ProcessGlassIconButton(systemName: "line.3.horizontal", size: 34, iconSize: 14) {
            HapticManager.shared.impact(.light)
            dismissCoachKeyboard()
            isSidebarExpanded = true
        }
        .accessibilityLabel("Ouvrir le menu")
    }

    private var coachSidebar: some View {
        CoachConversationsSidebar(
            isExpanded: $isSidebarExpanded,
            conversations: viewModel.conversations,
            activeConversationId: viewModel.activeConversationId,
            integrationProgress: integrationProgress,
            isIntegrationComplete: isIntegrationComplete,
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
            onOpenIntegration: {
                showsIntegrationFlow = true
            },
            onDeleteAllConversations: {
                await viewModel.deleteAllConversations()
            },
            onDeleteAllFiles: {
                CoachIntelligenceSettingsStore.shared.deleteAllCoachFiles(userId: profileService.currentProfile?.userId)
            },
            onResyncHistory: {
                await viewModel.resyncConversationHistory()
            },
            activeDestination: sidebarActiveDestination,
            presentedSheet: $sidebarPresentedSheet
        )
    }

    private var sidebarActiveDestination: CoachSidebarDestination? {
        if showsIntegrationFlow { return .integration }
        return sidebarPresentedSheet
    }

    private var isIntegrationComplete: Bool {
        session.hasCompletedWelcomePlanChat
            || (planStore.plan != nil && WelcomePlanQuestionBank.isFullyAnswered(answers: planStore.questionnaire.answers))
    }

    private var integrationProgress: Double {
        WelcomePlanQuestionBank.configurationProgress(
            answers: planStore.questionnaire.answers,
            isComplete: isIntegrationComplete
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

    private var coachConversationTopInset: CGFloat {
        ProcessMainChromeMetrics.topSafeInset + 96
    }

    private var chatScrollLayer: some View {
        ZStack(alignment: .top) {
            OnboardingChatAmbientHeader(
                topInset: ProcessMainChromeMetrics.topSafeInset,
                compact: true
            )
            .zIndex(0)

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
                .zIndex(1)
                .transition(.opacity.combined(with: .offset(y: 6)))
            } else {
                activeConversationScroll
                    .zIndex(1)
                    .transition(.opacity.combined(with: .offset(y: 8)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background.ignoresSafeArea())
        .ignoresSafeArea(edges: .top)
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture().onEnded {
                dismissCoachKeyboard()
            }
        )
        .ios26SafeAnimation(.spring(response: 0.42, dampingFraction: 0.88), value: viewModel.showsContextualHome)
        .ios26SafeAnimation(.spring(response: 0.42, dampingFraction: 0.88), value: viewModel.isComposingMessage)
        .onChange(of: viewModel.activeConversationId) { _, _ in
            viewModel.onActiveConversationChanged()
        }
        .onChange(of: viewModel.homePrompt.greetingText) { old, new in
            guard old != new else { return }
            viewModel.syncHomePresentationFromCache()
        }
    }

    private var activeConversationScroll: some View {
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

                        ForEach(viewModel.messages) { message in
                            messageRow(message)
                                .padding(.top, messageTopSpacing(before: message))
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
                    .padding(.bottom, 12)
                }
                .defaultScrollAnchor(.bottom)
                .safeAreaInset(edge: .top, spacing: 0) {
                    Color.clear.frame(height: coachConversationTopInset)
                }
                .mask(conversationScrollFadeMask)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .simultaneousGesture(
                    TapGesture().onEnded {
                        dismissCoachKeyboard()
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
        .coordinateSpace(name: "coachChatRoot")
    }

    private var conversationScrollFadeMask: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                .frame(height: coachConversationTopInset * 0.45)
            Rectangle().fill(.black)
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
            voiceAudioLevel: viewModel.voiceAudioLevel,
            voiceAudioLevels: viewModel.voiceAudioLevels,
            onSend: {
                dismissCoachKeyboard()
                Task { await viewModel.sendCurrentMessage() }
            },
            onStartVoice: {
                isCompactCameraPresented = false
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
            onOpenCamera: {
                dismissCoachKeyboard()
                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                    isCompactCameraPresented = true
                }
            },
            onRemovePendingImage: {
                viewModel.clearPendingAttachment()
            }
        )
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: viewModel.pendingAttachmentImage != nil)
        .animation(.easeInOut(duration: 0.22), value: isInputFocused)
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

    private func messageTopSpacing(before message: CoachMessage) -> CGFloat {
        guard let index = viewModel.messages.firstIndex(where: { $0.id == message.id }),
              index > 0,
              index < viewModel.messages.count else {
            return 0
        }

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

    private func dismissCoachKeyboard() {
        isInputFocused = false
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    private var scrollBottomInset: CGFloat { 20 }

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
            VStack(alignment: .leading, spacing: 0) {
                CoachFormattedText(
                    text: message.text,
                    font: messageFont,
                    lineSpacing: messageLineSpacing,
                    color: theme.primaryText
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)

                if let enrichment = viewModel.enrichment(for: message) {
                    CoachMessageEnrichmentView(
                        enrichment: enrichment,
                        showsReasoning: CoachIntelligenceSettingsStore.shared.showsExtendedReasoning,
                        showsFollowUps: CoachIntelligenceSettingsStore.shared.showsSuggestedFollowUps,
                        onFollowUp: { question in
                            Task { await viewModel.sendFollowUp(question) }
                        },
                        onDeepLink: { link in
                            handleCoachDeepLink(link)
                        }
                    )
                }
            }
        }
    }

    private func handleCoachDeepLink(_ link: CoachDeepLink) {
        switch link.action {
        case .plan, .journal:
            selectedSection = .plan
            onOpenWelcomePlan?()
        case .scan:
            showFaceScan = true
        case .streak:
            isSidebarExpanded = true
            sidebarPresentedSheet = .tracking
        case .integration:
            showsIntegrationFlow = true
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
        .ios26SafeAnimation(.spring(response: 0.42, dampingFraction: 0.88), value: showsContextualHome)
    }
}
