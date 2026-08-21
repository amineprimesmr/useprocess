import SwiftUI

/// Voile + overlay « calibration » sur un graphe ou un carousel. Pas de CTA paywall.
struct ProcessCalibrationLockOverlay: View {
    let surface: ProcessCalibrationSurface
    let remainingDays: Int

    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(spacing: 10) {
            availabilityBadge

            Text(ProcessCalibrationCopy.title(for: surface))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(theme.primaryText)
                .multilineTextAlignment(.center)

            Text(ProcessCalibrationCopy.subtitle(for: surface))
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(theme.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 22)
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var availabilityBadge: some View {
        Text(ProcessCalibrationCopy.availableIn(days: remainingDays))
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(theme.primaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .processGlassEffect(in: Capsule(), interactive: false)
    }

    private var accessibilityLabel: String {
        [
            ProcessCalibrationCopy.title(for: surface),
            ProcessCalibrationCopy.availableIn(days: remainingDays),
            ProcessCalibrationCopy.subtitle(for: surface)
        ].joined(separator: ". ")
    }
}

/// Bandeau compact au-dessus d’une section (page Série).
struct ProcessCalibrationStatusBanner: View {
    let surface: ProcessCalibrationSurface
    let remainingDays: Int

    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "hourglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(theme.secondaryText)
                .frame(width: 28, height: 28)
                .processGlassEffect(in: RoundedRectangle(cornerRadius: 8, style: .continuous), interactive: false)

            VStack(alignment: .leading, spacing: 2) {
                Text(ProcessCalibrationCopy.title(for: surface))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.primaryText)

                Text(ProcessCalibrationCopy.availableIn(days: remainingDays))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.secondaryText)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .processGlassEffect(
            in: RoundedRectangle(cornerRadius: 18, style: .continuous),
            interactive: false
        )
        .accessibilityElement(children: .combine)
    }
}

enum ProcessCalibrationLockChrome {
    static let blurRadius: CGFloat = 10
    static let dimOpacity: Double = 0.62
}

private struct ProcessCalibrationLockAccessibility: ViewModifier {
    let isLocked: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isLocked {
            content.accessibilityElement(children: .ignore)
        } else {
            content
        }
    }
}

private struct ProcessCalibrationLockModifier: ViewModifier {
    let isLocked: Bool
    let remainingDays: Int
    let surface: ProcessCalibrationSurface?
    var cornerRadius: CGFloat

    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .blur(radius: isLocked ? ProcessCalibrationLockChrome.blurRadius : 0)
            .opacity(isLocked ? ProcessCalibrationLockChrome.dimOpacity : 1)
            .allowsHitTesting(!isLocked)
            .overlay {
                if isLocked {
                    shape
                        .fill(.ultraThinMaterial)
                        .opacity(0.28)
                        .allowsHitTesting(false)
                }
            }
            .overlay {
                if isLocked, let surface {
                    ProcessCalibrationLockOverlay(
                        surface: surface,
                        remainingDays: remainingDays
                    )
                }
            }
            .clipShape(shape)
            .modifier(ProcessCalibrationLockAccessibility(isLocked: isLocked))
            .onAppear { ProcessCalibrationMode.shared.refresh() }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                ProcessCalibrationMode.shared.refresh()
            }
    }
}

extension View {
    /// Floute le contenu et pose l’overlay calibration. `surface == nil` : flou seul.
    func processCalibrationLocked(
        _ isLocked: Bool,
        remainingDays: Int,
        surface: ProcessCalibrationSurface?,
        cornerRadius: CGFloat = 20
    ) -> some View {
        modifier(
            ProcessCalibrationLockModifier(
                isLocked: isLocked,
                remainingDays: remainingDays,
                surface: surface,
                cornerRadius: cornerRadius
            )
        )
    }
}
