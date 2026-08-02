import SwiftUI

/// Salutation d’accueil du coach — inline dans le scroll ou plein écran.
struct CoachContextualHomeView: View {
    let prompt: CoachHomePrompt
    var mealHandoff: CoachMealHandoff? = nil
    var embeddedInScroll: Bool = false

    @Environment(\.appTheme) private var theme

    private let messageLineSpacing: CGFloat = 5
    private let horizontalPadding: CGFloat = 20

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let handoff = mealHandoff {
                CoachMealSuggestionMessageView(
                    content: CoachMealContentEnricher.enrich(handoff.meal)
                )
                .padding(.horizontal, horizontalPadding)
                .padding(.top, topContentPadding)
                .padding(.bottom, 14)
            }

            Text(prompt.greetingText)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(theme.primaryText)
                .lineSpacing(messageLineSpacing)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, horizontalPadding)
                .padding(.top, mealHandoff == nil ? topContentPadding : 0)
                .padding(.bottom, embeddedInScroll ? 12 : 0)

            if !embeddedInScroll {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: embeddedInScroll ? nil : .infinity, alignment: .topLeading)
    }

    private var topContentPadding: CGFloat { 16 }
}
