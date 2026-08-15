import SwiftUI

struct CoachHomeSuggestionBar: View {
    let suggestions: [CoachHomeSuggestion]
    var isDisabled: Bool
    var onSelect: (CoachHomeSuggestion) -> Void

    @Environment(\.appTheme) private var theme
    @State private var selectedID: String?
    @State private var isSelecting = false

    private let cardWidth: CGFloat = min(UIScreen.main.bounds.width - 56, 248)
    private let cardHeight: CGFloat = 54

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestions) { suggestion in
                    CoachHomeSuggestionCard(
                        suggestion: suggestion,
                        cardWidth: cardWidth,
                        cardHeight: cardHeight,
                        isDisabled: isDisabled || isSelecting,
                        opacity: rowOpacity(for: suggestion.id)
                    ) {
                        handleSelection(suggestion)
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .contentMargins(.horizontal, 20, for: .scrollContent)
    }

    private func rowOpacity(for id: String) -> Double {
        if isDisabled { return 0.55 }
        guard let selectedID else { return 1 }
        return id == selectedID ? 1 : 0.72
    }

    private func handleSelection(_ suggestion: CoachHomeSuggestion) {
        guard !isDisabled, !isSelecting else { return }

        isSelecting = true
        selectedID = suggestion.id
        HapticManager.shared.impact(.light)
        onSelect(suggestion)
        isSelecting = false
    }
}

private struct CoachHomeSuggestionCard: View {
    let suggestion: CoachHomeSuggestion
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let isDisabled: Bool
    let opacity: Double
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
        .processGlassButton(in: cardShape)
        .disabled(isDisabled)
        .opacity(opacity)
    }
}
