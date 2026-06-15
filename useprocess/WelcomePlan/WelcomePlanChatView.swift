import SwiftUI

struct WelcomePlanChatView: View {
    var previewMode: Bool = false
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
        VStack(spacing: 0) {
            progressHeader

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
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
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    withAnimation(ProcessGlass.spring) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
                .onChange(of: viewModel.isComplete) { _, _ in
                    withAnimation(ProcessGlass.spring) {
                        proxy.scrollTo("complete", anchor: .bottom)
                    }
                }
            }

            if !viewModel.isComplete, let question = viewModel.currentQuestion, !viewModel.isGenerating {
                answerPanel(for: question)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
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

    private var progressHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Protocole Origine")
                    .font(.headline)
                    .foregroundStyle(theme.primaryText)
                Spacer()
                if previewMode {
                    Button("Fermer") { onComplete() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.onboardingAccent)
                }
                Text("\(Int(viewModel.progress * 100)) %")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(theme.secondaryText)
            }
            ProgressView(value: viewModel.progress)
                .tint(theme.onboardingAccent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
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
                    answerButton("Oui", prominent: true) {
                        await viewModel.submitYesNo(true)
                    }
                    answerButton("Non") {
                        await viewModel.submitYesNo(false)
                    }
                }

            case .singleChoice:
                FlowLayout(spacing: 8) {
                    ForEach(question.choices) { choice in
                        answerChip(choice.label) {
                            await viewModel.submitSingleChoice(choice.id)
                        }
                    }
                }

            case .multiChoice:
                FlowLayout(spacing: 8) {
                    ForEach(question.choices) { choice in
                        let selected = multiSelection.contains(choice.id)
                        Button {
                            if selected { multiSelection.remove(choice.id) }
                            else { multiSelection.insert(choice.id) }
                        } label: {
                            Text(choice.label)
                                .font(.subheadline)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(selected ? theme.onboardingAccent.opacity(0.25) : theme.coachUserBubble, in: Capsule())
                                .overlay(Capsule().stroke(selected ? theme.onboardingAccent : .clear, lineWidth: 1.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                welcomePrimaryButton("Valider", disabled: multiSelection.isEmpty) {
                    let selection = multiSelection
                    multiSelection = []
                    await viewModel.submitMultiChoice(selection)
                }

            case .time:
                DatePicker("Heure", selection: $timeDraft, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                answerButton("Continuer", prominent: true) {
                    await viewModel.submitTime(timeDraft)
                }

            case .text:
                TextField("Ta réponse…", text: $textDraft, axis: .vertical)
                    .lineLimit(2...4)
                    .padding(12)
                    .background(theme.coachUserBubble, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                HStack {
                    if question.allowsSkip {
                        answerButton("Passer") {
                            await viewModel.submitText("", skipped: true)
                            textDraft = ""
                        }
                    }
                    answerButton("Envoyer", prominent: true) {
                        await viewModel.submitText(textDraft)
                        textDraft = ""
                    }
                }

            case .info:
                answerButton("Continuer", prominent: true) {
                    await viewModel.submitText("OK", skipped: false)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .onChange(of: viewModel.currentQuestion?.id) { _, _ in
            multiSelection = []
            textDraft = ""
        }
    }

    private func answerButton(_ title: String, prominent: Bool = false, action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            Text(title)
                .font(prominent ? .headline : .subheadline.weight(.semibold))
                .foregroundStyle(prominent ? Color.white : theme.primaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, prominent ? 14 : 12)
                .background(
                    prominent ? theme.onboardingAccent : theme.coachUserBubble,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
        }
        .buttonStyle(.plain)
    }

    private func welcomePrimaryButton(
        _ title: String,
        disabled: Bool = false,
        action: @escaping () async -> Void
    ) -> some View {
        Button {
            Task { await action() }
        } label: {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(theme.onboardingAccent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
    }

    private func answerChip(_ title: String, action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(theme.coachUserBubble, in: Capsule())
        }
        .buttonStyle(.plain)
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
                    .background(theme.coachUserBubble, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        } else {
            Text(message.text)
                .font(messageFont)
                .foregroundStyle(theme.primaryText)
                .lineSpacing(messageLineSpacing)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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
