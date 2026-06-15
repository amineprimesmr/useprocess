import SwiftUI

/// Toggle CM/FT ou KG/LBS — adapté clair / sombre.
struct OnboardingUnitSegmentToggle: View {
    @Environment(\.colorScheme) private var colorScheme

    let leftLabel: String
    let rightLabel: String
    @Binding var isLeftSelected: Bool

    var body: some View {
        HStack(spacing: 4) {
            segmentButton(label: leftLabel, isSelected: isLeftSelected) {
                isLeftSelected = true
            }
            segmentButton(label: rightLabel, isSelected: !isLeftSelected) {
                isLeftSelected = false
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(OnboardingTheme.segmentTrack(for: colorScheme))
                .shadow(
                    color: OnboardingTheme.segmentTrackShadow(for: colorScheme),
                    radius: 6,
                    x: 0,
                    y: 3
                )
        )
        .frame(width: ScreenMetrics.width - 80)
        .frame(height: 56)
    }

    private func segmentButton(
        label: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                action()
            }
            HapticManager.shared.selection()
        } label: {
            Text(label)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            isSelected
                                ? OnboardingTheme.segmentSelectedFill(for: colorScheme)
                                : Color.clear
                        )
                        .shadow(
                            color: isSelected
                                ? OnboardingTheme.segmentSelectedShadow(for: colorScheme)
                                : .clear,
                            radius: 2,
                            x: 0,
                            y: 1
                        )
                )
        }
    }
}

extension View {
    func onboardingValueGlow(colorScheme: ColorScheme) -> some View {
        let glow = OnboardingTheme.valueGlowColor(for: colorScheme)
        return shadow(color: glow.opacity(0.15), radius: 12, x: 0, y: 0)
            .shadow(color: glow.opacity(0.08), radius: 20, x: 0, y: 0)
    }
}
