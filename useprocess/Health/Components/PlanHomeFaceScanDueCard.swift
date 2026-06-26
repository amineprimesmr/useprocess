import SwiftUI

/// Carte « scan à faire » — ouvre le flux capture plein écran (pas de caméra inline).
struct PlanHomeFaceScanDueCard: View {
    let isFirstScan: Bool
    var planScanHint: String?
    var onStartScan: () -> Void

    @Environment(\.appTheme) private var theme

    private let cardRadius: CGFloat = 22

    var body: some View {
        Button {
            HapticManager.shared.impact(.medium)
            onStartScan()
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        theme.onboardingAccent.opacity(0.22),
                                        theme.glow.opacity(0.12)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)

                        Image(systemName: "viewfinder")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(theme.onboardingAccent)
                            .symbolEffect(.pulse.byLayer, options: .repeating.speed(0.55))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(isFirstScan ? "Premier scan visage" : "C'est le moment")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(theme.primaryText)

                        Text(isFirstScan
                            ? "30 secondes pour calibrer ton debloat et ta progression."
                            : "Scan du jour — puis analyse avec le coach.")
                            .font(.subheadline)
                            .foregroundStyle(theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if let planScanHint, !planScanHint.isEmpty {
                    Label(planScanHint, systemImage: "calendar.badge.clock")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(theme.onboardingAccent.opacity(0.92))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Label(isFirstScan ? "Lancer mon premier scan" : "Scanner maintenant", systemImage: "camera.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(theme.onboardingAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(theme.onboardingAccent.opacity(theme.isDark ? 0.16 : 0.1))
                    )
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
            .overlay(cardBorder)
            .clipShape(RoundedRectangle(cornerRadius: cardRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Scanner le visage")
    }

    private var cardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .fill(theme.isDark ? Color(red: 0.11, green: 0.11, blue: 0.12) : theme.cardBackgroundStrong)

            LinearGradient(
                colors: [
                    theme.onboardingAccent.opacity(theme.isDark ? 0.12 : 0.07),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        theme.onboardingAccent.opacity(0.5),
                        theme.glow.opacity(0.3),
                        theme.onboardingAccent.opacity(0.15)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1.5
            )
    }
}
