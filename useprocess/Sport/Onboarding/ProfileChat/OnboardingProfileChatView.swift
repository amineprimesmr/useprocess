//
//  OnboardingProfileChatView.swift
//  useprocess
//

import SwiftUI

struct OnboardingProfileChatView: View {
    @ObservedObject var onboardingViewModel: OnboardingViewModel
    @EnvironmentObject private var healthManager: HealthManager
    @EnvironmentObject private var permissionsManager: PermissionsManager
    var onComplete: () -> Void

    @State private var chatViewModel = OnboardingProfileChatViewModel()
    @State private var multiSelection: Set<String> = []
    @State private var isSportSearchActive = false
    @State private var revealedAnswerIDs: Set<String> = []
    @State private var showFaceScan = false

    private let messageLineSpacing: CGFloat = 7
    private let horizontalPadding: CGFloat = 28
    private let answerButtonShape = Capsule()

    var body: some View {
        GeometryReader { geometry in
            let layout = ChatLayoutMetrics(screenHeight: geometry.size.height)

            ZStack(alignment: .bottom) {
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

                VStack(alignment: .leading, spacing: layout.slotSpacing) {
                    historySlot(height: layout.historySlotHeight)
                    activeSlot(layout: layout)
                    Spacer(minLength: 0)
                }
                .animation(OnboardingProfileChatDepthStyle.historySpring, value: chatViewModel.messages.count)
                .padding(.horizontal, horizontalPadding)
                .padding(.top, layout.contentTopPadding)
                .padding(.bottom, chatViewModel.showsLetsGoButton ? 110 : 36)
                .animation(OnboardingProfileChatAnswerReveal.spring, value: chatViewModel.showsLetsGoButton)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .regularWidthContainer(maxWidth: AdaptiveScreenLayout.onboardingChatMaxWidth)

                if chatViewModel.showsLetsGoButton {
                    VStack(spacing: 10) {
                        Text(HealthMedicalSources.disclaimer)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(OnboardingTheme.mutedText.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)

                        letsGoButton
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, 50)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                if chatViewModel.analysisShowPopup {
                    OnboardingAnalysisYesNoPopup(
                        question: chatViewModel.analysisPopupQuestion,
                        subtitle: chatViewModel.analysisPopupSubtitle,
                        affirmativeTitle: chatViewModel.analysisPopupAffirmativeTitle,
                        negativeTitle: chatViewModel.analysisPopupNegativeTitle,
                        popupOffset: chatViewModel.analysisPopupOffset,
                        onAnswer: { chatViewModel.handleAnalysisPopupAnswer($0) }
                    )
                    .zIndex(30)
                }
            }
            .animation(OnboardingProfileChatAnswerReveal.spring, value: chatViewModel.showsLetsGoButton)
            .animation(OnboardingProfileChatAnswerReveal.spring, value: chatViewModel.showsAnalysisSection)
            .padding(.top, OnboardingConstants.backOnlyContentTopInset)
            .mask(topFadeMask)
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fullScreenCover(isPresented: $showFaceScan) {
            FaceScanCapturePrivacyGateView(
                onBack: {
                    showFaceScan = false
                    chatViewModel.faceScanDidCancel()
                },
                onSkip: {
                    showFaceScan = false
                    chatViewModel.faceScanDidSkip()
                },
                onCapture: { payload, markers in
                    showFaceScan = false
                    chatViewModel.faceScanDidComplete(payload: payload, markers: markers)
                }
            )
        }
        .onChange(of: chatViewModel.shouldPresentFaceScan) { _, should in
            if should { showFaceScan = true }
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

    // MARK: - Layout slots

    private struct ChatLayoutMetrics {
        let screenHeight: CGFloat
        let activeAnchorY: CGFloat
        let historySlotHeight: CGFloat
        let slotSpacing: CGFloat
        let contentTopPadding: CGFloat

        init(screenHeight: CGFloat) {
            self.screenHeight = screenHeight
            activeAnchorY = screenHeight * 0.30
            historySlotHeight = screenHeight * 0.16
            slotSpacing = 12
            contentTopPadding = max(12, activeAnchorY - historySlotHeight - slotSpacing)
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
    private func activeSlot(layout: ChatLayoutMetrics) -> some View {
        let bottomPadding: CGFloat = chatViewModel.showsLetsGoButton ? 110 : 36

        VStack(alignment: .leading, spacing: OnboardingProfileChatDepthStyle.messageSpacing) {
            HStack(alignment: .top, spacing: 0) {
                if chatViewModel.isMessageAnimating {
                    CoachThinkingDotsView()
                        .frame(width: 36)
                }

                if let active = activeMessage {
                    depthMessageRow(active, distanceFromActive: 0)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if chatViewModel.showsAnswerOptions,
               let question = chatViewModel.currentQuestion {
                answerSection(
                    for: question,
                    maxScrollHeight: layout.answersScrollMaxHeight(bottomPadding: bottomPadding)
                )
                    .id("answers_\(question.id)")
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .task(id: answerRevealTaskID(for: question)) {
                        await runAnswerReveal(for: question)
                    }
            }

            if chatViewModel.showsAnalysisSection {
                analysisSection
                    .id("analysis_progress")
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(OnboardingProfileChatAnswerReveal.spring, value: chatViewModel.showsAnalysisSection)
        .animation(OnboardingProfileChatAnswerReveal.spring, value: chatViewModel.showsLetsGoButton)
        .animation(.easeInOut(duration: 0.2), value: chatViewModel.analysisProgress)
        .animation(.easeInOut(duration: 0.2), value: chatViewModel.analysisDisplayedPercentage)
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
            .frame(height: 110)

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
                chatPrimaryButton("Valider", disabled: multiSelection.isEmpty) {
                    let selection = multiSelection
                    multiSelection = []
                    await chatViewModel.submitMultiChoice(selection)
                }
                .onboardingChatAnswerReveal(isRevealed: isAnswerRevealed("validate"))

            case .faceScanOffer:
                VStack(alignment: .leading, spacing: 10) {
                    chatPrimaryButton("Lancer le scan") {
                        await chatViewModel.submitFaceScanNow()
                    }
                    .onboardingChatAnswerReveal(isRevealed: isAnswerRevealed("scan"))

                    if let detail = question.detailText {
                        Button {
                            guard !chatViewModel.isSubmittingAnswer else { return }
                            HapticManager.shared.selection()
                            Task { await chatViewModel.submitFaceScanLater() }
                        } label: {
                            Text(detail)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(OnboardingTheme.mutedText.opacity(0.72))
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 2)
                        }
                        .buttonStyle(.plain)
                        .onboardingChatAnswerReveal(isRevealed: isAnswerRevealed("later_hint"))
                    }
                }

            case .analysisProgress:
                EmptyView()
            }
        }
        .padding(.top, 10)
        .animation(OnboardingProfileChatAnswerReveal.spring, value: chatViewModel.showsAnswerOptions)
    }

    private var analysisSection: some View {
        OnboardingProfileChatAnalysisPanel(
            phaseLabel: chatViewModel.analysisPhaseLabel,
            displayedPercentage: chatViewModel.analysisDisplayedPercentage,
            progress: chatViewModel.analysisProgress,
            isVisible: chatViewModel.showsAnalysisSection
        )
        .padding(.top, 10)
    }

    // MARK: - Analysis & CTA

    private var letsGoButton: some View {
        Button {
            HapticManager.shared.impact(.medium)
            chatViewModel.submitLetsGo()
        } label: {
            Text("C'est parti")
                .font(.system(size: OnboardingProfileChatDepthStyle.answerFontSize + 1, weight: .bold))
                .foregroundStyle(OnboardingTheme.actionButtonText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .contentShape(answerButtonShape)
        }
        .processGlassButton(in: answerButtonShape)
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
            .padding(.vertical, 16)
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
            .padding(.vertical, 16)
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
                .foregroundStyle(isDisabled ? OnboardingTheme.mutedText : OnboardingTheme.actionButtonText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .contentShape(answerButtonShape)
        }
        .processGlassButton(in: answerButtonShape)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.55 : 1)
        .padding(.top, 4)
    }
}
