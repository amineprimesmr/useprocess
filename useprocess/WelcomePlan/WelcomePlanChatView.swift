import SwiftUI
import UIKit

struct WelcomePlanChatView: View {
    var embeddedInMainApp: Bool = false
    var selectedSection: Binding<ProcessMainSection>?
    var onComplete: () -> Void

    @EnvironmentObject private var profileService: UnifiedProfileService

    @State private var viewModel = WelcomePlanChatViewModel()
    @State private var multiSelection: Set<String> = []
    @State private var textDraft = ""
    @State private var timeDraft = Calendar.current.date(from: DateComponents(hour: 0, minute: 0)) ?? .now
    @State private var showFaceScan = false
    @State private var revealedAnswerIDs: Set<String> = []

    private let messageLineSpacing: CGFloat = 7
    private let horizontalPadding: CGFloat = 28
    private let answerButtonShape = Capsule()
    private let configurationProgressHeaderHeight: CGFloat = 18

    var body: some View {
        GeometryReader { geometry in
            let layout = ChatLayoutMetrics(
                screenHeight: geometry.size.height,
                topInset: topChromeInset,
                embedded: embeddedInMainApp
            )
            let bottomContentPadding: CGFloat = {
                if viewModel.showsEnterButton { return 120 }
                if showsMultiChoiceValidate { return 72 }
                if viewModel.showsGenerationProgress { return 28 }
                return 28
            }()

            ZStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: layout.slotSpacing) {
                    historySlot(height: layout.historySlotHeight)
                    activeSlot(layout: layout, bottomPadding: bottomContentPadding)
                    Spacer(minLength: 0)
                }
                .animation(OnboardingProfileChatDepthStyle.historySpring, value: viewModel.messages.count)
                .padding(.horizontal, horizontalPadding)
                .padding(.top, layout.contentTopPadding + topChromeInset + configurationProgressInset)
                .padding(.bottom, bottomContentPadding)
                .animation(OnboardingProfileChatAnswerReveal.spring, value: viewModel.showsEnterButton)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .regularWidthContainer(maxWidth: AdaptiveScreenLayout.onboardingChatMaxWidth)

                if showsConfigurationProgress {
                    configurationProgressHeader
                        .padding(.horizontal, horizontalPadding)
                        .padding(.top, max(0, topChromeInset - 6))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .transition(.opacity)
                }

                if showsMultiChoiceValidate {
                    multiChoiceValidateButton
                        .padding(.horizontal, horizontalPadding)
                        .padding(.bottom, embeddedInMainApp ? 12 : 28)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                if viewModel.showsEnterButton {
                    enterAppButton
                        .padding(.horizontal, horizontalPadding)
                        .padding(.bottom, embeddedInMainApp ? 28 : 50)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .animation(OnboardingProfileChatAnswerReveal.spring, value: viewModel.showsEnterButton)
            .animation(OnboardingProfileChatAnswerReveal.spring, value: viewModel.showsAnswerOptions)
            .animation(OnboardingProfileChatAnswerReveal.spring, value: viewModel.showsGenerationProgress)
            .mask(topFadeMask)
            .clipped()
            .onChange(of: viewModel.currentQuestion?.id) { _, _ in
                applyAnswerDraftIfNeeded()
            }
            .onChange(of: viewModel.answerDraftRevision) { _, _ in
                applyAnswerDraftIfNeeded()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OnboardingTheme.screenBackground.ignoresSafeArea())
        .task {
            viewModel.bind(profile: profileService.currentProfile)
            await viewModel.startIfNeeded()
        }
        .fullScreenCover(isPresented: $showFaceScan) {
            FaceScanPrivacyGateView(
                onDismiss: { showFaceScan = false },
                onComplete: { _ in showFaceScan = false }
            )
        }
    }

    private var topChromeInset: CGFloat {
        embeddedInMainApp ? ProcessMainChromeMetrics.scrollTopInset : 0
    }

    // MARK: - Layout slots

    private var showsConfigurationProgress: Bool {
        !viewModel.showsEnterButton && !viewModel.isGenerating
    }

    private var configurationProgressInset: CGFloat {
        showsConfigurationProgress ? configurationProgressHeaderHeight : 0
    }

    private var configurationProgressHeader: some View {
        OnboardingProgressBar(
            progress: viewModel.configurationProgress,
            height: 8,
            cornerRadius: 5
        )
        .animation(.easeInOut(duration: 0.25), value: viewModel.configurationProgress)
    }

    private var showsMultiChoiceValidate: Bool {
        viewModel.showsAnswerOptions && viewModel.currentQuestion?.kind == .multiChoice
    }

    private struct ChatLayoutMetrics {
        let screenHeight: CGFloat
        let activeAnchorY: CGFloat
        let historySlotHeight: CGFloat
        let slotSpacing: CGFloat
        let contentTopPadding: CGFloat
        let topInset: CGFloat
        let embedded: Bool

        init(screenHeight: CGFloat, topInset: CGFloat = 0, embedded: Bool = false) {
            self.screenHeight = screenHeight
            self.topInset = topInset
            self.embedded = embedded

            if embedded {
                activeAnchorY = screenHeight * 0.13
                historySlotHeight = screenHeight * 0.09
            } else {
                activeAnchorY = screenHeight * 0.30
                historySlotHeight = screenHeight * 0.16
            }
            slotSpacing = 10
            contentTopPadding = max(4, activeAnchorY - historySlotHeight - slotSpacing)
        }

        func answersScrollMaxHeight(bottomPadding: CGFloat) -> CGFloat {
            OnboardingProfileChatDepthStyle.answersScrollMaxHeight(
                screenHeight: screenHeight,
                contentTopPadding: contentTopPadding + topInset,
                historySlotHeight: historySlotHeight,
                slotSpacing: slotSpacing,
                bottomPadding: bottomPadding,
                activeMessageHeight: embedded ? 68 : 96
            )
        }
    }

    @ViewBuilder
    private func historySlot(height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: OnboardingProfileChatDepthStyle.messageSpacing) {
            ForEach(historyMessages, id: \.message.id) { item in
                let distance = (viewModel.messages.count - 1) - item.index
                depthMessageRow(
                    item.message,
                    distanceFromActive: distance,
                    onEdit: historyEditAction(for: item.message, at: item.index, distanceFromActive: distance)
                )
            }
        }
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .bottomLeading)
        .clipped()
        .mask(historyFadeMask)
    }

