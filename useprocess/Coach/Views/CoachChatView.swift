import SwiftUI
import UIKit

struct CoachChatView: View {
    @Binding var selectedSection: ProcessMainSection
    var isTabActive: Bool = true
    var onDismiss: (() -> Void)? = nil
    var onOpenProfile: () -> Void
    var onOpenWelcomePlan: (() -> Void)? = nil

    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var profileService: UnifiedProfileService

    @Bindable var viewModel: CoachChatViewModel
    @FocusState private var isInputFocused: Bool
    @State private var isCompactCameraPresented = false
    @State private var attachmentFlyImage: UIImage?
    @State private var messageContextMenu: CoachUserMessageContextState?
    @State private var showFaceScan = false
    @State private var showsCloseControl = false
    @Bindable private var session = AppSession.shared

    private let messageFont = Font.system(size: 17, weight: .regular)
    private let messageLineSpacing: CGFloat = 4

    init(
        selectedSection: Binding<ProcessMainSection>,
        viewModel: CoachChatViewModel,
        isTabActive: Bool = true,
        onDismiss: (() -> Void)? = nil,
        onOpenProfile: @escaping () -> Void,
        onOpenWelcomePlan: (() -> Void)? = nil
    ) {
        _selectedSection = selectedSection
        self.viewModel = viewModel
        self.isTabActive = isTabActive
        self.onDismiss = onDismiss
        self.onOpenProfile = onOpenProfile
        self.onOpenWelcomePlan = onOpenWelcomePlan
    }

    var body: some View {
        coachRoot
            .overlay(alignment: .topTrailing) {
                coachCloseChrome
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: selectedSection) { _, section in
                guard section != .coach else { return }
                dismissCoachKeyboard()
            }
            .onDisappear {
                dismissCoachKeyboard()
            }
    }

