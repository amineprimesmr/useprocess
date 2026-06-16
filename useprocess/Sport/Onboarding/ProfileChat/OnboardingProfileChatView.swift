//
//  OnboardingProfileChatView.swift
//  useprocess
//

import SwiftUI

struct OnboardingProfileChatView: View {
    @ObservedObject var onboardingViewModel: OnboardingViewModel
    var onComplete: () -> Void

    @State private var chatViewModel = OnboardingProfileChatViewModel()
    @State private var multiSelection: Set<String> = []
    @State private var isSportSearchActive = false
    @State private var revealedAnswerIDs: Set<String> = []

    private let messageLineSpacing: CGFloat = 7
    private let horizontalPadding: CGFloat = 28
    private let answerButtonShape = Capsule()

    var body: some View {
        GeometryReader { geometry in
            let layout = ChatLayoutMetrics(screenHeight: geometry.size.height)

            ZStack(alignment: .topLeading) {
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
                    activeSlot
                    Spacer(minLength: 0)
                }
                .animation(OnboardingProfileChatDepthStyle.historySpring, value: chatViewModel.messages.count)
                .padding(.horizontal, horizontalPadding)
                .padding(.top, layout.contentTopPadding)
                .padding(.bottom, 36)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
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
        .task(id: onboardingViewModel.currentStep) {
            chatViewModel.bind(onboardingViewModel)
            onboardingViewModel.syncInferredWeightGoal()
            await chatViewModel.startIfNeeded()
        }
    }

    // MARK: - Layout slots

    private struct ChatLayoutMetrics {
        let activeAnchorY: CGFloat
        let historySlotHeight: CGFloat
        let slotSpacing: CGFloat
        let contentTopPadding: CGFloat

        init(screenHeight: CGFloat) {
            activeAnchorY = screenHeight * 0.30
            historySlotHeight = screenHeight * 0.16
            slotSpacing = 12
            contentTopPadding = max(12, activeAnchorY - historySlotHeight - slotSpacing)
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
    private var activeSlot: some View {
        VStack(alignment: .leading, spacing: OnboardingProfileChatDepthStyle.messageSpacing) {
            if let active = activeMessage {
                depthMessageRow(active, distanceFromActive: 0)
            }

            if chatViewModel.showsAnswerOptions,
               let question = chatViewModel.currentQuestion {
                answerSection(for: question)
                    .id("answers_\(question.id)")
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .task(id: answerRevealTaskID(for: question)) {
                        await runAnswerReveal(for: question)
                    }
            }
        }
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
            withAnimation(OnboardingProfileChatAnswerReveal.spring) {
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
    private func answerSection(for question: OnboardingProfileChatQuestion) -> some View {
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
                ForEach(question.choices) { choice in
                    chatChoiceButton(title: choice.label, emoji: choice.emoji) {
                        await chatViewModel.submitSingleChoice(choice.id)
                    }
                    .onboardingChatAnswerReveal(isRevealed: isAnswerRevealed(choice.id))
                }

            case .multiChoice:
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
                chatPrimaryButton("Valider", disabled: multiSelection.isEmpty) {
                    let selection = multiSelection
                    multiSelection = []
                    await chatViewModel.submitMultiChoice(selection)
                }
                .onboardingChatAnswerReveal(isRevealed: isAnswerRevealed("validate"))
            }
        }
        .padding(.top, 10)
        .animation(OnboardingProfileChatAnswerReveal.spring, value: chatViewModel.showsAnswerOptions)
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
        .buttonStyle(.plain)
        .processGlassEffect(in: answerButtonShape)
        .buttonStyle(ProcessGlassPressStyle())
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
        .buttonStyle(.plain)
        .processGlassEffect(in: answerButtonShape)
        .overlay {
            if isSelected {
                answerButtonShape
                    .strokeBorder(OnboardingTheme.primaryText.opacity(0.22), lineWidth: 1)
            }
        }
        .buttonStyle(ProcessGlassPressStyle())
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
        .buttonStyle(.plain)
        .processGlassEffect(in: answerButtonShape)
        .buttonStyle(ProcessGlassPressStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.55 : 1)
        .padding(.top, 4)
    }
}