    @ViewBuilder
    private func activeSlot(layout: ChatLayoutMetrics, bottomPadding: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: OnboardingProfileChatDepthStyle.messageSpacing) {
            HStack(alignment: .top, spacing: 0) {
                if viewModel.isMessageAnimating {
                    CoachThinkingDotsView()
                        .frame(width: 36)
                }

                if let active = activeMessage {
                    depthMessageRow(active, distanceFromActive: 0)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if viewModel.showsAnswerOptions, let question = viewModel.currentQuestion {
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

            if viewModel.showsGenerationProgress {
                planGenerationSection
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .animation(nil, value: viewModel.messages.last?.text)
    }

    private var planGenerationSection: some View {
        OnboardingProfileChatAnalysisPanel(
            phaseLabel: viewModel.generationPhaseLabel,
            displayedPercentage: viewModel.generationDisplayedPercentage,
            progress: viewModel.generationProgress,
            isVisible: viewModel.showsGenerationProgress
        )
        .padding(.top, 10)
    }

    private var activeMessage: OnboardingProfileChatMessage? {
        viewModel.messages.last
    }

    private var historyMessages: [(index: Int, message: OnboardingProfileChatMessage)] {
        guard viewModel.messages.count > 1 else { return [] }
        let history = Array(viewModel.messages.enumerated().dropLast())
        let maxHistory = OnboardingProfileChatDepthStyle.maxVisibleMessages - 1
        let start = max(0, history.count - maxHistory)
        return history.dropFirst(start).map { ($0.offset, $0.element) }
    }

    private var historyFadeMask: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                .frame(height: 32)
            Rectangle().fill(.black)
        }
    }

    private var topFadeMask: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                .frame(height: 110)
            Rectangle().fill(.black)
        }
    }

    private func answerRevealTaskID(for question: WelcomePlanQuestion) -> String {
        "\(question.id)-\(viewModel.showsAnswerOptions)"
    }

    @MainActor
    private func runAnswerReveal(for question: WelcomePlanQuestion) async {
        revealedAnswerIDs = []
        let ids = WelcomePlanChatAnswerReveal.orderedIDs(for: question)
        guard !ids.isEmpty else { return }

        try? await Task.sleep(nanoseconds: WelcomePlanChatAnswerReveal.initialDelay)
        guard viewModel.showsAnswerOptions else { return }

        for (index, id) in ids.enumerated() {
            if Task.isCancelled { return }
            guard viewModel.showsAnswerOptions else { return }
            if index > 0 {
                try? await Task.sleep(nanoseconds: WelcomePlanChatAnswerReveal.staggerDelay)
            }
            if Task.isCancelled { return }
            guard viewModel.showsAnswerOptions else { return }
            _ = withAnimation(OnboardingProfileChatAnswerReveal.spring) {
                revealedAnswerIDs.insert(id)
            }
        }
    }

    private func isAnswerRevealed(_ id: String) -> Bool {
        revealedAnswerIDs.contains(id)
    }

    // MARK: - Messages

