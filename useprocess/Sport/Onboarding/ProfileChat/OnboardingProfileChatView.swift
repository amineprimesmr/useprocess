//
//  OnboardingProfileChatView.swift
//  useprocess
//
//  Discussion onboarding — moteur et UI Moss (typewriter, profondeur, haptiques).
//  Source: https://github.com/imranhsni/mossonboardingchat
//

import SwiftUI
import AVFoundation

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
    @State private var multiSelection: Set<String> = []
    @State private var isSportSearchActive = false

    var body: some View {
        ZStack {
            OnboardingTheme.screenBackground
                .ignoresSafeArea()

            if !chatViewModel.isGlowUpResultsPresented {
                MossBreathingArc(intensity: colorScheme == .dark ? 0.55 : 0.28)
            }

            if chatViewModel.isGlowUpResultsPresented {
                OnboardingGlowUpResultsStepView {
                    Task { await chatViewModel.completeGlowUpResults() }
                }
                .transition(.opacity)
            } else {
                mossConversationSurface
            }
        }
        .onChange(of: chatViewModel.shouldFinish) { _, should in
            guard should else { return }
            chatViewModel.finish(onComplete: onComplete)
        }
        .onChange(of: chatViewModel.currentQuestion?.id) { _, _ in
            multiSelection = []
            isSportSearchActive = false
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
        .onAppear {
            refreshChatHeaderProgress()
        }
    }

    private var chatHeaderProgressRefreshKey: String {
        let questionID = chatViewModel.currentQuestion?.id ?? ""
        let typingState = mossEngine.messages
            .map { "\($0.id):\($0.revealed)" }
            .joined(separator: "|")
        return "\(questionID)|\(typingState)|\(mossEngine.isTyping)|\(mossEngine.controlsVisible)"
    }

    private func refreshChatHeaderProgress() {
        onboardingViewModel.profileChatHeaderProgress = OnboardingProfileChatCoachHeaderProgress.snapshot(
            questionID: chatViewModel.currentQuestion?.id,
            engine: mossEngine
        )
    }

    // MARK: - Moss conversation surface

    private var mossConversationSurface: some View {
        let conversationTopInset = OnboardingConstants.mossChatContentTopInset

        return ZStack(alignment: .top) {
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

            if mossEngine.isTyping {
                VStack(spacing: 0) {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            mossEngine.completeCurrent()
                        }
                    Spacer(minLength: 0)
                        .frame(maxHeight: 260)
                        .allowsHitTesting(false)
                }
                .ignoresSafeArea()
                .accessibilityLabel(OnboardingCopy.t("Appuie pour afficher la suite", en: "Tap to show the rest"))
                .accessibilityAddTraits(.isButton)
            }
        }
    }

    private var mossConversationStack: some View {
        let engine = mossEngine
        let messages = engine.messages
        let lastIndex = messages.count - 1

        return VStack(alignment: .leading, spacing: Theme.Space.xl) {
            ForEach(Array(messages.enumerated()).suffix(MossChatStyle.windowSize), id: \.element.id) { item in
                let depth = lastIndex - item.offset
                MossConversationBubble(message: item.element)
                    .padding(.top, firstMessageTopInset(for: item.element))
                    .blur(radius: MossChatStyle.blur(forDepth: depth))
                    .opacity(MossChatStyle.opacity(forDepth: depth))
                    .scaleEffect(MossChatStyle.scale(forDepth: depth), anchor: .top)
                    .transition(.opacity)
                    .id(item.element.id)
            }

            VStack(alignment: .leading, spacing: Theme.Space.l) {
                if chatViewModel.showsProgramCreationSection {
                    programCreationSection
                }

                if chatViewModel.showsAnalysisSection {
                    analysisSection
                }

                if chatViewModel.showsAnswerOptions,
                   let question = chatViewModel.currentQuestion {
                    mossAnswerControls(for: question)
                        .opacity(engine.controlsVisible ? 1 : 0)
                        .allowsHitTesting(engine.controlsVisible && !engine.isTyping)
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
        .animation(reduceMotion ? nil : .smooth(duration: 0.32), value: messages.count)
        .animation(reduceMotion ? nil : .smooth(duration: 0.28), value: engine.controlsVisible)
    }

    /// Espace sous la barre de progression — uniquement la toute première bulle Moss.
    private func firstMessageTopInset(for message: MossConversationEngine.Message) -> CGFloat {
        guard message.sender == .moss,
              message.id == mossEngine.messages.first?.id else {
            return 0
        }
        return 16
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
        if reduceMotion {
            proxy.scrollTo("inlineAnswer", anchor: .center)
        } else {
            withAnimation(.smooth(duration: 0.28)) {
                proxy.scrollTo("inlineAnswer", anchor: .center)
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

            case .yesNo:
                HStack(spacing: Theme.Space.s) {
                    MossChip(title: OnboardingCopy.t("Oui", en: "Yes"), isSelected: false) {
                        Task { await chatViewModel.submitYesNo(true) }
                    }
                    .settleIn(0)
                    MossChip(title: OnboardingCopy.t("Non", en: "No"), isSelected: false) {
                        Task { await chatViewModel.submitYesNo(false) }
                    }
                    .settleIn(1)
                }

            case .singleChoice where question.id == "sport_pick":
                OnboardingProfileChatSportPicker(
                    isSearching: $isSportSearchActive,
                    isSubmitting: chatViewModel.isSubmittingAnswer,
                    revealedOptionIDs: Set(question.choices.map(\.id)),
                    onSelectFeatured: { choiceId in
                        Task { await chatViewModel.submitSingleChoice(choiceId) }
                    },
                    onSelectSearched: { sport in
                        Task { await chatViewModel.submitSearchedSport(sport) }
                    }
                )

            case .singleChoice:
                MossFlowLayout(spacing: 8) {
                    ForEach(Array(question.choices.enumerated()), id: \.element.id) { index, choice in
                        MossChip(title: choice.label, isSelected: false) {
                            Task { await chatViewModel.submitSingleChoice(choice.id) }
                        }
                        .settleIn(index)
                    }
                }

            case .multiChoice:
                MossFlowLayout(spacing: 8) {
                    ForEach(Array(question.choices.enumerated()), id: \.element.id) { index, choice in
                        MossChip(
                            title: choice.label,
                            isSelected: multiSelection.contains(choice.id)
                        ) {
                            if multiSelection.contains(choice.id) {
                                multiSelection.remove(choice.id)
                            } else {
                                multiSelection.insert(choice.id)
                            }
                        }
                        .settleIn(index)
                    }
                }

                MossChatPrimaryButton(
                    title: OnboardingCopy.t("Valider", en: "Confirm"),
                    enabled: !multiSelection.isEmpty && !chatViewModel.isSubmittingAnswer
                ) {
                    let selection = multiSelection
                    multiSelection = []
                    Task { await chatViewModel.submitMultiChoice(selection) }
                }
                .settleIn(question.choices.count)

            case .faceScanOffer:
                OnboardingProfileChatInlineFaceScanSection(
                    isSubmitting: chatViewModel.isSubmittingAnswer,
                    isScanRevealed: mossEngine.controlsVisible,
                    onLaunchScan: {
                        Task { await launchOnboardingFaceScan() }
                    }
                )
                .settleIn(0)

            case .profileSummary:
                OnboardingProfileChatProfileSummarySection(
                    sections: OnboardingProfileSummaryBuilder.sections(for: onboardingViewModel),
                    isSubmitting: chatViewModel.isSubmittingAnswer,
                    isRevealed: mossEngine.controlsVisible,
                    onContinue: {
                        Task { await chatViewModel.submitProfileSummaryContinue() }
                    }
                )
                .settleIn(0)

            case .autoPlanCreation, .answersAnalysis, .analysisProgress:
                EmptyView()
            }
        }
        .padding(.top, Theme.Space.s)
    }

    private var programCreationSection: some View {
        OnboardingProfileChatPlanCreationPanel(
            isVisible: chatViewModel.showsProgramCreationSection,
            isComplete: chatViewModel.programCreationPhase == .complete
        )
        .padding(.top, Theme.Space.s)
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
        .padding(.top, Theme.Space.s)
    }

    @MainActor
    private func launchOnboardingFaceScan() async {
        guard onboardingViewModel.presentedOnboardingFaceScan == nil else { return }
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        if granted {
            ProcessAnalytics.trackCameraAuthorized(source: "onboarding_face_scan")
        } else {
            ProcessAnalytics.trackCameraDenied(source: "onboarding_face_scan")
        }
        onboardingViewModel.presentOnboardingFaceScan()
        await Task.yield()
        await chatViewModel.submitFaceScanNow()
    }

    @MainActor
    private func completeFaceScanOnboarding() async {
        chatViewModel.finishAfterDedicatedFaceAnalysis()
        onboardingViewModel.dismissOnboardingFaceScan()
        chatViewModel.finish(onComplete: onComplete)
    }
}
