import SwiftUI

/// Réglages studio (visible seulement si mode créateur débloqué).
struct ProcessCreatorStudioView: View {
    @ObservedObject private var creator = ProcessCreatorModeStore.shared
    @Environment(\.appTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(AppCopy.t("Studio contenu", en: "Content Studio"))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(theme.primaryText)

                Text(AppCopy.t("Import photo illimité sur le scan. Sur l’écran résultats, un slider te laisse choisir un rendu de Mauvais → Réaliste → Excellent.", en: "Unlimited photo import for scans. On the results screen, a slider lets you choose a result from Poor → Realistic → Excellent."))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(AppCopy.t("Rendu par défaut", en: "Default Result"))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(theme.primaryText)
                        Spacer()
                        Text(creator.qualityLabel)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(theme.onboardingAccent)
                    }

                    Slider(value: $creator.resultQuality, in: 0...1)
                        .tint(theme.onboardingAccent)

                    HStack {
                        Text(AppCopy.t("Mauvais", en: "Poor"))
                        Spacer()
                        Text(AppCopy.t("Réaliste", en: "Realistic"))
                        Spacer()
                        Text(AppCopy.t("Excellent", en: "Excellent"))
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.secondaryText)
                }
                .padding(16)
                .background {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.clear)
                        .processGlassEffect(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(AppCopy.t("Page scan analyse", en: "Scan analysis page"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.primaryText)

                    Picker(
                        AppCopy.t("Page scan analyse", en: "Scan analysis page"),
                        selection: $creator.scanResultsLayout
                    ) {
                        ForEach(ProcessCreatorScanResultsLayout.allCases) { layout in
                            Text(layout.title).tag(layout)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(creator.scanResultsLayout.subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .background {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.clear)
                        .processGlassEffect(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                Text(AppCopy.t("Astuce : tu peux encore ajuster le slider pendant l’écran résultats, avant de taper Continuer.", en: "Tip: you can still adjust the slider on the results screen before tapping Continue."))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.secondaryText.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, AccountDetailsTheme.horizontalPadding)
            .padding(.top, 12)
            .padding(.bottom, 36)
        }
        .navigationTitle(AppCopy.t("Studio", en: "Studio"))
        .navigationBarTitleDisplayMode(.inline)
        .reportsProfileSubrouteActive(true)
    }
}

/// Entrée hub Réglages — uniquement si débloqué.
struct ProcessCreatorStudioHubLink: View {
    @ObservedObject private var creator = ProcessCreatorModeStore.shared
    @Environment(\.appTheme) private var theme

    var body: some View {
        if creator.isUnlocked {
            NavigationLink {
                ProcessCreatorStudioView()
                    .reportsProfileSubrouteActive(true)
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(theme.onboardingAccent)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(AppCopy.t("Studio contenu", en: "Content Studio"))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(theme.primaryText)
                        Text(AppCopy.t(
                            "Rendu : \(creator.qualityLabel) · \(creator.scanResultsLayout.title)",
                            en: "Result: \(creator.qualityLabel) · \(creator.scanResultsLayout.title)"
                        ))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(theme.secondaryText)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.secondaryText.opacity(0.55))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.clear)
                        .processGlassEffect(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .buttonStyle(.processPlain)
        }
    }
}
