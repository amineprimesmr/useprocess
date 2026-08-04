import SwiftUI

struct CoachContextualActionButtons: View {
    let actions: [CoachContextualAction]
    var onAction: (CoachContextualAction) -> Void

    @Environment(\.appTheme) private var theme

    private let buttonShape = RoundedRectangle(cornerRadius: 16, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(actions) { action in
                actionButton(action)
            }
        }
        .padding(.top, 4)
    }

    private func actionButton(_ action: CoachContextualAction) -> some View {
        Button {
            HapticManager.shared.impact(action.kind.isPrimary ? .medium : .light)
            onAction(action)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: action.kind.icon)
                    .font(.system(size: 14, weight: .semibold))

                Text(action.label)
                    .font(.subheadline.weight(action.kind.isPrimary ? .semibold : .medium))

                Spacer(minLength: 0)

                if action.kind.isPrimary {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .foregroundStyle(theme.primaryText)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(buttonShape)
        }
        .modifier(CoachContextualActionGlassStyle(isPrimary: action.kind.isPrimary, shape: buttonShape))
    }
}

private struct CoachContextualActionGlassStyle: ViewModifier {
    @Environment(\.appTheme) private var theme
    let isPrimary: Bool
    let shape: RoundedRectangle

    @ViewBuilder
    func body(content: Content) -> some View {
        if isPrimary {
            if #available(iOS 26.0, *) {
                content
                    .buttonStyle(.processPlain)
                    .glassEffect(
                        ProcessGlass.tinted(theme.coachAccent, opacity: theme.isDark ? 0.42 : 0.48),
                        in: shape
                    )
                    .buttonStyle(ProcessGlassPressStyle())
            } else {
                content
                    .background(
                        shape.fill(theme.coachAccent.opacity(theme.isDark ? 0.28 : 0.16))
                    )
                    .overlay(shape.strokeBorder(theme.coachAccent.opacity(theme.isDark ? 0.35 : 0.45), lineWidth: 0.75))
                    .buttonStyle(ProcessGlassPressStyle())
            }
        } else {
            if theme.isDark {
                content.processGlassButton(in: shape)
            } else {
                content
                    .background(shape.fill(Color.white))
                    .overlay(shape.strokeBorder(theme.coachSurfaceStroke.opacity(0.85), lineWidth: 0.75))
                    .shadow(color: theme.coachSurfaceStroke.opacity(0.16), radius: 8, y: 3)
                    .buttonStyle(ProcessGlassPressStyle())
            }
        }
    }
}
