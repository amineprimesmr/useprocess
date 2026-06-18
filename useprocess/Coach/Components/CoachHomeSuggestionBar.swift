import SwiftUI

struct CoachHomeSuggestionBar: View {
    let suggestions: [CoachHomeSuggestion]
    var isRevealed: Bool
    var instantReveal: Bool = false
    var isDisabled: Bool
    var onSelect: (CoachHomeSuggestion) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var revealedIDs: Set<String> = []
    @State private var selectedID: String?
    @State private var isSelecting = false

    private let buttonShape = Capsule()
    private let selectSpring = Animation.spring(response: 0.34, dampingFraction: 0.86)
    private let dismissDelay: UInt64 = 220_000_000

    private var invertedFill: Color {
        colorScheme == .dark ? .white : .black
    }

    private var invertedLabel: Color {
        colorScheme == .dark ? .black : .white
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(suggestions) { suggestion in
                let visible = isButtonVisible(id: suggestion.id)

                Button {
                    handleSelection(suggestion, visible: visible)
                } label: {
                    Text(suggestion.label)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(invertedLabel)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .contentShape(buttonShape)
                        .background {
                            suggestionGlassBackground
                        }
                }
                .buttonStyle(CoachSuggestionPressStyle())
                .disabled(isDisabled || !visible || isSelecting)
                .opacity(rowOpacity(for: suggestion.id))
                .scaleEffect(rowScale(for: suggestion.id))
                .offset(y: rowOffset(for: suggestion.id))
                .modifier(CoachSuggestionRevealStyle(isVisible: visible, animated: usesRevealAnimation))
            }
        }
        .animation(selectSpring, value: selectedID)
        .animation(selectSpring, value: isSelecting)
        .task(id: staggerRevealTaskID) {
            guard usesRevealAnimation else { return }
            await runStaggerReveal()
        }
        .onChange(of: instantReveal) { _, skip in
            if skip, isRevealed {
                revealedIDs = Set(suggestions.map(\.id))
            }
        }
        .onAppear {
            if instantReveal, isRevealed {
                revealedIDs = Set(suggestions.map(\.id))
            }
        }
    }

    private var usesRevealAnimation: Bool {
        isRevealed && !instantReveal
    }

    private var staggerRevealTaskID: String {
        suggestions.map(\.id).joined(separator: "-") + "-\(isRevealed)"
    }

    private func isButtonVisible(id: String) -> Bool {
        guard isRevealed else { return false }
        if instantReveal { return true }
        return revealedIDs.contains(id)
    }

    private func rowOpacity(for id: String) -> Double {
        if isDisabled { return 0.55 }
        guard let selectedID else { return 1 }
        return id == selectedID ? 1 : 0
    }

    private func rowScale(for id: String) -> CGFloat {
        guard let selectedID else { return 1 }
        return id == selectedID ? 0.975 : 0.94
    }

    private func rowOffset(for id: String) -> CGFloat {
        guard let selectedID, id != selectedID else { return 0 }
        return 6
    }

    private func handleSelection(_ suggestion: CoachHomeSuggestion, visible: Bool) {
        guard !isDisabled, visible, !isSelecting else { return }

        isSelecting = true
        selectedID = suggestion.id
        HapticManager.shared.impact(.light)

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: dismissDelay)
            onSelect(suggestion)
        }
    }

    @ViewBuilder
    private var suggestionGlassBackground: some View {
        if #available(iOS 26.0, *) {
            buttonShape
                .fill(.clear)
                .glassEffect(ProcessGlass.filterSelected(invertedFill), in: buttonShape)
        } else {
            buttonShape.fill(invertedFill)
        }
    }

    @MainActor
    private func runStaggerReveal() async {
        guard isRevealed, !instantReveal else { return }

        revealedIDs = []

        try? await Task.sleep(nanoseconds: OnboardingProfileChatAnswerReveal.initialDelay)
        guard isRevealed, !instantReveal else { return }

        for (index, suggestion) in suggestions.enumerated() {
            if Task.isCancelled { return }
            guard isRevealed, !instantReveal else { return }
            if index > 0 {
                try? await Task.sleep(nanoseconds: OnboardingProfileChatAnswerReveal.staggerDelay)
            }
            if Task.isCancelled { return }
            guard isRevealed, !instantReveal else { return }
            withAnimation(OnboardingProfileChatAnswerReveal.spring) {
                revealedIDs.insert(suggestion.id)
            }
        }
    }
}

private struct CoachSuggestionPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.988 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.84), value: configuration.isPressed)
    }
}

private struct CoachSuggestionRevealStyle: ViewModifier {
    let isVisible: Bool
    let animated: Bool

    func body(content: Content) -> some View {
        if animated {
            content.onboardingChatAnswerReveal(isRevealed: isVisible)
        } else {
            content
                .opacity(isVisible ? 1 : 0)
                .allowsHitTesting(isVisible)
        }
    }
}
