import SwiftUI

enum HealthHubDesign {
    static func sectionHeader(_ title: String, subtitle: String, theme: AppTheme) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
                .foregroundStyle(theme.primaryText)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
        }
    }

    static func softCard(theme: AppTheme) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(theme.coachUserBubble.opacity(0.3))
    }

    static func surfaceCard(theme: AppTheme) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(theme.cardBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(theme.cardStroke, lineWidth: theme.isDark ? 0 : 0.5)
            }
    }
}