    private var coachRoot: some View {
        chatScrollLayer
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if isCompactCameraPresented,
                   !viewModel.isVoiceRecording,
                   !viewModel.isVoiceExiting {
                    CoachInlineBottomCameraPanel(
                        panelHeight: coachInlineCameraHeight,
                        onCapture: handleCapturedPhoto,
                        onPickFromGallery: handleCapturedPhoto,
                        onCancel: {
                            withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                                isCompactCameraPresented = false
                            }
                        }
                    )
                    .background(Color.black)
                    .ignoresSafeArea(edges: .bottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    coachBottomBar
                }
            }
            .overlay {
                coachMessageContextOverlay
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
            .ios26SafeAnimation(.spring(response: 0.34, dampingFraction: 0.86), value: isCompactCameraPresented)
            .onAppear {
                updateCoachPresentation(active: isTabActive)
                presentCloseControlIfNeeded(animated: false)
                if isTabActive {
                    focusChatInputIfAppropriate(delay: 0.18)
                }
            }
            .onDisappear {
                CoachPresentationTracker.shared.isCoachChatActive = false
            }
            .onChange(of: isTabActive) { _, active in
                updateCoachPresentation(active: active)
                if active {
                    presentCloseControlIfNeeded()
                } else {
                    showsCloseControl = false
                }
                guard active else {
                    dismissCoachKeyboard()
                    return
                }
                focusChatInputIfAppropriate(delay: 0.08)
            }
            .onChange(of: viewModel.activeConversationId) { _, id in
                CoachPresentationTracker.shared.activeConversationId = id
            }
            .onChange(of: viewModel.shouldOpenInlineCamera) { _, shouldOpen in
                guard shouldOpen else { return }
                viewModel.shouldOpenInlineCamera = false
                dismissCoachKeyboard()
                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                    isCompactCameraPresented = true
                }
            }
            .task(id: isTabActive) {
                guard isTabActive else { return }
                viewModel.bind(profile: profileService.currentProfile)
                await viewModel.loadThreadIfNeeded()
                if !viewModel.messages.contains(where: FaceScanCoachInsightService.isCoachInsightMessage) {
                    _ = await CoachEveningChecklistService.deliverEveningMessageIfNeeded()
                }
            }
            .onChange(of: profileService.currentProfile?.userId) { _, _ in
                viewModel.bind(profile: profileService.currentProfile)
                Task { await viewModel.loadThreadIfNeeded() }
            }
            .onChange(of: CoachPlanNavigationBridge.shared.shouldOpenCoach) { _, should in
                guard should else { return }
                Task { await viewModel.consumePendingNavigationIfNeeded() }
            }
            .onChange(of: CoachPlanNavigationBridge.shared.coachNavigationNonce) { _, _ in
                Task { await viewModel.consumePendingNavigationIfNeeded() }
            }
            .onChange(of: CoachPlanNavigationBridge.shared.shouldOpenFaceScan) { _, should in
                guard should else { return }
                CoachPlanNavigationBridge.shared.shouldOpenFaceScan = false
                CoachPlanNavigationBridge.shared.requestHomeFaceScan()
            }
            .onChange(of: CoachPlanNavigationBridge.shared.shouldOpenTracking) { _, should in
                guard should else { return }
                CoachPlanNavigationBridge.shared.shouldOpenTracking = false
                selectedSection = .statistics
            }
            .onChange(of: session.hasCompletedWelcomePlanChat) { _, completed in
                guard completed else { return }
                Task {
                    viewModel.bind(profile: profileService.currentProfile)
                    await viewModel.loadThreadIfNeeded()
                    focusChatInputIfAppropriate(delay: 0.2)
                }
            }
            .fullScreenCover(isPresented: $showFaceScan) {
                FaceScanPrivacyGateView(
                    onDismiss: { showFaceScan = false },
                    onComplete: { result in
                        showFaceScan = false
                        FaceScanHistoryStore.shared.reloadForUser(userId: profileService.currentProfile?.userId)
                        Task {
                            await viewModel.sendFaceScanHandoff(for: result)
                        }
                    },
                    skipResultSheet: true
                )
                .environmentObject(profileService)
            }
    }

    private func handleCapturedPhoto(_ image: UIImage) {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            isCompactCameraPresented = false
        }
        attachmentFlyImage = image
    }

    private var coachInlineCameraHeight: CGFloat {
        max(420, UIScreen.main.bounds.height * 0.62)
    }

    @ViewBuilder
    private var coachCloseChrome: some View {
        if onDismiss != nil, isTabActive {
            coachCloseButton
                .padding(.top, 6)
                .padding(.trailing, 16)
                .opacity(showsCloseControl ? 1 : 0)
                .scaleEffect(showsCloseControl ? 1 : 0.9)
                .offset(y: showsCloseControl ? 0 : -8)
                .allowsHitTesting(showsCloseControl)
                .animation(.spring(response: 0.42, dampingFraction: 0.86), value: showsCloseControl)
        }
    }

    private var coachCloseButton: some View {
        ProcessGlassIconButton(systemName: "xmark", size: 34, iconSize: 13) {
            HapticManager.shared.impact(.light)
            dismissCoachKeyboard()
            onDismiss?()
        }
        .accessibilityLabel(AppCopy.t("Quitter Process IA", en: "Exit Process AI"))
    }

    private func presentCloseControlIfNeeded(animated: Bool = true) {
        guard onDismiss != nil, isTabActive else {
            showsCloseControl = false
            return
        }
        if animated {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86).delay(0.06)) {
                showsCloseControl = true
            }
        } else {
            showsCloseControl = true
        }
    }

    private var coachBottomBar: some View {
        VStack(spacing: 6) {
            if viewModel.showsContextualHome, !viewModel.homePrompt.suggestions.isEmpty {
                CoachHomeSuggestionBar(
                    suggestions: viewModel.homePrompt.suggestions,
                    isDisabled: viewModel.isSending,
                    onSelect: { suggestion in
                        isInputFocused = false
                        if suggestion.id == "scan" {
                            showFaceScan = true
                            return
                        }
                        Task { await viewModel.sendHomeSuggestion(suggestion) }
                    }
                )
            }

            coachChatInputBar
        }
        .padding(.bottom, isInputFocused ? 8 : 0)
        .animation(.easeOut(duration: 0.22), value: isInputFocused)
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

    private func updateCoachPresentation(active: Bool) {
        CoachPresentationTracker.shared.isCoachChatActive = active
        if active {
            CoachPresentationTracker.shared.activeConversationId = viewModel.activeConversationId
        } else {
            dismissCoachKeyboard()
        }
    }

    private var chatScrollLayer: some View {
        activeConversationScroll
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture().onEnded {
                    dismissCoachKeyboard()
                }
            )
            .onChange(of: viewModel.activeConversationId) { _, _ in
                viewModel.onActiveConversationChanged()
            }
    }

    private var activeConversationScroll: some View {
        let topSpacings = messageTopSpacings
        let faceScansByID = faceScanResultsByID

        return VStack(spacing: 0) {
            ScrollViewReader { proxy in
                processMainScrollableChrome(
                    selectedSection: $selectedSection,
                    pageSection: .coach,
                    dismissesKeyboard: .interactively,
                    scrollDisabled: messageContextMenu != nil,
                    adoptsFloatingTabBar: false
                ) {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        if viewModel.showsContextualHome {
                            CoachContextualHomeView(
                                prompt: viewModel.homePrompt,
                                mealHandoff: viewModel.activeMealHandoff,
                                embeddedInScroll: true
                            )
                        }

                        if !viewModel.claudeConfigured {
                            configurationBanner
                        }

                        ForEach(viewModel.messages) { message in
                            messageRow(message, faceScansByID: faceScansByID)
                                .padding(.top, topSpacings[message.id] ?? 0)
                                .id(message.id)
                        }

                        if viewModel.isSending {
                            CoachThinkingDotsView()
                                .padding(.top, pendingAssistantReplySpacing)
                                .id("thinking")
                                .transition(.opacity)
                        }

                        Color.clear
                            .frame(height: scrollBottomInset)
                            .id("bottom-spacer")
                    }
                    .id(viewModel.activeConversationId?.uuidString ?? "coach-no-conversation")
                    .padding(.leading, 16)
                    .padding(.trailing, 6)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                }
                .defaultScrollAnchor(
                    viewModel.showsContextualHome && viewModel.messages.isEmpty ? .top : .bottom
                )
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
                .onChange(of: viewModel.isSending) { wasSending, sending in
                    if sending, !wasSending {
                        isInputFocused = false
                        scrollToBottom(proxy, delay: 0.08)
                    } else if wasSending, !sending {
                        scrollToBottom(proxy, delay: 0.05)
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
        .coordinateSpace(name: "coachChatRoot")
    }

    private var coachChatInputBar: some View {
        CoachLiquidGlassInputBar(
            text: $viewModel.inputText,
            isFocused: $isInputFocused,
            pendingImages: viewModel.pendingAttachmentImages,
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
            onRemovePendingImageAt: { index in
                viewModel.removePendingAttachment(at: index)
            }
        )
        .padding(.horizontal, 14)
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: viewModel.pendingAttachmentImages.count)
    }

    private enum CoachMessageSpacing {
        static let userToAssistant: CGFloat = 24
        static let assistantToUser: CGFloat = 10
    }

    private var pendingAssistantReplySpacing: CGFloat {
        viewModel.messages.last?.role == .user ? CoachMessageSpacing.userToAssistant : 0
    }

    private var messageTopSpacings: [UUID: CGFloat] {
        var result: [UUID: CGFloat] = [:]
        guard viewModel.messages.count > 1 else { return result }

        for index in 1..<viewModel.messages.count {
            let previous = viewModel.messages[index - 1]
            let current = viewModel.messages[index]
            if previous.role == .user, current.role == .assistant {
                result[current.id] = CoachMessageSpacing.userToAssistant
            } else if previous.role == .assistant, current.role == .user {
                result[current.id] = CoachMessageSpacing.assistantToUser
            }
        }
        return result
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

    private func focusChatInputIfAppropriate(delay: TimeInterval = 0.32) {
        guard canPresentChatInputKeyboard else { return }

        Task { @MainActor in
            if delay > 0 {
                let nanoseconds = UInt64(delay * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
            }
            guard canPresentChatInputKeyboard else { return }
            isInputFocused = true
        }
    }

    private var canPresentChatInputKeyboard: Bool {
        CoachPresentationTracker.shared.isCoachChatActive
            && !isCompactCameraPresented
            && !viewModel.isVoiceRecording
            && !viewModel.isVoiceExiting
    }

    private var scrollBottomInset: CGFloat { 16 }

    private var faceScanResultsByID: [String: FaceScanResult] {
        Dictionary(uniqueKeysWithValues: FaceScanHistoryStore.shared.history.map { ($0.id, $0) })
    }

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
            Text(AppCopy.t("Le coach est momentanément indisponible. Réessaie dans quelques instants.", en: "The coach is temporarily unavailable. Try again in a moment."))
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func messageRow(_ message: CoachMessage, faceScansByID: [String: FaceScanResult]) -> some View {
        let isUser = message.role == .user

        if isUser {
            if let scanId = CoachFaceScanMessageMarker.scanId(from: message.text),
               let result = faceScansByID[scanId] {
                CoachFaceScanUserMessageView(
                    message: message,
                    result: result,
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
            } else if let imageMessageId = CoachChatImageMessageMarker.messageId(from: message.text) {
                let images = CoachChatAttachmentImageStore.load(messageId: imageMessageId)
                if !images.isEmpty {
                    CoachChatImageUserMessageView(
                        message: message,
                        images: images,
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
                } else {
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
                }
            } else {
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
            }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                CoachAssistantMessageBody(
                    text: assistantDisplayText(for: message),
                    font: messageFont,
                    lineSpacing: messageLineSpacing,
                    color: theme.primaryText
                )

                if CoachEveningChecklistService.isEveningMessage(message) {
                    CoachEveningChecklistCard()
                        .padding(.top, 10)
                }

                if let enrichment = viewModel.enrichment(for: message) {
                    CoachMessageEnrichmentView(
                        enrichment: enrichment,
                        showsFollowUps: CoachIntelligenceSettingsStore.shared.showsSuggestedFollowUps,
                        onFollowUp: { question in
                            Task { await viewModel.sendFollowUp(question) }
                        },
                        onDeepLink: { link in
                            handleCoachDeepLink(link)
                        },
                        onContextualAction: { action in
                            Task { await handleContextualAction(action, for: message) }
                        }
                    )
                }
            }
            .coachMessageFadeIn()
            .transition(
                .opacity
                    .combined(with: .offset(y: 10))
                    .combined(with: .scale(scale: 0.98, anchor: .topLeading))
            )
        }
    }

    /// Affiche uniquement la prose — jamais de fiche repas structurée héritée.
    private func assistantDisplayText(for message: CoachMessage) -> String {
        if let intro = CoachMealMessageDetector.coachIntro(from: message.text),
           CoachMealMessageDetector.mealContent(from: message.text) != nil {
            return intro
        }
        let stripped = MealSuggestionParser.stripStructuredMealBlock(from: message.text)
        let cleaned = CoachResponseParser.parse(stripped).displayText
        if !cleaned.isEmpty { return cleaned }
        if !stripped.isEmpty { return stripped }
        return message.text
    }

    private func precedingUserText(before message: CoachMessage) -> String? {
        guard let index = viewModel.messages.firstIndex(where: { $0.id == message.id }) else {
            return nil
        }
        return viewModel.messages
            .prefix(index)
            .reversed()
            .first(where: { $0.role == .user })?
            .text
    }

    private func handleCoachDeepLink(_ link: CoachDeepLink) {
        switch link.action {
        case .plan:
            break
        case .journal:
            selectedSection = .plan
            onOpenWelcomePlan?()
        case .scan:
            CoachPlanNavigationBridge.shared.requestHomeFaceScan()
        case .streak:
            CoachPlanNavigationBridge.shared.openProfileStatistics()
            selectedSection = .statistics
        case .integration:
            break
        }
    }

    private func handleContextualAction(_ action: CoachContextualAction, for message: CoachMessage) async {
        switch action.kind {
        case .openPlan:
            break
        case .openJournal:
            selectedSection = .plan
            onOpenWelcomePlan?()
        default:
            await viewModel.executeContextualAction(action, for: message)
            if action.kind == .modifyMeal || action.kind == .followUp {
                isInputFocused = true
            }
        }
    }
}
