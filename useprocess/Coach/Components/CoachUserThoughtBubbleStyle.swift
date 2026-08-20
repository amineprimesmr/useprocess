import SwiftUI

enum CoachUserThoughtBubbleMetrics {
    static let cornerRadius: CGFloat = 24
    static let horizontalPadding: CGFloat = 20
    static let verticalPadding: CGFloat = 14
    static let avatarSize: CGFloat = 40
    static let tailLarge: CGFloat = 11
    static let tailMedium: CGFloat = 8
    static let tailSmall: CGFloat = 5
}

/// Trois pastilles reliant la bulle à l’avatar (style « bulle de pensée »).
struct CoachThoughtBubbleTailView: View {
    var color: Color

    var body: some View {
        ZStack(alignment: .topLeading) {
            Circle()
                .fill(color)
                .frame(width: CoachUserThoughtBubbleMetrics.tailLarge, height: CoachUserThoughtBubbleMetrics.tailLarge)
                .offset(x: -5, y: 0)

            Circle()
                .fill(color)
                .frame(width: CoachUserThoughtBubbleMetrics.tailMedium, height: CoachUserThoughtBubbleMetrics.tailMedium)
                .offset(x: 0, y: 10)

            Circle()
                .fill(color)
                .frame(width: CoachUserThoughtBubbleMetrics.tailSmall, height: CoachUserThoughtBubbleMetrics.tailSmall)
                .offset(x: 5, y: 17)
        }
        .frame(width: 14, height: 26, alignment: .topLeading)
        .padding(.bottom, 8)
    }
}

struct CoachUserChatAvatarView: View {
    var profile: UnifiedUserProfile?
    var bubbleColor: Color
    var textColor: Color
    var size: CGFloat = CoachUserThoughtBubbleMetrics.avatarSize

    private var initials: String {
        let first = profile?.firstName.trimmingCharacters(in: .whitespacesAndNewlines).first.map(String.init) ?? ""
        let last = profile?.lastName?.trimmingCharacters(in: .whitespacesAndNewlines).first.map(String.init) ?? ""
        let combined = (first + last).uppercased()
        if combined.isEmpty {
            return String(profile?.firstName.prefix(2) ?? "ME").uppercased()
        }
        return String(combined.prefix(2))
    }

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.34, weight: .semibold))
            .foregroundStyle(textColor)
            .frame(width: size, height: size)
            .background(bubbleColor, in: Circle())
            .clipShape(Circle())
    }
}

struct CoachUserThoughtBubbleBody<Content: View>: View {
    var bubbleColor: Color
    @ViewBuilder var content: () -> Content

    @Environment(\.appTheme) private var theme

    var body: some View {
        content()
            .padding(.horizontal, CoachUserThoughtBubbleMetrics.horizontalPadding)
            .padding(.vertical, CoachUserThoughtBubbleMetrics.verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: CoachUserThoughtBubbleMetrics.cornerRadius, style: .continuous)
                    .fill(bubbleColor)
                    .overlay {
                        if !theme.isDark {
                            RoundedRectangle(cornerRadius: CoachUserThoughtBubbleMetrics.cornerRadius, style: .continuous)
                                .strokeBorder(theme.coachSurfaceStroke.opacity(0.85), lineWidth: 0.75)
                        }
                    }
                    .shadow(
                        color: theme.isDark ? .clear : theme.coachSurfaceStroke.opacity(0.28),
                        radius: 10,
                        y: 4
                    )
            )
    }
}
