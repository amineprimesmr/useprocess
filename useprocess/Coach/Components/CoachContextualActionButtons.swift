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
        .processGlassButton(in: buttonShape)
    }
}
