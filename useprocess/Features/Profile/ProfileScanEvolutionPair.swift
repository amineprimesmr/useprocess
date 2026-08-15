import SwiftUI

/// Profil — premier scan (début) et dernier scan, côte à côte, pour voir l’évolution.
struct ProfileScanEvolutionPair: View {
    var isPlaybackActive: Bool = true
    var initials: String = "?"

    @Environment(\.appTheme) private var theme
    @Bindable private var scanStore = FaceScanHistoryStore.shared

    private let cornerRadius: CGFloat = 22
    private let spacing: CGFloat = 12

    private var firstScan: FaceScanResult? {
        scanStore.result(id: ProcessCreatorStudioScanSlot.start.scanId)
            ?? scanStore.oldestResultForProfileIdentity()
    }

    private var lastScan: FaceScanResult? {
        scanStore.result(id: ProcessCreatorStudioScanSlot.now.scanId)
            ?? scanStore.latestResult
    }

    /// Un seul scan : « Maintenant » rejouerait la même vidéo que « Début ».
    private var isNowTeaser: Bool {
        guard let first = firstScan, let last = lastScan else { return false }
        return first.id == last.id
    }

    var body: some View {
        HStack(alignment: .top, spacing: spacing) {
            scanColumn(
                scan: firstScan,
                caption: AppCopy.t("Début", en: "Start"),
                placeholderInitials: initials,
                isTeaser: false
            )
            scanColumn(
                scan: lastScan,
                caption: AppCopy.t("Maintenant", en: "Now"),
                placeholderInitials: nil,
                isTeaser: isNowTeaser
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(AppCopy.t("Évolution du visage", en: "Face evolution"))
    }

    private func scanColumn(
        scan: FaceScanResult?,
        caption: String,
        placeholderInitials: String?,
        isTeaser: Bool
    ) -> some View {
        VStack(spacing: 8) {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    scanTile(
                        scan: scan,
                        placeholderInitials: placeholderInitials,
                        isTeaser: isTeaser
                    )
                }

            VStack(spacing: 2) {
                Text(caption)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.primaryText)

                if isTeaser {
                    Text(AppCopy.t("Débloqué", en: "Unlocked"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.secondaryText)
                } else if let scan {
                    Text(scanDateLabel(scan.createdAt))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.secondaryText)
                        .monospacedDigit()
                }
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(scanAccessibilityLabel(caption: caption, scan: scan, isTeaser: isTeaser))
    }

    @ViewBuilder
    private func scanTile(
        scan: FaceScanResult?,
        placeholderInitials: String?,
        isTeaser: Bool
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        Group {
            if let scan {
                FaceScanRecordingMediaView(
                    result: scan,
                    displayMode: .sidePanel,
                    isPlaybackActive: isPlaybackActive && !isTeaser
                )
                .blur(radius: isTeaser ? 14 : 0)
                .opacity(isTeaser ? 0.78 : 1)
                .overlay {
                    if isTeaser {
                        unlockedLockBadge
                    }
                }
            } else {
                ZStack {
                    theme.cardBackgroundStrong.opacity(0.55)
                    if let placeholderInitials, !placeholderInitials.isEmpty {
                        Text(String(placeholderInitials.prefix(1)).uppercased())
                            .font(.system(size: 42, weight: .bold))
                            .foregroundStyle(theme.primaryText.opacity(0.55))
                    } else {
                        Image(systemName: "viewfinder")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(theme.secondaryText.opacity(0.55))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(theme.cardStroke.opacity(0.55), lineWidth: 0.75)
        }
        .shadow(
            color: Color.black.opacity(theme.isDark ? 0.28 : 0.08),
            radius: 14,
            y: 8
        )
    }

    private var unlockedLockBadge: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.open.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(theme.primaryText.opacity(0.92))
                .padding(11)
                .background {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Circle()
                                .strokeBorder(theme.cardStroke.opacity(0.45), lineWidth: 0.6)
                        }
                }

            Text(AppCopy.t("Débloqué", en: "Unlocked"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.primaryText.opacity(0.92))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func scanDateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = ProcessAppLanguage.shared.locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func scanAccessibilityLabel(caption: String, scan: FaceScanResult?, isTeaser: Bool) -> String {
        if isTeaser {
            return AppCopy.t(
                "\(caption), prochain scan débloqué",
                en: "\(caption), next scan unlocked"
            )
        }
        guard let scan else {
            return caption
        }
        return AppCopy.t(
            "\(caption), scan du \(scanDateLabel(scan.createdAt))",
            en: "\(caption), scan from \(scanDateLabel(scan.createdAt))"
        )
    }
}
