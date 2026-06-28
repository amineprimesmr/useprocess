import SwiftUI

/// Catégories du hub Paramètres — chaque entrée ouvre une sous-page.
enum ProfileSettingsCategory: String, Hashable, Identifiable, CaseIterable {
    case profile
    case account
    case health
    case app
    case legal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .profile: return "Profil"
        case .account: return "Compte"
        case .health: return "Santé & données"
        case .app: return "Application"
        case .legal: return "Aide & confidentialité"
        }
    }

    var subtitle: String {
        switch self {
        case .profile: return "Photo et partage"
        case .account: return "Identité et tag Process"
        case .health: return "Apple Santé, scans et sources"
        case .app: return "Apparence"
        case .legal: return "Conditions, support et infos"
        }
    }

    var icon: String {
        switch self {
        case .profile: return "person.crop.circle"
        case .account: return "person.text.rectangle"
        case .health: return "heart.text.square"
        case .app: return "circle.lefthalf.filled"
        case .legal: return "doc.text"
        }
    }
}

struct ProfileSettingsCategoryHubRow: View {
    let category: ProfileSettingsCategory

    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: category.icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(theme.onboardingAccent)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(category.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(theme.primaryText)
                Text(category.subtitle)
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(theme.secondaryText.opacity(0.55))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

@ViewBuilder
func profileSettingsDetail(for category: ProfileSettingsCategory, onShareProfile: @escaping () -> Void) -> some View {
    switch category {
    case .profile:
        ProfileSettingsProfileDetailView(onShareProfile: onShareProfile)
    case .account:
        ProfileSettingsAccountDetailView()
    case .health:
        ProfileSettingsHealthDetailView()
    case .app:
        ProfileSettingsAppDetailView()
    case .legal:
        ProfileSettingsLegalDetailView()
    }
}
