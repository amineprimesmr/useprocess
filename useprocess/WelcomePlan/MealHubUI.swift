import SwiftUI

// MARK: - Alternatives ingrédient (chips)

struct MealItemAlternativesBar: View {
    let alternatives: [String]
    var isLoading: Bool
    var onSelect: (String) -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppCopy.t("Alternatives", en: "Alternatives"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.secondaryText)

            if isLoading {
                ProgressView().controlSize(.small)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(alternatives, id: \.self) { alt in
                            Button {
                                HapticManager.shared.selection()
                                onSelect(alt)
                            } label: {
                                Text(alt)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(theme.onboardingAccent.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.processPlain)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Photo frigo

struct MealPhotoScanSheet: View {
    let panelHeight: CGFloat
    var onCapture: (UIImage) -> Void
    var onCancel: () -> Void

    var body: some View {
        CoachInlineBottomCameraPanel(
            panelHeight: panelHeight,
            showsDismissButton: false,
            useGlassCaptureButton: true,
            controlsVerticalOffset: 12,
            onCapture: onCapture,
            onPickFromGallery: onCapture,
            onCancel: onCancel
        )
    }
}
