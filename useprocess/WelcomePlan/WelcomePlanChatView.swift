import SwiftUI

struct WelcomePlanChatView: View {
    var previewMode: Bool = false
    var embeddedInMainApp: Bool = false
    var selectedSection: Binding<ProcessMainSection>?
    var onComplete: () -> Void

    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var profileService: UnifiedProfileService

    @State private var viewModel = WelcomePlanChatViewModel()
    @State private var multiSelection: Set<String> = []
    @State private var textDraft = ""
    @State private var timeDraft = Calendar.current.date(from: DateComponents(hour: 22, minute: 30)) ?? .now
    @State private var showFaceScan = false

    private let messageFont = Font.system(size: 18, weight: .regular)
    private let messageLineSpacing: CGFloat = 5

    var body: some View {
        Group {
            if embeddedInMainApp, let selectedSection {
                embeddedLayout(selectedSection: selectedSection)
            } else {
                standaloneLayout
            }
        }
        .background(theme.background.ignoresSafeArea())
        .task {
            viewModel.bind(profile: profileService.currentProfile)
            await viewModel.startIfNeeded()
        }
        .fullScreenCover(isPresented: $showFaceScan) {
            FaceScanSessionView(
                onDismiss: { showFaceScan = false },
                onComplete: { _ in showFaceScan = false }
            )
        }
    }

    // MARK: - Embedded (onglet Coach + menu sticky)

