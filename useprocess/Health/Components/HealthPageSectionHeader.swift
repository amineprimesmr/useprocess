import SwiftUI

/// Titre de section pour structurer la page Santé.
struct HealthPageSectionHeader: View {
    let title: String
    var subtitle: String?

    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.secondaryText)
                .textCase(.uppercase)
            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(theme.secondaryText.opacity(0.85))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }
}
