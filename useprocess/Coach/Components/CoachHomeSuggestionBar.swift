import SwiftUI

struct CoachHomeSuggestionBar: View {
    let suggestions: [CoachHomeSuggestion]
    var isRevealed: Bool
    var instantReveal: Bool = false
    var isDisabled: Bool
    var onSelect: (CoachHomeSuggestion) -> Void

    @Environment(\.appTheme) private var theme
    @State private var revealedIDs: Set<String> = []
    @State private var selectedID: String?
    @State private var isSelecting = false

    private let selectSpring = Animation.spring(response: 0.34, dampingFraction: 0.86)
    private let dismissDelay: UInt64 = 220_000_000
    private let cardWidth: CGFloat = min(UIScreen.main.bounds.width - 56, 248)
    private let cardHeight: CGFloat = 54

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestions) { suggestion in
                    let visible = isButtonVisible(id: suggestion.id)

                    CoachHomeSuggestionCard(
                        suggestion: suggestion,
                        cardWidth: cardWidth,
                        cardHeight: cardHeight,
                        isVisible: visible,
                        isDisabled: isDisabled || isSelecting,
                        opacity: rowOpacity(for: suggestion.id),
                        offsetY: rowOffset(for: suggestion.id)
                    ) {
                        handleSelection(suggestion, visible: visible)
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .contentMargins(.horizontal, 28, for: .scrollContent)
        .padding(.top, 6)
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
            _ = withAnimation(OnboardingProfileChatAnswerReveal.spring) {
                revealedIDs.insert(suggestion.id)
            }
        }
    }
}

private struct CoachHomeSuggestionCard: View {
    let suggestion: CoachHomeSuggestion
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let isVisible: Bool
    let isDisabled: Bool
    let opacity: Double
    let offsetY: CGFloat
    let onTap: () -> Void

    @Environment(\.appTheme) private var theme

    private let cardShape = RoundedRectangle(cornerRadius: 14, style: .continuous)

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 8) {
                Text(suggestion.icon)
                    .font(.system(size: 20))
                    .frame(width: 26, alignment: .center)

                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.primaryText)
                        .lineLimit(1)

                    Text(suggestion.subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(theme.secondaryText.opacity(0.88))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .frame(width: cardWidth, height: cardHeight)
            .padding(.horizontal, 12)
            .contentShape(cardShape)
        }
        .buttonStyle(.plain)
        .processGlassEffect(in: cardShape, interactive: true)
        .disabled(isDisabled || !isVisible)
        .opacity(isVisible ? opacity : 0)
        .offset(y: isVisible ? offsetY : 8)
        .scaleEffect(isVisible ? 1 : 0.97)
    }
}
