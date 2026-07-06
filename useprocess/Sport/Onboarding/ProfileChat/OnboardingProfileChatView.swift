//
//  OnboardingProfileChatView.swift
//  useprocess
//

import SwiftUI

struct OnboardingProfileChatView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var onboardingViewModel: OnboardingViewModel
    @EnvironmentObject private var healthManager: HealthManager
    @EnvironmentObject private var permissionsManager: PermissionsManager
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var profileService: UnifiedProfileService
    var onComplete: () -> Void

    @State private var chatViewModel = OnboardingProfileChatViewModel()
    @State private var multiSelection: Set<String> = []
    @State private var isSportSearchActive = false
    @State private var revealedAnswerIDs: Set<String> = []
    @State private var isSigningIn = false
    @State private var signInError: String?
    @State private var faceScanScrollProxy: ScrollViewProxy?

    private let messageLineSpacing: CGFloat = 7
    private let horizontalPadding: CGFloat = 28
    private let answerButtonShape = Capsule()

    var body: some View {
        GeometryReader { geometry in
            let layout = ChatLayoutMetrics(screenHeight: geometry.size.height)

            ZStack(alignment: .bottom) {
                OnboardingChatAmbientHeader(topInset: OnboardingConstants.headerBackButtonTopPadding)
                    .zIndex(0)

                if isSportSearchActive {
                    VStack(spacing: 0) {
                        Color.black.opacity(0.001)
                            .frame(height: max(0, geometry.size.height * 0.42))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                dismissSportSearch()
                            }
                        Spacer(minLength: 0)
                    }
                    .ignoresSafeArea()
                }

                standardChatLayout(layout: layout)
                    .zIndex(1)

                if chatViewModel.showsContinueAfterAnalysis {
                    VStack(spacing: 10) {
                        Text("Connecte-toi pour sauvegarder tes réponses et retrouver ton programme sur tous tes appareils.")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(OnboardingTheme.mutedText.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)

                        continueAfterAnalysisButton
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, 50)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .zIndex(5)
                }
            }
            .animation(OnboardingProfileChatAnswerReveal.spring, value: chatViewModel.showsContinueAfterAnalysis)
            .animation(OnboardingProfileChatAnswerReveal.spring, value: chatViewModel.showsAnalysisSection)
            .ignoresSafeArea(edges: .top)
            .clipped()
            .onChange(of: chatViewModel.shouldFinish) { _, should in
                guard should else { return }
                chatViewModel.finish(onComplete: onComplete)
            }
            .onChange(of: chatViewModel.currentQuestion?.id) { _, _ in
                multiSelection = []
                isSportSearchActive = false
                revealedAnswerIDs = []
            }
            .onChange(of: chatViewModel.faceScanInlinePhase) { _, phase in
                guard phase != .idle else { return }
                scrollFaceScanFlow(to: phase)
            }
            .onChange(of: chatViewModel.inlineFaceScanResultsUnlocked) { _, unlocked in
                guard unlocked else { return }
                scrollFaceScanFlow(to: .results, preferContinueButton: true)
            }
            .onChange(of: chatViewModel.inlineFaceScanPhaseIndex) { _, _ in
                guard chatViewModel.faceScanInlinePhase == .analyzing else { return }
                scrollFaceScanFlow(to: .analyzing)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert("Connexion impossible", isPresented: Binding(
            get: { signInError != nil },
            set: { if !$0 { signInError = nil } }
        )) {
            Button("OK", role: .cancel) { signInError = nil }
        } message: {
            Text(signInError ?? "")
        }
        .task(id: onboardingViewModel.currentStep) {
            chatViewModel.bind(
                onboardingViewModel,
                healthManager: healthManager,
                permissionsManager: permissionsManager
            )
            onboardingViewModel.syncInferredWeightGoal()
            await chatViewModel.startIfNeeded()
        }
    }

    // MARK: - Layout modes

    @ViewBuilder
    private func standardChatLayout(layout: ChatLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: layout.slotSpacing) {
            historySlot(
                height: chatViewModel.showsInlineFaceScanFlow
                    ? layout.compactHistorySlotHeight
                    : layout.historySlotHeight
            )
            activeSlot(layout: layout, bottomPadding: chatViewModel.showsContinueAfterAnalysis ? 110 : 36)
            Spacer(minLength: 0)
        }
        .animation(OnboardingProfileChatDepthStyle.historySpring, value: chatViewModel.messages.count)
        .animation(OnboardingProfileChatDepthStyle.historySpring, value: chatViewModel.showsInlineFaceScanFlow)
        .padding(.horizontal, horizontalPadding)
        .padding(.top, layout.contentTopPadding + OnboardingConstants.backOnlyContentTopInset)
        .padding(.bottom, chatViewModel.showsContinueAfterAnalysis ? 110 : 36)
        .animation(OnboardingProfileChatAnswerReveal.spring, value: chatViewModel.showsContinueAfterAnalysis)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .regularWidthContainer(maxWidth: AdaptiveScreenLayout.onboardingChatMaxWidth)
        .mask(topFadeMask)
    }

    // MARK: - Layout slots

    private struct ChatLayoutMetrics {
        let screenHeight: CGFloat
        let activeAnchorY: CGFloat
        let historySlotHeight: CGFloat
        let compactHistorySlotHeight: CGFloat
        let slotSpacing: CGFloat
        let contentTopPadding: CGFloat

        init(screenHeight: CGFloat) {
            self.screenHeight = screenHeight
            let chromeInset = OnboardingConstants.backOnlyContentTopInset
            activeAnchorY = screenHeight * 0.36
            historySlotHeight = screenHeight * 0.20
            compactHistorySlotHeight = min(72, historySlotHeight * 0.42)
            slotSpacing = 8
            contentTopPadding = max(4, activeAnchorY - chromeInset - historySlotHeight - slotSpacing)
        }

        func answersScrollMaxHeight(bottomPadding: CGFloat) -> CGFloat {
            OnboardingProfileChatDepthStyle.answersScrollMaxHeight(
                screenHeight: screenHeight,
                contentTopPadding: contentTopPadding + OnboardingConstants.backOnlyContentTopInset,
                historySlotHeight: historySlotHeight,
                slotSpacing: slotSpacing,
                bottomPadding: bottomPadding
            )
        }

        func faceScanActiveScrollMaxHeight(bottomPadding: CGFloat) -> CGFloat {
            let chrome = contentTopPadding + OnboardingConstants.backOnlyContentTopInset + bottomPadding
            return max(300, screenHeight - chrome - compactHistorySlotHeight - slotSpacing - 8)
        }
    }

    private func scrollFaceScanFlow(
        to phase: OnboardingProfileChatViewModel.FaceScanInlinePhase,
        preferContinueButton: Bool = false,
        proxy: ScrollViewProxy? = nil,
        animated: Bool = true
    ) {
        let activeProxy = proxy ?? faceScanScrollProxy
        guard let activeProxy else { return }

        let target: String = {
            if preferContinueButton { return FaceScanThreadAnchor.continueButton }
            switch phase {
            case .capturing: return FaceScanThreadAnchor.capturing
            case .analyzing: return FaceScanThreadAnchor.analyzing
            case .results: return FaceScanThreadAnchor.results
            case .idle: return FaceScanThreadAnchor.idle
            }
        }()

        let anchor: UnitPoint = (phase == .results || preferContinueButton) ? .bottom : .top

        let scrollAction = {
            activeProxy.scrollTo(target, anchor: anchor)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            scrollAction()
            if phase == .results || preferContinueButton {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    activeProxy.scrollTo(FaceScanThreadAnchor.bottom, anchor: .bottom)
                }
            }
        }
    }

    @ViewBuilder
    private func historySlot(height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: OnboardingProfileChatDepthStyle.messageSpacing) {
            ForEach(historyMessages, id: \.message.id) { item in
                let distance = (chatViewModel.messages.count - 1) - item.index
                depthMessageRow(item.message, distanceFromActive: distance)
            }
        }
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .bottomLeading)
        .clipped()
        .mask(historyFadeMask)
    }

    @ViewBuilder
    private func activeSlot(layout: ChatLayoutMetrics, bottomPadding: CGFloat) -> some View {
        let slotBody = activeSlotBody(layout: layout, bottomPadding: bottomPadding)

        if chatViewModel.showsInlineFaceScanFlow {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    slotBody
                        .padding(.bottom, 28)
                    Color.clear
                        .frame(height: 1)
                        .id(FaceScanThreadAnchor.bottom)
                }
                .scrollDismissesKeyboard(.interactively)
                .frame(maxHeight: layout.faceScanActiveScrollMaxHeight(bottomPadding: bottomPadding))
                .onAppear {
                    faceScanScrollProxy = proxy
                    scrollFaceScanFlow(
                        to: chatViewModel.faceScanInlinePhase,
                        proxy: proxy,
                        animated: false
                    )
                }
            }
        } else {
            slotBody
        }
    }

    @ViewBuilder
    private func activeSlotBody(layout: ChatLayoutMetrics, bottomPadding: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: OnboardingProfileChatDepthStyle.messageSpacing) {
            if let active = activeMessage {
                depthMessageRow(active, distanceFromActive: 0)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let question = chatViewModel.currentQuestion,
               chatViewModel.showsAnswerOptions || chatViewModel.showsInlineFaceScanSection {
                answerSection(
                    for: question,
                    maxScrollHeight: layout.answersScrollMaxHeight(bottomPadding: bottomPadding)
                )
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .task(id: answerRevealTaskID(for: question)) {
                        guard question.id != "face_scan_offer" || chatViewModel.faceScanInlinePhase == .idle else { return }
                        await runAnswerReveal(for: question)
                    }
            }

            if chatViewModel.showsProgramCreationSection {
                programCreationSection
                    .id("plan_creation_progress")
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            if chatViewModel.showsAnalysisSection {
                analysisSection
                    .id("analysis_progress")
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(OnboardingProfileChatAnswerReveal.spring, value: chatViewModel.showsProgramCreationSection)
        .animation(OnboardingProfileChatAnswerReveal.spring, value: chatViewModel.showsAnalysisSection)
        .animation(OnboardingProfileChatAnswerReveal.spring, value: chatViewModel.showsContinueAfterAnalysis)
        .animation(OnboardingProfileChatAnswerReveal.spring, value: chatViewModel.faceScanInlinePhase)
        .animation(.easeInOut(duration: 0.2), value: chatViewModel.analysisProgress)
        .animation(.easeInOut(duration: 0.2), value: chatViewModel.analysisDisplayedPercentage)
        .animation(.easeInOut(duration: 0.2), value: chatViewModel.inlineFaceScanProgress)
        .animation(.easeInOut(duration: 0.2), value: chatViewModel.inlineFaceScanDisplayedPercentage)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .animation(nil, value: chatViewModel.messages.last?.text)
    }

    private var activeMessage: OnboardingProfileChatMessage? {
        chatViewModel.messages.last
    }

    private var historyMessages: [(index: Int, message: OnboardingProfileChatMessage)] {
        guard chatViewModel.messages.count > 1 else { return [] }
        let history = Array(chatViewModel.messages.enumerated().dropLast())
        let maxHistory = OnboardingProfileChatDepthStyle.maxVisibleMessages - 1
        let start = max(0, history.count - maxHistory)
        return history.dropFirst(start).map { ($0.offset, $0.element) }
    }

    private var historyFadeMask: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [.clear, .black],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 32)

            Rectangle()
                .fill(.black)
        }
    }

    private func answerRevealTaskID(for question: OnboardingProfileChatQuestion) -> String {
        "\(question.id)-\(chatViewModel.showsAnswerOptions)"
    }

    @MainActor
    private func runAnswerReveal(for question: OnboardingProfileChatQuestion) async {
        revealedAnswerIDs = []
        let ids = OnboardingProfileChatAnswerReveal.orderedIDs(for: question)
        guard !ids.isEmpty else { return }

        try? await Task.sleep(nanoseconds: OnboardingProfileChatAnswerReveal.initialDelay)
        guard chatViewModel.showsAnswerOptions else { return }

        for (index, id) in ids.enumerated() {
            if Task.isCancelled { return }
            guard chatViewModel.showsAnswerOptions else { return }
            if index > 0 {
                try? await Task.sleep(nanoseconds: OnboardingProfileChatAnswerReveal.staggerDelay)
            }
            if Task.isCancelled { return }
            guard chatViewModel.showsAnswerOptions else { return }
            _ = withAnimation(OnboardingProfileChatAnswerReveal.spring) {
                revealedAnswerIDs.insert(id)
            }
        }
    }

    private func isAnswerRevealed(_ id: String) -> Bool {
        revealedAnswerIDs.contains(id)
    }

    private func dismissSportSearch() {
        guard isSportSearchActive else { return }
        HapticManager.shared.selection()
        isSportSearchActive = false
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    private var topFadeMask: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [.clear, .black],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 48)

            Rectangle()
                .fill(.black)
        }
    }

    // MARK: - Messages

    @ViewBuilder
    private func depthMessageRow(
        _ message: OnboardingProfileChatMessage,
        distanceFromActive: Int
    ) -> some View {
        let appearance = OnboardingProfileChatDepthStyle.appearance(
            distanceFromActive: distanceFromActive,
            role: message.role
        )

        if !appearance.isHidden {
            Group {
                let layoutText = message.layoutAnchorText ?? message.text
                let visibleText = message.text

                if layoutText.isEmpty && visibleText.isEmpty {
                    Color.clear
                        .frame(height: 1)
                } else {
                    ZStack(alignment: .topLeading) {
                        if !layoutText.isEmpty {
                            Text(layoutText)
                                .font(
                                    .system(
                                        size: OnboardingProfileChatDepthStyle.activeFontSize,
                                        weight: message.role == .user ? .medium : .regular
                                    )
                                )
                                .foregroundStyle(.clear)
                                .lineSpacing(messageLineSpacing)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityHidden(true)
                        }

                        if !visibleText.isEmpty {
                            Text(visibleText)
                                .font(.system(size: appearance.fontSize, weight: message.role == .user ? .medium : .regular))
                                .foregroundStyle(appearance.color)
                                .lineSpacing(messageLineSpacing)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .scaleEffect(appearance.scale, anchor: .leading)
                    .blur(radius: appearance.blur)
                    .opacity(visibleText.isEmpty ? 0 : appearance.opacity)
                }
            }
            .animation(OnboardingProfileChatDepthStyle.historySpring, value: distanceFromActive)
            .animation(nil, value: message.text)
        }
    }

    // MARK: - Answers

    @ViewBuilder
    private func answerSection(
        for question: OnboardingProfileChatQuestion,
        maxScrollHeight: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            switch question.kind {
            case .infoContinue:
                chatPrimaryButton("Continuer") {
                    await chatViewModel.submitInfoContinue()
                }
                .onboardingChatAnswerReveal(isRevealed: isAnswerRevealed("continue"))

            case .autoPlanCreation:
                EmptyView()

            case .yesNo:
                HStack(spacing: 12) {
                    chatChoiceButton(title: "Oui", emoji: nil, centered: true) {
                        await chatViewModel.submitYesNo(true)
                    }
                    .onboardingChatAnswerReveal(isRevealed: isAnswerRevealed("yes"))

                    chatChoiceButton(title: "Non", emoji: nil, centered: true) {
                        await chatViewModel.submitYesNo(false)
                    }
                    .onboardingChatAnswerReveal(isRevealed: isAnswerRevealed("no"))
                }

            case .singleChoice where question.id == "sport_pick":
                OnboardingProfileChatSportPicker(
                    isSearching: $isSportSearchActive,
                    isSubmitting: chatViewModel.isSubmittingAnswer,
                    revealedOptionIDs: revealedAnswerIDs,
                    onSelectFeatured: { choiceId in
                        Task { await chatViewModel.submitSingleChoice(choiceId) }
                    },
                    onSelectSearched: { sport in
                        Task { await chatViewModel.submitSearchedSport(sport) }
                    }
                )
                .id("sport_picker_\(question.id)")

            case .singleChoice:
                OnboardingChatScrollableAnswerStack(
                    choiceCount: question.choices.count,
                    maxHeight: maxScrollHeight
                ) {
                    ForEach(question.choices) { choice in
                        chatChoiceButton(title: choice.label, emoji: choice.emoji) {
                            await chatViewModel.submitSingleChoice(choice.id)
                        }
                        .onboardingChatAnswerReveal(isRevealed: isAnswerRevealed(choice.id))
                    }
                }

            case .multiChoice:
                OnboardingChatScrollableAnswerStack(
                    choiceCount: question.choices.count,
                    maxHeight: max(140, maxScrollHeight - 72)
                ) {
                    ForEach(question.choices) { choice in
                        chatMultiChoiceButton(
                            title: choice.label,
                            emoji: choice.emoji,
                            isSelected: multiSelection.contains(choice.id)
                        ) {
                            if multiSelection.contains(choice.id) {
                                multiSelection.remove(choice.id)
                            } else {
                                multiSelection.insert(choice.id)
                            }
                        }
                        .onboardingChatAnswerReveal(isRevealed: isAnswerRevealed(choice.id))
                    }
                }
                chatPrimaryButton("Valider", disabled: multiSelection.isEmpty, filled: true) {
                    let selection = multiSelection
                    multiSelection = []
                    await chatViewModel.submitMultiChoice(selection)
                }
                .onboardingChatAnswerReveal(isRevealed: isAnswerRevealed("validate"))

            case .faceScanOffer:
                OnboardingProfileChatInlineFaceScanSection(
                    phase: chatViewModel.faceScanInlinePhase,
                    analysisProgress: chatViewModel.inlineFaceScanProgress,
                    analysisPhaseIndex: chatViewModel.inlineFaceScanPhaseIndex,
                    analysisPhaseLabel: chatViewModel.inlineFaceScanPhaseLabel,
                    analysisDisplayedPercentage: chatViewModel.inlineFaceScanDisplayedPercentage,
                    analysisElapsedSeconds: chatViewModel.inlineFaceScanElapsedSeconds,
                    scanResult: chatViewModel.inlineFaceScanResult,
                    resultsUnlocked: chatViewModel.inlineFaceScanResultsUnlocked,
                    isSubmitting: chatViewModel.isSubmittingAnswer,
                    skipLabel: question.detailText,
                    isScanRevealed: isAnswerRevealed("scan"),
                    capturedPayload: chatViewModel.inlineFaceScanCapturedPayload,
                    onLaunchScan: {
                        await chatViewModel.submitFaceScanNow()
                    },
                    onSkip: {
                        await chatViewModel.submitFaceScanLater()
                    },
                    onCapture: { payload, markers in
                        chatViewModel.faceScanCaptureCompleted(payload: payload, markers: markers)
                    },
                    onContinueResults: {
                        chatViewModel.submitFaceScanResultsContinue()
                    }
                )

            case .answersAnalysis, .analysisProgress:
                EmptyView()
            }
        }
        .padding(.top, 10)
        .animation(OnboardingProfileChatAnswerReveal.spring, value: chatViewModel.showsAnswerOptions)
    }

    private var programCreationSection: some View {
        OnboardingProfileChatPlanCreationPanel(
            isVisible: chatViewModel.showsProgramCreationSection,
            isComplete: chatViewModel.programCreationPhase == .complete
        )
        .padding(.top, 10)
    }

    private var analysisSection: some View {
        OnboardingProfileChatAnalysisPanel(
            phaseLabel: chatViewModel.analysisPhaseLabel,
            phaseIndex: chatViewModel.analysisPhaseIndex,
            displayedPercentage: chatViewModel.analysisDisplayedPercentage,
            progress: chatViewModel.analysisProgress,
            elapsedSeconds: chatViewModel.analysisElapsedSeconds,
            isPaused: chatViewModel.analysisIsPaused,
            isVisible: chatViewModel.showsAnalysisSection
        )
        .padding(.top, 10)
    }

    // MARK: - Analysis & CTA

    private var continueAfterAnalysisButton: some View {
        Button {
            guard !isSigningIn else { return }
            HapticManager.shared.impact(.medium)
            Task { await authenticateAndContinue() }
        } label: {
            HStack(spacing: 10) {
                if isSigningIn {
                    ProgressView()
                        .tint(.black)
                } else if AuthUser.current == nil {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 20, weight: .semibold))
                    Text("Continuer avec Apple")
                        .font(.system(size: OnboardingProfileChatDepthStyle.answerFontSize + 1, weight: .bold))
                } else {
                    Text("Continuer")
                        .font(.system(size: OnboardingProfileChatDepthStyle.answerFontSize + 1, weight: .bold))
                }
            }
                .foregroundStyle(OnboardingTheme.onboardingPrimaryActionText(for: colorScheme))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .contentShape(answerButtonShape)
        }
        .onboardingPrimaryActionStyle()
        .disabled(isSigningIn)
        .opacity(isSigningIn ? 0.72 : 1)
    }

    @MainActor
    private func authenticateAndContinue() async {
        guard !isSigningIn else { return }
        isSigningIn = true
        signInError = nil
        chatViewModel.prepareAnswersForAuthentication()
        onboardingViewModel.saveProgress()

        do {
            try await OnboardingAppleAuth.authenticateAndMigrate(
                authManager: authManager,
                profileService: profileService,
                viewModel: onboardingViewModel
            )
            HapticManager.shared.notification(.success)
            isSigningIn = false
            chatViewModel.submitContinueAfterAnalysis()
        } catch {
            HapticManager.shared.notification(.error)
            signInError = error.localizedDescription
            isSigningIn = false
        }
    }

    private func chatChoiceButton(
        title: String,
        emoji: String?,
        centered: Bool = false,
        action: @escaping () async -> Void
    ) -> some View {
        Button {
            guard !chatViewModel.isSubmittingAnswer else { return }
            HapticManager.shared.selection()
            Task { await action() }
        } label: {
            HStack(spacing: 12) {
                if let emoji {
                    Text(emoji)
                        .font(.system(size: 20))
                }
                Text(title)
                    .font(.system(size: OnboardingProfileChatDepthStyle.answerFontSize, weight: .semibold))
                    .foregroundStyle(OnboardingTheme.primaryText)
                    .multilineTextAlignment(centered ? .center : .leading)
                if !centered {
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
            .contentShape(answerButtonShape)
        }
        .processGlassButton(in: answerButtonShape)
        .disabled(chatViewModel.isSubmittingAnswer)
    }

    private func chatMultiChoiceButton(
        title: String,
        emoji: String?,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            guard !chatViewModel.isSubmittingAnswer else { return }
            HapticManager.shared.selection()
            action()
        } label: {
            HStack(spacing: 12) {
                if let emoji {
                    Text(emoji)
                        .font(.system(size: 20))
                }
                Text(title)
                    .font(.system(size: OnboardingProfileChatDepthStyle.answerFontSize, weight: .semibold))
                    .foregroundStyle(OnboardingTheme.primaryText)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(OnboardingTheme.primaryText.opacity(0.85))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(answerButtonShape)
        }
        .processGlassButton(in: answerButtonShape)
        .overlay {
            if isSelected {
                answerButtonShape
                    .strokeBorder(OnboardingTheme.primaryText.opacity(0.22), lineWidth: 1)
            }
        }
        .opacity(isSelected ? 1 : 0.82)
        .disabled(chatViewModel.isSubmittingAnswer)
    }

    private func chatPrimaryButton(
        _ title: String,
        disabled: Bool = false,
        filled: Bool = false,
        action: @escaping () async -> Void
    ) -> some View {
        let isDisabled = disabled || chatViewModel.isSubmittingAnswer

        return Button {
            guard !isDisabled else { return }
            HapticManager.shared.impact(.medium)
            Task { await action() }
        } label: {
            Text(title)
                .font(.system(size: OnboardingProfileChatDepthStyle.answerFontSize + 1, weight: .bold))
                .foregroundStyle(
                    isDisabled
                        ? OnboardingTheme.mutedText
                        : (filled
                            ? OnboardingTheme.onboardingPrimaryActionText(for: colorScheme)
                            : OnboardingTheme.actionButtonText)
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .contentShape(answerButtonShape)
        }
        .modifier(ChatPrimaryButtonStyleModifier(filled: filled, shape: answerButtonShape))
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.55 : 1)
        .padding(.top, 4)
    }
}

private struct ChatPrimaryButtonStyleModifier<S: InsettableShape>: ViewModifier {
    let filled: Bool
    let shape: S

    func body(content: Content) -> some View {
        if filled {
            content.onboardingPrimaryActionStyle()
        } else {
            content.processGlassButton(in: shape)
        }
    }
}
