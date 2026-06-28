import SwiftUI

/// Tokens visuels communs aux blocs de la page Accueil / Plan.
enum PlanHomeSectionDesign {
    static let sectionSpacing: CGFloat = 58
    static let firstSectionTopSpacing: CGFloat = 8
    /// Marge supplémentaire au-dessus du scan quand c’est la première section.
    static let faceScanTopSpacing: CGFloat = 12
    static let headerContentSpacing: CGFloat = 12
    static let titleSize: CGFloat = 17
    static let trailingSize: CGFloat = 13
    /// Padding horizontal du scroll Accueil (`LazyVStack.padding()`).
    static let homeScrollPadding: CGFloat = 16
}

struct PlanHomeSectionHeader: View {
    let title: String
    var trailingCaption: String?
    var actionTitle: String?
    var action: (() -> Void)?

    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.system(size: PlanHomeSectionDesign.titleSize, weight: .semibold))
                .foregroundStyle(theme.primaryText)

            Spacer(minLength: 8)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.system(size: PlanHomeSectionDesign.trailingSize, weight: .semibold))
                    .foregroundStyle(theme.secondaryText)
            } else if let trailingCaption {
                Text(trailingCaption)
                    .font(.system(size: PlanHomeSectionDesign.trailingSize, weight: .medium))
                    .foregroundStyle(theme.secondaryText)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}