    @ViewBuilder
    private func depthMessageRow(
        _ message: OnboardingProfileChatMessage,
        distanceFromActive: Int,
        onEdit: (() -> Void)? = nil
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
                    Color.clear.frame(height: 1)
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
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onEdit?()
                    }
                }
            }
            .animation(OnboardingProfileChatDepthStyle.historySpring, value: distanceFromActive)
            .animation(nil, value: message.text)
        }
    }

    private func historyEditAction(
        for message: OnboardingProfileChatMessage,
        at index: Int,
        distanceFromActive: Int
    ) -> (() -> Void)? {
        guard distanceFromActive > 0,
              message.role == .user,
              viewModel.canEditHistory,
              let questionId = viewModel.questionIdForHistoryMessage(at: index) else { return nil }

        return {
            Task { await viewModel.reopenQuestion(questionId: questionId) }
        }
    }

    private func applyAnswerDraftIfNeeded() {
        multiSelection = []
        textDraft = ""
        revealedAnswerIDs = []

        guard let question = viewModel.currentQuestion else { return }

        if let draft = viewModel.consumeAnswerDraft() {
            switch question.kind {
            case .multiChoice:
                multiSelection = Set(draft.choiceIds)
            case .text:
                textDraft = draft.textValue ?? ""
            case .time:
                if let timeValue = draft.timeValue {
                    timeDraft = dateFromTimeValue(timeValue) ?? defaultTime(for: question)
                } else {
                    timeDraft = defaultTime(for: question)
                }
            case .singleChoice, .yesNo, .info:
                break
            }
            revealedAnswerIDs = Set(WelcomePlanChatAnswerReveal.orderedIDs(for: question))
        } else if question.kind == .time {
            timeDraft = defaultTime(for: question)
        }
    }

    private func defaultTime(for question: WelcomePlanQuestion) -> Date {
        switch question.id {
        case "bedtime":
            return dateFromTimeValue("00:00") ?? .now
        case "wake_time":
            return dateFromTimeValue("08:30") ?? .now
        default:
            return dateFromTimeValue("22:30") ?? .now
        }
    }

    private func dateFromTimeValue(_ timeValue: String) -> Date? {
        let parts = timeValue.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else { return nil }
        let snappedMinute = (minute / 5) * 5
        return Calendar.current.date(from: DateComponents(hour: hour, minute: snappedMinute))
    }

    // MARK: - Answers

    @ViewBuilder
    private func answerSection(for question: WelcomePlanQuestion, maxScrollHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            switch question.kind {
            case .info:
                chatPrimaryButton("Continuer") {
                    await viewModel.submitInfoContinue()
                }
                .onboardingChatAnswerReveal(isRevealed: isAnswerRevealed("continue"))

            case .yesNo:
                HStack(spacing: 12) {
                    chatChoiceButton(title: "Oui", centered: true) {
                        await viewModel.submitYesNo(true)
                    }
                    .onboardingChatAnswerReveal(isRevealed: isAnswerRevealed("yes"))

                    chatChoiceButton(title: "Non", centered: true) {
                        await viewModel.submitYesNo(false)
                    }
                    .onboardingChatAnswerReveal(isRevealed: isAnswerRevealed("no"))
                }

            case .singleChoice where question.choices.count == 1:
                if let only = question.choices.first {
                    chatPrimaryButton(only.label) {
                        await viewModel.submitSingleChoice(only.id)
                    }
                    .onboardingChatAnswerReveal(isRevealed: isAnswerRevealed(only.id))
                }

            case .singleChoice:
                OnboardingChatScrollableAnswerStack(
                    choiceCount: question.choices.count,
                    maxHeight: maxScrollHeight
                ) {
                    ForEach(question.choices) { choice in
                        chatChoiceButton(title: choice.label) {
                            await viewModel.submitSingleChoice(choice.id)
                        }
                        .onboardingChatAnswerReveal(isRevealed: isAnswerRevealed(choice.id))
                    }
                }

            case .multiChoice:
                OnboardingChatScrollableAnswerStack(
                    choiceCount: question.choices.count,
                    maxHeight: maxScrollHeight
                ) {
                    ForEach(question.choices) { choice in
                        chatMultiChoiceButton(
                            title: choice.label,
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

            case .time:
                WelcomePlanFiveMinuteTimePicker(selection: $timeDraft)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .onboardingChatAnswerReveal(isRevealed: isAnswerRevealed("time_picker"))

                chatPrimaryButton("Continuer") {
                    await viewModel.submitTime(timeDraft)
                }
                .onboardingChatAnswerReveal(isRevealed: isAnswerRevealed("time_continue"))

            case .text:
                TextField("Ta réponse…", text: $textDraft, axis: .vertical)
                    .lineLimit(2...4)
                    .font(.system(size: OnboardingProfileChatDepthStyle.answerFontSize))
                    .foregroundStyle(OnboardingTheme.primaryText)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .processGlassEffect(
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous),
                        interactive: false
                    )
                    .onboardingChatAnswerReveal(isRevealed: isAnswerRevealed("text_field"))

                HStack(spacing: 12) {
                    if question.allowsSkip {
                        chatChoiceButton(title: "Passer", centered: true) {
                            await viewModel.submitText("", skipped: true)
                            textDraft = ""
                        }
                        .onboardingChatAnswerReveal(isRevealed: isAnswerRevealed("skip"))
                    }

                    chatPrimaryButton("Envoyer", disabled: textDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                        await viewModel.submitText(textDraft)
                        textDraft = ""
                    }
                    .onboardingChatAnswerReveal(isRevealed: isAnswerRevealed("send"))
                }
            }
        }
        .padding(.top, 10)
        .animation(OnboardingProfileChatAnswerReveal.spring, value: viewModel.showsAnswerOptions)
    }

    // MARK: - CTA

    private var multiChoiceValidateButton: some View {
        let isDisabled = multiSelection.isEmpty || viewModel.isSubmittingAnswer

        return Button {
            guard !isDisabled else { return }
            HapticManager.shared.impact(.medium)
            let selection = multiSelection
            multiSelection = []
            Task { await viewModel.submitMultiChoice(selection) }
        } label: {
            Text("Valider")
                .font(.system(size: OnboardingProfileChatDepthStyle.answerFontSize + 1, weight: .bold))
                .foregroundStyle(isDisabled ? OnboardingTheme.mutedText : OnboardingTheme.actionButtonText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .contentShape(answerButtonShape)
        }
        .processGlassButton(in: answerButtonShape)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.55 : 1)
        .onboardingChatAnswerReveal(isRevealed: isAnswerRevealed("validate"))
    }

    private var enterAppButton: some View {
        Button {
            HapticManager.shared.impact(.medium)
            Task {
                if viewModel.pendingFaceScan {
                    await viewModel.finishAndEnterApp {
                        showFaceScan = true
                        onComplete()
                    }
                } else {
                    await viewModel.finishAndEnterApp(onComplete: onComplete)
                }
            }
        } label: {
            Text(enterButtonTitle)
                .font(.system(size: OnboardingProfileChatDepthStyle.answerFontSize + 1, weight: .bold))
                .foregroundStyle(OnboardingTheme.actionButtonText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .contentShape(answerButtonShape)
        }
        .processGlassButton(in: answerButtonShape)
    }

    private var enterButtonTitle: String {
        viewModel.pendingFaceScan ? "Entrer & lancer le scan" : "Entrer dans Process"
    }

    // MARK: - Buttons

    private func chatChoiceButton(
        title: String,
        centered: Bool = false,
        action: @escaping () async -> Void
    ) -> some View {
        Button {
            guard !viewModel.isSubmittingAnswer else { return }
            HapticManager.shared.selection()
            Task { await action() }
        } label: {
            Text(title)
                .font(.system(size: OnboardingProfileChatDepthStyle.answerFontSize, weight: .semibold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .multilineTextAlignment(centered ? .center : .leading)
                .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .contentShape(answerButtonShape)
        }
        .processGlassButton(in: answerButtonShape)
        .disabled(viewModel.isSubmittingAnswer)
    }

    private func chatMultiChoiceButton(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            guard !viewModel.isSubmittingAnswer else { return }
            HapticManager.shared.selection()
            action()
        } label: {
            HStack(spacing: 12) {
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
        .disabled(viewModel.isSubmittingAnswer)
    }

    private func chatPrimaryButton(
        _ title: String,
        disabled: Bool = false,
        action: @escaping () async -> Void
    ) -> some View {
        let isDisabled = disabled || viewModel.isSubmittingAnswer

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

private struct WelcomePlanFiveMinuteTimePicker: UIViewRepresentable {
    @Binding var selection: Date

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.datePickerMode = .time
        picker.preferredDatePickerStyle = .wheels
        picker.minuteInterval = 5
        picker.date = selection
        picker.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .valueChanged)
        return picker
    }

    func updateUIView(_ picker: UIDatePicker, context: Context) {
        if abs(picker.date.timeIntervalSince(selection)) > 1 {
            picker.date = selection
        }
    }

    final class Coordinator: NSObject {
        @Binding var selection: Date

        init(selection: Binding<Date>) {
            _selection = selection
        }

        @objc func changed(_ picker: UIDatePicker) {
            selection = picker.date
        }
    }
}

#Preview("Protocole Origine") {
    WelcomePlanChatView(onComplete: {})
        .environmentObject(UnifiedProfileService.shared)
}
