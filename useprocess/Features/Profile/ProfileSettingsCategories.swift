import SwiftUI

/// Catégories du hub Paramètres — chaque entrée ouvre une sous-page.
enum ProfileSettingsCategory: String, Hashable, Identifiable, CaseIterable {
    case studio
    case referral
    case account
    case health
    case app
    case language
    case legal

    var id: String { rawValue }

    @MainActor
    var title: String {
        switch self {
        case .studio: return AppCopy.t("Studio contenu", en: "Content Studio")
        case .referral: return AppCopy.t("Parrainage", en: "Refer friends")
        case .account: return AppCopy.t("Compte", en: "Account")
        case .health: return AppCopy.t("Santé & données", en: "Health & Data")
        case .app: return AppCopy.t("Application", en: "App")
        case .language: return AppCopy.t("Langue", en: "Language")
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



@ViewBuilder
func profileSettingsDetail(for category: ProfileSettingsCategory) -> some View {
    switch category {
    case .studio:
        ProcessCreatorStudioView()
    case .referral:
        ProcessReferralProgramDetailView()
    case .account:
        ProfileSettingsAccountDetailView()
    case .health:
        ProfileSettingsHealthDetailView()
    case .app:
        ProfileSettingsAppDetailView()
    case .language:
        ProfileSettingsLanguageDetailView()
    case .legal:
        ProfileSettingsLegalDetailView()
    }
}
