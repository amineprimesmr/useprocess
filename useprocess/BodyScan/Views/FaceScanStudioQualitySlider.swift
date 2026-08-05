import SwiftUI

/// Slider studio Mauvais → Réaliste → Excellent (mode créateur `Amineprcs`).
struct FaceScanStudioQualitySlider: View {
    @Binding var quality: Double
    var onEditingEnded: ((Double) -> Void)? = nil

    private var label: String {
        switch quality {
        case ..<0.2: return AppCopy.t("Mauvais", en: "Poor")
        case ..<0.4: return AppCopy.t("Faible", en: "Weak")
        case ..<0.6: return AppCopy.t("Réaliste", en: "Realistic")
        case ..<0.8: return AppCopy.t("Bon", en: "Good")
        default: return AppCopy.t("Excellent", en: "Excellent")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(AppCopy.t("Rendu résultats", en: "Results look"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FaceScanWhoopPalette.secondary)
                Spacer()
                Text(label)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(FaceScanWhoopPalette.label)
                    .contentTransition(.opacity)
            }

            Slider(
                value: Binding(
                    get: { quality },
                    set: { newValue in
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            quality = newValue
                        }
                    }
                ),
                in: 0...1,
                onEditingChanged: { editing in
                    if !editing {
                        onEditingEnded?(quality)
                    }
                }
            )
            .tint(FaceScanWhoopPalette.label)

            HStack {
                Text(AppCopy.t("Mauvais", en: "Poor"))
                Spacer()
                Text(AppCopy.t("Réaliste", en: "Realistic"))
                Spacer()
                Text(AppCopy.t("Excellent", en: "Excellent"))
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(FaceScanWhoopPalette.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(FaceScanWhoopPalette.card)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(AppCopy.t("Rendu résultats", en: "Results look"))
        .accessibilityValue(label)
    }
}
