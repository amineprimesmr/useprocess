import SwiftUI

/// Catégories du hub Paramètres — chaque entrée ouvre une sous-page.
enum ProfileSettingsCategory: String, Hashable, Identifiable, CaseIterable {
    case referral
    case account
    case health
    case app
    case legal

    var id: String { rawValue }

    @MainActor
    var title: String {
        switch self {
        case .referral: return AppCopy.t("Parrainage", en: "Referral Program")
        case .account: return AppCopy.t("Compte", en: "Account")
        case .health: return AppCopy.t("Santé & données", en: "Health & Data")
        case .app: return AppCopy.t("Application", en: "App")
        case .legal: return AppCopy.t("Aide & confidentialité", en: "Help & Privacy")
        }
    }
}

// MARK: - Hub paramètres (section unique fond clair)

struct ProfileSettingsGroupedSection<Content: View>: View {
    @Environment(\.appTheme) private var theme
    @ViewBuilder private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
    }

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .background {
            shape.fill(surfaceFill)
        }
        .overlay {
            shape.strokeBorder(Color.primary.opacity(theme.isDark ? 0.10 : 0.07), lineWidth: 0.5)
        }
        .clipShape(shape)
    }

    private var surfaceFill: Color {
        theme.isDark
            ? theme.cardBackgroundStrong.opacity(0.78)
            : Color.white.opacity(0.98)
    }
}

struct ProfileSettingsHubTitleRow: View {
    let title: String

    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(theme.primaryText)

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(theme.secondaryText.opacity(0.55))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
    }
}

private struct ProfileSettingsHubDivider: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        Divider()
            .overlay(Color(.separator).opacity(theme.isDark ? 0.55 : 0.85))
            .padding(.leading, 16)
    }
}

struct ProfileSettingsCategoryHubRow: View {
    let category: ProfileSettingsCategory

    var body: some View {
        ProfileSettingsHubTitleRow(title: category.title)
    }
}

struct ProfileSettingsActivityStatusPill: View {
    let status: ProcessActivityStatus
    let action: () -> Void

    @Environment(\.appTheme) private var theme

    private enum Metrics {
        static let iconSide: CGFloat = 40
        static let iconRadius: CGFloat = 15
        static let pillMaxWidth: CGFloat = 292
    }

    private let shape = Capsule(style: .continuous)

    private var iconShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Metrics.iconRadius, style: .continuous)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    iconShape
                        .fill(status.accentColor)
                        .frame(width: Metrics.iconSide, height: Metrics.iconSide)
                        .shadow(
                            color: status.accentColor.opacity(0.35),
                            radius: 0,
                            y: 1
                        )

                    Image(systemName: status.systemImage)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(status.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(theme.primaryText)

                    Text(AppCopy.t("Modifiable", en: "Editable"))
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(theme.secondaryText.opacity(0.65))
            }
            .padding(.leading, 7)
            .padding(.trailing, 14)
            .padding(.vertical, 7)
            .frame(maxWidth: Metrics.pillMaxWidth)
            .background {
                shape.fill(pillFill)
            }
            .overlay {
                shape.strokeBorder(Color.primary.opacity(theme.isDark ? 0.08 : 0.05), lineWidth: 0.5)
            }
            .shadow(
                color: Color.black.opacity(theme.isDark ? 0.20 : 0.06),
                radius: 10,
                y: 4
            )
            .contentShape(shape)
        }
        .buttonStyle(.processPlain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(AppCopy.t("Statut d'activité, \(status.title)", en: "Activity status, \(status.title)"))
        .accessibilityValue(AppCopy.t("Modifiable", en: "Editable"))
        .accessibilityHint(AppCopy.t("Modifier le statut du jour", en: "Change today's status"))
    }

    private var pillFill: Color {
        theme.isDark
            ? theme.cardBackgroundStrong.opacity(0.95)
            : Color.white
    }
}

struct ProfileSettingsHubLinksSection: View {
    var body: some View {
        ProfileSettingsGroupedSection {
            ForEach(Array(ProfileSettingsCategory.allCases.enumerated()), id: \.element.id) { index, category in
                if index > 0 {
                    ProfileSettingsHubDivider()
                }

                NavigationLink(value: category) {
                    ProfileSettingsCategoryHubRow(category: category)
                }
                .buttonStyle(.processPlain)
            }
        }
    }
}

@ViewBuilder
func profileSettingsDetail(for category: ProfileSettingsCategory) -> some View {
    switch category {
    case .referral:
        ProcessReferralProgramDetailView()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background {
                ProcessReferralTheme.pageBackground.ignoresSafeArea()
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationBarBackButtonHidden(true)
    case .account:
        ProfileSettingsAccountDetailView()
            .processSettingsDetailPage()
    case .health:
        ProfileSettingsHealthDetailView()
            .processSettingsDetailPage()
    case .app:
        ProfileSettingsAppDetailView()
            .processSettingsDetailPage()
    case .legal:
        ProfileSettingsLegalDetailView()
            .processSettingsDetailPage()
    }
}
