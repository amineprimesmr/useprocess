import SwiftUI

/// Réglages studio (visible seulement si mode créateur débloqué).
struct ProcessCreatorStudioView: View {
    @ObservedObject private var creator = ProcessCreatorModeStore.shared
    @Environment(\.appTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Studio contenu")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(theme.primaryText)

                Text("Import photo illimité sur le scan. Sur l’écran résultats, un slider te laisse choisir un rendu de Mauvais → Réaliste → Excellent.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Rendu par défaut")
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
                        Text("Mauvais")
                        Spacer()
                        Text("Réaliste")
                        Spacer()
                        Text("Excellent")
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

                Text("Astuce : tu peux encore ajuster le slider pendant l’écran résultats, avant de taper Continuer.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.secondaryText.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, AccountDetailsTheme.horizontalPadding)
            .padding(.top, 12)
            .padding(.bottom, 36)
        }
        .navigationTitle("Studio")
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
                        Text("Studio contenu")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(theme.primaryText)
                        Text("Rendu : \(creator.qualityLabel)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(theme.secondaryText)
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
            .buttonStyle(.plain)
        }
    }
}
