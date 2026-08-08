import SwiftUI

/// Sélecteur studio — page analyse normale vs premier scan (graisse / rétention).
struct FaceScanStudioResultsLayoutPicker: View {
    @Binding var layout: ProcessCreatorScanResultsLayout

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppCopy.t("Page analyse", en: "Analysis page"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(FaceScanWhoopPalette.secondary)

            Picker(
                AppCopy.t("Page analyse", en: "Analysis page"),
                selection: $layout
            ) {
                ForEach(ProcessCreatorScanResultsLayout.allCases) { option in
                    Text(shortTitle(for: option)).tag(option)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(FaceScanWhoopPalette.card)
        }
    }

    private func shortTitle(for option: ProcessCreatorScanResultsLayout) -> String {
        switch option {
        case .standard:
            return AppCopy.t("Normal", en: "Normal")
        case .onboardingDeep:
            return AppCopy.t("1er scan", en: "1st scan")
        }
    }
}