    private func embeddedLayout(selectedSection: Binding<ProcessMainSection>) -> some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                processMainScrollableChrome(
                    selectedSection: selectedSection,
                    pageSection: .coach
                ) {
                    messageStack
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    scrollToBottom(proxy)
                }
                .onChange(of: viewModel.isComplete) { _, _ in
                    scrollToBottom(proxy, anchor: .bottom)
                }
            }

            if !viewModel.isComplete, let question = viewModel.currentQuestion, !viewModel.isGenerating {
                answerPanel(for: question)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Standalone (preview depuis la sidebar)

    private var standaloneLayout: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    messageStack
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    scrollToBottom(proxy)
                }
                .onChange(of: viewModel.isComplete) { _, _ in
                    scrollToBottom(proxy, anchor: .bottom)
                }
            }

            if !viewModel.isComplete, let question = viewModel.currentQuestion, !viewModel.isGenerating {
                answerPanel(for: question)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var messageStack: some View {
        LazyVStack(alignment: .leading, spacing: 20) {
            if !viewModel.isComplete {
                progressBar
            }

            ForEach(viewModel.messages) { message in
                messageRow(message)
                    .id(message.id)
                    .coachMessageFadeIn()
            }

            if viewModel.isTyping {
                CoachThinkingBlobPlaceholder()
                    .id("thinking")
            }

            if viewModel.isComplete {
                completionCard
                    .id("complete")
            }

            Color.clear.frame(height: 24).id("bottom")
        }
    }

    private var progressBar: some View {
        HStack(spacing: 10) {
            ProgressView(value: viewModel.progress)
                .tint(Color.primary.opacity(0.85))
            Text("\(Int(viewModel.progress * 100)) %")
                .font(.caption.monospacedDigit().weight(.medium))
                .foregroundStyle(theme.secondaryText)
                .frame(minWidth: 34, alignment: .trailing)
        }
        .padding(.bottom, 4)
    }

    private var completionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let plan = viewModel.generatedPlan {
                WelcomePlanCompactCard(plan: plan)
            }

            welcomePrimaryButton(
                previewMode
                    ? (viewModel.pendingFaceScan ? "Terminer & lancer le scan" : "Terminer la preview")
                    : (viewModel.pendingFaceScan ? "Entrer & lancer le scan" : "Entrer dans Process")
            ) {
                if viewModel.pendingFaceScan {
                    await viewModel.finishAndEnterApp(previewMode: previewMode) {
                        showFaceScan = true
                        onComplete()
                    }
                } else {
                    await viewModel.finishAndEnterApp(previewMode: previewMode, onComplete: onComplete)
                }
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func answerPanel(for question: WelcomePlanQuestion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            switch question.kind {
            case .yesNo:
                HStack(spacing: 12) {
                    answerButton("Oui", prominent: true, inPanel: true) {
                        await viewModel.submitYesNo(true)
                    }
                    answerButton("Non", inPanel: true) {
                        await viewModel.submitYesNo(false)
                    }
                }

            case .singleChoice:
                if question.choices.count == 1, let only = question.choices.first {
                    welcomePrimaryButton(only.label, inPanel: true) {
                        await viewModel.submitSingleChoice(only.id)
                    }
                } else {
                    FlowLayout(spacing: 10) {
                        ForEach(question.choices) { choice in
                            answerChip(choice.label, inPanel: true) {
                                await viewModel.submitSingleChoice(choice.id)
                            }
                        }
                    }
                }

            case .multiChoice:
                FlowLayout(spacing: 10) {
                    ForEach(question.choices) { choice in
                        multiChoiceChip(choice.label, isSelected: multiSelection.contains(choice.id), inPanel: true) {
                            if multiSelection.contains(choice.id) {
                                multiSelection.remove(choice.id)
                            } else {
                                multiSelection.insert(choice.id)
                            }
                        }
                    }
                }
                welcomePrimaryButton("Valider", disabled: multiSelection.isEmpty, inPanel: true) {
                    let selection = multiSelection
                    multiSelection = []
                    await viewModel.submitMultiChoice(selection)
                }

            case .time:
                DatePicker("Heure", selection: $timeDraft, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .welcomePlanPanelInset(cornerRadius: 16)
                answerButton("Continuer", prominent: true, inPanel: true) {
                    await viewModel.submitTime(timeDraft)
                }

            case .text:
                TextField("Ta réponse…", text: $textDraft, axis: .vertical)
                    .lineLimit(2...4)
                    .font(.system(size: 16))
                    .foregroundStyle(theme.primaryText)
                    .padding(14)
                    .welcomePlanPanelInset(cornerRadius: 16)
                HStack(spacing: 12) {
                    if question.allowsSkip {
                        answerButton("Passer", inPanel: true) {
                            await viewModel.submitText("", skipped: true)
                            textDraft = ""
                        }
                    }
                    answerButton("Envoyer", prominent: true, inPanel: true) {
                        await viewModel.submitText(textDraft)
                        textDraft = ""
                    }
                }

            case .info:
                answerButton("Continuer", prominent: true, inPanel: true) {
                    await viewModel.submitText("OK", skipped: false)
                }
            }
        }
        .padding(16)
        .welcomePlanGlass(cornerRadius: 22)
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
        .onChange(of: viewModel.currentQuestion?.id) { _, _ in
            multiSelection = []
            textDraft = ""
        }
    }

    private func answerButton(
        _ title: String,
        prominent: Bool = false,
        inPanel: Bool = false,
        action: @escaping () async -> Void
    ) -> some View {
        Button {
            Task { await action() }
        } label: {
            Text(title)
                .font(prominent ? .headline.weight(.semibold) : .subheadline.weight(.semibold))
                .foregroundStyle(Color.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, prominent ? 14 : 12)
        }
        .buttonStyle(.plain)
        .modifier(WelcomePlanAnswerChromeModifier(
            theme: theme,
            cornerRadius: 14,
            isCapsule: false,
            prominent: prominent,
            isSelected: false,
            inPanel: inPanel
        ))
        .buttonStyle(ProcessGlassPressStyle())
    }

    private func welcomePrimaryButton(
        _ title: String,
        disabled: Bool = false,
        inPanel: Bool = false,
        action: @escaping () async -> Void
    ) -> some View {
        Button {
            Task { await action() }
        } label: {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
        .modifier(WelcomePlanAnswerChromeModifier(
            theme: theme,
            cornerRadius: 14,
            isCapsule: false,
            prominent: true,
            isSelected: false,
            inPanel: inPanel
        ))
        .buttonStyle(ProcessGlassPressStyle())
        .disabled(disabled)
        .opacity(disabled ? 0.72 : 1)
    }

    private func answerChip(_ title: String, inPanel: Bool = false, action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .modifier(WelcomePlanAnswerChromeModifier(
            theme: theme,
            cornerRadius: 999,
            isCapsule: true,
            prominent: false,
            isSelected: false,
            inPanel: inPanel
        ))
        .buttonStyle(ProcessGlassPressStyle())
    }

    private func multiChoiceChip(
        _ title: String,
        isSelected: Bool,
        inPanel: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .modifier(WelcomePlanAnswerChromeModifier(
            theme: theme,
            cornerRadius: 999,
            isCapsule: true,
            prominent: false,
            isSelected: isSelected,
            inPanel: inPanel
        ))
        .buttonStyle(ProcessGlassPressStyle())
    }

    @ViewBuilder
    private func messageRow(_ message: CoachMessage) -> some View {
        if message.role == .user {
            HStack {
                Spacer(minLength: 56)
                Text(message.text)
                    .font(messageFont)
                    .foregroundStyle(theme.primaryText)
                    .lineSpacing(messageLineSpacing)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        theme.coachUserBubble,
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                    )
            }
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

    private func scrollToBottom(_ proxy: ScrollViewProxy, anchor: UnitPoint = .bottom) {
        withAnimation(ProcessGlass.spring) {
            if viewModel.isComplete {
                proxy.scrollTo("complete", anchor: anchor)
            } else {
                proxy.scrollTo("bottom", anchor: anchor)
            }
        }
    }
}

// MARK: - Glass (aligné menu Coach / analyse)

private struct WelcomePlanAnswerChromeModifier: ViewModifier {
    let theme: AppTheme
    let cornerRadius: CGFloat
    let isCapsule: Bool
    let prominent: Bool
    let isSelected: Bool
    let inPanel: Bool

    func body(content: Content) -> some View {
        if inPanel {
            if isCapsule {
                content.background(Capsule().fill(panelFillColor))
            } else {
                content.background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(panelFillColor)
                )
            }
        } else if isCapsule {
            content.welcomePlanGlassCapsule()
        } else {
            content.welcomePlanGlass(cornerRadius: cornerRadius)
        }
    }

    private var panelFillColor: Color {
        if isSelected {
            return Color.primary.opacity(theme.isDark ? 0.16 : 0.1)
        }
        if prominent {
            return Color.primary.opacity(theme.isDark ? 0.12 : 0.08)
        }
        return Color.primary.opacity(theme.isDark ? 0.07 : 0.05)
    }
}

private extension View {
    @ViewBuilder
    func welcomePlanGlass(cornerRadius: CGFloat) -> some View {
        processGlassEffect(in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    @ViewBuilder
    func welcomePlanGlassCapsule() -> some View {
        processGlassEffect(in: Capsule())
    }

    @ViewBuilder
    func welcomePlanPanelInset(cornerRadius: CGFloat) -> some View {
        modifier(WelcomePlanPanelInsetModifier(cornerRadius: cornerRadius))
    }
}

private struct WelcomePlanPanelInsetModifier: ViewModifier {
    @Environment(\.appTheme) private var theme
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content.background(
            Color.primary.opacity(theme.isDark ? 0.07 : 0.05),
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
    }
}

// MARK: - Flow layout for chips

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? UIScreen.main.bounds.width - 32
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var frames: [CGRect] = []

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), frames)
    }
}
