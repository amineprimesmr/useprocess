//
//  OnboardingProfileChatView.swift
//  useprocess
//
//  Discussion onboarding — moteur et UI Moss (typewriter, profondeur, haptiques).
//  Source: https://github.com/imranhsni/mossonboardingchat
//

import SwiftUI

struct OnboardingProfileChatView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverOn

    @ObservedObject var onboardingViewModel: OnboardingViewModel
    @EnvironmentObject private var healthManager: HealthManager
    @EnvironmentObject private var permissionsManager: PermissionsManager
    @EnvironmentObject private var profileService: UnifiedProfileService
    var onComplete: () -> Void

    @State private var mossEngine = MossConversationEngine()
    @State private var chatViewModel = OnboardingProfileChatViewModel()

    var body: some View {
        ZStack {
            OnboardingTheme.screenBackground
                .ignoresSafeArea()

            if !chatViewModel.isGlowUpResultsPresented {
                MossBreathingArc(
                    palette: .processBlue,
                    intensity: colorScheme == .dark ? 1.05 : 0.62
                )
            }

            mossConversationSurface
                .opacity(chatViewModel.isGlowUpResultsPresented ? 0 : 1)
                .offset(x: chatViewModel.isGlowUpResultsPresented ? -64 : 0)
                .allowsHitTesting(!chatViewModel.isGlowUpResultsPresented)
                .accessibilityHidden(chatViewModel.isGlowUpResultsPresented)
                .clipped()

            if chatViewModel.isGlowUpResultsPresented {
                OnboardingGlowUpResultsStepView {
                    Task { await chatViewModel.completeGlowUpResults() }
                }
                .zIndex(10)
                .transition(.glowUpResultsCover)
            }
        }
        .onChange(of: chatViewModel.shouldFinish) { _, should in
            guard should else { return }
            chatViewModel.finish(onComplete: onComplete)
        }
        .task(id: onboardingViewModel.currentStep) {
            mossEngine.reduceMotion = reduceMotion
            mossEngine.assistiveVoice = voiceOverOn

            chatViewModel.bind(
                onboardingViewModel,
                engine: mossEngine,
                healthManager: healthManager,
                permissionsManager: permissionsManager
            )
            onboardingViewModel.profileChatBackHandler = { [chatViewModel] in
                chatViewModel.goBackInDiscussion()
            }
            onboardingViewModel.onOnboardingFaceScanCancel = { [chatViewModel] in
                chatViewModel.isSubmittingAnswer = false
                if chatViewModel.currentQuestion?.kind == .profileSummary
                    || chatViewModel.currentQuestion?.id == "face_scan_offer" {
                    chatViewModel.restoreFaceScanOfferAnswers()
                }
            }
            onboardingViewModel.onOnboardingFaceScanSkip = { [chatViewModel] in
                chatViewModel.faceScanDidSkip()
            }
            onboardingViewModel.onOnboardingFaceScanResult = { [chatViewModel] result in
                chatViewModel.adoptDedicatedFaceScanResult(result)
            }
            onboardingViewModel.onOnboardingFaceScanContinue = {
                Task { await completeFaceScanOnboarding() }
            }
            onboardingViewModel.syncInferredWeightGoal()
            await chatViewModel.startIfNeeded()

            if onboardingViewModel.presentedOnboardingFaceScan == nil {
                if onboardingViewModel.shouldReopenFaceScanResultsAfterBack,
                   let restored = chatViewModel.restoredFaceScanResultIfAvailable() {
                    onboardingViewModel.shouldReopenFaceScanResultsAfterBack = false
                    chatViewModel.prepareForFaceScanResultsReopen()
                    onboardingViewModel.presentOnboardingFaceScan(initialResult: restored)
                } else if let restored = chatViewModel.consumePendingDedicatedResultsReopen() {
                    onboardingViewModel.presentOnboardingFaceScan(initialResult: restored)
                } else if chatViewModel.shouldAutoFinishAfterResume,
                          !onboardingViewModel.suppressProfileChatAutoFinish {
                    chatViewModel.finish(onComplete: onComplete)
                }
            }

            if onboardingViewModel.suppressProfileChatAutoFinish {
                onboardingViewModel.suppressProfileChatAutoFinish = false
            }
        }
        .onChange(of: reduceMotion) { _, value in
            mossEngine.reduceMotion = value
        }
        .onChange(of: voiceOverOn) { _, value in
            mossEngine.assistiveVoice = value
        }
        .onDisappear {
            onboardingViewModel.profileChatHeaderProgress = nil
            if onboardingViewModel.profileChatBackHandler != nil {
                onboardingViewModel.profileChatBackHandler = nil
            }
        }
        .onChange(of: chatHeaderProgressRefreshKey) { _, _ in
            refreshChatHeaderProgress()
        }
        .onChange(of: chatViewModel.isGlowUpResultsPresented) { _, _ in
            refreshChatHeaderProgress()
        }
        .onAppear {
            refreshChatHeaderProgress()
        }
    }

    private var chatHeaderProgressRefreshKey: String {
        let questionID = chatViewModel.currentQuestion?.id ?? ""
        let typingState = mossEngine.messages
            .map { "\($0.id):\($0.revealed)" }
            .joined(separator: "|")
        return "\(questionID)|\(typingState)|\(mossEngine.isTyping)|\(mossEngine.controlsVisible)|\(chatViewModel.isGlowUpResultsPresented)"
    }

    private func refreshChatHeaderProgress() {
        onboardingViewModel.profileChatHeaderProgress = OnboardingProfileChatCoachHeaderProgress.snapshot(
            questionID: chatViewModel.currentQuestion?.id,
            engine: mossEngine,
            isGlowUpResultsPresented: chatViewModel.isGlowUpResultsPresented
        )
    }

    // MARK: - Moss conversation surface

    private var mossConversationSurface: some View {
        mossChatScrollSurface(conversationTopInset: OnboardingConstants.mossChatContentTopInset)
    }

    private func mossChatScrollSurface(conversationTopInset: CGFloat) -> some View {
        ZStack(alignment: .top) {
            GeometryReader { geometry in
                ScrollViewReader { proxy in
                    ScrollView {
                        mossConversationStack
                            .padding(.top, 12)
                            .padding(.bottom, Theme.Space.xl)
                            .frame(
                                maxWidth: .infinity,
                                minHeight: geometry.size.height,
                                alignment: .top
                            )
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .onChange(of: mossEngine.messages.count) { _, _ in
                        scrollToLatestMessage(proxy: proxy)
                    }
                    .onChange(of: mossEngine.controlsVisible) { _, visible in
                        guard visible else { return }
                        scrollToInlineAnswer(proxy: proxy)
                    }
                }
            }
            .padding(.top, conversationTopInset)
            .regularWidthContainer(maxWidth: AdaptiveScreenLayout.onboardingChatMaxWidth)
        }
    }

    private var mossConversationStack: some View {
        let engine = mossEngine
        let messages = engine.messages
        let lastIndex = messages.count - 1
        let messageWindow = MossChatStyle.windowSize

        return VStack(alignment: .leading, spacing: Theme.Space.l) {
            ForEach(Array(messages.enumerated()).suffix(messageWindow), id: \.element.id) { item in
                let depth = lastIndex - item.offset
                MossConversationBubble(message: item.element)
                    .padding(.top, firstMessageTopInset(for: item.element))
                    .blur(radius: MossChatStyle.blur(forDepth: depth))
                    .opacity(MossChatStyle.opacity(forDepth: depth))
                    .scaleEffect(MossChatStyle.scale(forDepth: depth), anchor: .top)
                    .transition(.opacity)
                    .id(item.element.id)
                    .onTapGesture {
                        guard mossEngine.isTyping else { return }
                        mossEngine.completeCurrent()
                    }
            }

            VStack(alignment: .leading, spacing: Theme.Space.l) {
                if chatViewModel.showsAnswerOptions,
                   let question = chatViewModel.currentQuestion {
                    mossAnswerControls(for: question)
                        .opacity(engine.controlsVisible && !engine.isTyping ? 1 : 0)
                        .allowsHitTesting(profileSummaryHitsEnabled(question, engine: engine))
                        .id("controls.\(question.id)")
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(y: 10)),
                            removal: .opacity
                        ))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .id("inlineAnswer")
        }
        .padding(.horizontal, Theme.margin)
        .animation(reduceMotion ? nil : .smooth(duration: 0.18), value: messages.count)
        .animation(reduceMotion ? nil : .smooth(duration: 0.18), value: engine.controlsVisible)
    }

    /// Espace sous la barre de progression — uniquement la toute première bulle Moss.
    private func firstMessageTopInset(for message: MossConversationEngine.Message) -> CGFloat {
        guard message.sender == .moss,
              message.id == mossEngine.messages.first?.id else {
            return 0
        }
        return 16
    }

    /// Les contrôles ne reçoivent le tap qu’après la fin du typewriter.
    private func profileSummaryHitsEnabled(
        _ question: OnboardingProfileChatQuestion,
        engine: MossConversationEngine
    ) -> Bool {
        guard engine.controlsVisible, !engine.isTyping else { return false }
        return true
    }

    private func scrollToLatestMessage(proxy: ScrollViewProxy) {
        guard let last = mossEngine.messages.last else { return }
        if reduceMotion {
            proxy.scrollTo(last.id, anchor: .top)
        } else {
            withAnimation(.smooth(duration: 0.32)) {
                proxy.scrollTo(last.id, anchor: .top)
            }
        }
    }

    private func scrollToInlineAnswer(proxy: ScrollViewProxy) {
        let isProfileSummary = chatViewModel.currentQuestion?.kind == .profileSummary
        let anchor: UnitPoint = isProfileSummary ? .bottom : .center
        if reduceMotion {
            proxy.scrollTo("inlineAnswer", anchor: anchor)
        } else {
            withAnimation(.smooth(duration: 0.28)) {
                proxy.scrollTo("inlineAnswer", anchor: anchor)
            }
        }
    }

    // MARK: - Réponses (chips Moss)

    @ViewBuilder
    private func mossAnswerControls(for question: OnboardingProfileChatQuestion) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            switch question.kind {
            case .infoContinue:
                MossChatPrimaryButton(
                    title: question.continueLabel ?? OnboardingCopy.continueCTA,
                    enabled: !chatViewModel.isSubmittingAnswer
                ) {
                    Task { await chatViewModel.submitInfoContinue() }
                }
                .settleIn(0)

            case .singleChoice:
                OnboardingChatScrollableAnswerStack(
                    choiceCount: question.choices.count,
                    maxHeight: 220
                ) {
                    ForEach(Array(question.choices.enumerated()), id: \.element.id) { index, choice in
                        MossChip(title: choice.label, isSelected: false) {
                            Task { await chatViewModel.submitSingleChoice(choice.id) }
                        }
                        .settleIn(index)
                    }
                }

            case .profileSummary:
                OnboardingProfileChatProfileSummarySection(
                    sections: OnboardingProfileSummaryBuilder.sections(for: onboardingViewModel),
                    isRevealed: mossEngine.controlsVisible && !mossEngine.isTyping,
                    onContinue: {
                        Task { await chatViewModel.submitProfileSummaryContinue() }
                    }
                )
                .padding(.top, 48)
            }
        }
        .padding(.top, Theme.Space.s)
    }

    @MainActor
    private func completeFaceScanOnboarding() async {
        chatViewModel.finishAfterDedicatedFaceAnalysis()
        onboardingViewModel.dismissOnboardingFaceScan()
        chatViewModel.finish(onComplete: onComplete)
    }
}
