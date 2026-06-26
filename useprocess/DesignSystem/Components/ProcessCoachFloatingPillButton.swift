import SwiftUI

/// Pilule flottante type Bevel — coach qui dépasse en haut, glass sombre, chevron.
struct ProcessCoachFloatingPillButton: View {
    let title: String
    var leadingSystemImage: String = "camera.fill"
    let action: () -> Void

    @Environment(\.appTheme) private var theme
    @State private var coachPeekOffset: CGFloat = 0
    @State private var coachGlow = false

    private let pillHeight: CGFloat = 52
    private let coachSize: CGFloat = 38
    private let coachPeek: CGFloat = 22

    var body: some View {
        Button {
            HapticManager.shared.impact(.medium)
            action()
        } label: {
            ZStack(alignment: .top) {
                pillBody
                    .padding(.top, coachPeek)

                coachBadge
            }
        }
        .buttonStyle(ProcessGlassPressStyle())
        .onAppear {
            withAnimation(.easeInOut(duration: 1.65).repeatForever(autoreverses: true)) {
                coachPeekOffset = 3
            }
            withAnimation(.easeInOut(duration: 2.1).repeatForever(autoreverses: true)) {
                coachGlow = true
            }
        }
        .accessibilityLabel(title)
    }

    private var coachBadge: some View {
        Image("caochiaicon")
            .resizable()
            .scaledToFit()
            .frame(width: coachSize, height: coachSize)
            .clipShape(Circle())
            .shadow(
                color: theme.onboardingAccent.opacity(coachGlow ? 0.45 : 0.18),
                radius: coachGlow ? 10 : 4,
                y: 2
            )
            .offset(y: coachPeekOffset)
            .zIndex(1)
    }

    private var pillBody: some View {
        HStack(spacing: 12) {
            Image(systemName: leadingSystemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.primaryText.opacity(0.9))
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(theme.isDark ? Color.white.opacity(0.1) : Color.black.opacity(0.06))
                )

            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(theme.primaryText.opacity(0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.secondaryText.opacity(0.85))
        }
        .padding(.leading, 14)
        .padding(.trailing, 16)
        .frame(maxWidth: .infinity)
        .frame(height: pillHeight)
        .processGlassEffect(in: Capsule(), interactive: true)
        .shadow(color: Color.black.opacity(theme.isDark ? 0.42 : 0.14), radius: 18, y: 10)
    }
}
