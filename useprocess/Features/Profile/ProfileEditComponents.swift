import SwiftUI
import UIKit

enum AccountConfirmation: Identifiable {
    case logout
    case deleteAccount

    var id: Self { self }

    var title: String {
        switch self {
        case .logout: return "Se déconnecter ?"
        case .deleteAccount: return "Supprimer le compte ?"
        }
    }

    var message: String {
        switch self {
        case .logout:
            return "Tu pourras te reconnecter à tout moment."
        case .deleteAccount:
            return "Cette action est définitive. Toutes tes données seront effacées et tu reviendras au début de Process."
        }
    }

    var confirmTitle: String {
        switch self {
        case .logout: return "Se déconnecter"
        case .deleteAccount: return "Supprimer le compte"
        }
    }
}

enum ProfileEditTheme {
    static let background = ProcessColors.background
    static let chipBackground = ProcessColors.secondaryBackground
    static let chipSelected = Color(.tertiarySystemBackground)
    static let headerButton = ProcessColors.secondaryBackground
    static let savePill = Color.primary.opacity(0.1)
    static let textSecondary = ProcessColors.textSecondary
    static let placeholder = Color(.placeholderText)
    static let separator = ProcessColors.border

    static let spring = Animation.spring(response: 0.34, dampingFraction: 0.86)
}

struct ProfileEditorHeader: View {
    let title: String
    var showsSave: Bool = false
    var saveDisabled: Bool = false
    let onDismiss: () -> Void
    var onSave: (() -> Void)?

    var body: some View {
        ZStack {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.primary)

            HStack {
                ProcessGlassIconButton(systemName: "chevron.left", size: 40, iconSize: 16, action: onDismiss)

                Spacer()

                if showsSave, let onSave {
                    Button(action: onSave) {
                        Text("Enregistrer")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(saveDisabled ? Color(.tertiaryLabel) : Color.primary)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .processGlassEffect(in: Capsule())
                    .buttonStyle(ProcessGlassPressStyle())
                    .disabled(saveDisabled)
                    .opacity(saveDisabled ? 0.72 : 1)
                } else {
                    Color.clear.frame(width: 40, height: 40)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 12)
    }
}

struct ProfileEditorHero: View {
    let headline: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 14) {
            Text(headline)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.primary)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.system(size: 15))
                .foregroundStyle(ProfileEditTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 28)
    }
}

struct ProfileEditorBottomSaveButton: View {
    let title: String
    var disabled: Bool = false
    let action: () -> Void

    private let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(disabled ? Color(.tertiaryLabel) : Color.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
        }
        .buttonStyle(.plain)
        .processGlassEffect(in: shape)
        .buttonStyle(ProcessGlassPressStyle())
        .disabled(disabled)
        .opacity(disabled ? 0.72 : 1)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(ProfileEditTheme.background)
    }
}

struct ProfileInterestChip: View {
    let interest: ProfileInterest
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(interest.label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isSelected ? ProfileEditTheme.chipSelected : ProfileEditTheme.chipBackground)
                .clipShape(Capsule())
                .overlay {
                    if isSelected {
                        Capsule()
                            .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
        .animation(ProfileEditTheme.spring, value: isSelected)
    }
}

struct ProfileInterestFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

struct ProfileEditListRow: View {
    let label: String
    let value: String?
    let placeholder: String
    var showsAccentDot: Bool = false
    var showsChevron: Bool = true
    var valueIsMuted: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                if showsAccentDot {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 7, height: 7)
                }
                Text(label)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.primary)
            }

            Spacer(minLength: 8)

            Text(value?.isEmpty == false ? value! : placeholder)
                .font(.system(size: 16))
                .foregroundStyle(valueForeground)
                .lineLimit(2)
                .multilineTextAlignment(.trailing)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ProfileEditTheme.textSecondary.opacity(0.55))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
    }

    private var valueForeground: Color {
        guard value?.isEmpty == false else { return ProfileEditTheme.placeholder }
        if valueIsMuted { return ProfileEditTheme.textSecondary.opacity(0.85) }
        return Color.primary
    }
}

// MARK: - Account details (Détails du compte)

enum AccountDetailsTheme {
    static let pageBackground = ProfileTheme.background
    static let linkText = ProfileTheme.textSecondary
    static let rowCornerRadius: CGFloat = 16
    static let actionCornerRadius: CGFloat = 14
    static let rowSpacing: CGFloat = 10
    static let horizontalPadding: CGFloat = 16
}

struct AccountDetailsGlassReliefModifier: ViewModifier {
    var cornerRadius: CGFloat = AccountDetailsTheme.rowCornerRadius
    var destructiveTint: Bool = false

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .processGlassEffect(in: shape, interactive: false)
            .overlay {
                if destructiveTint {
                    shape.fill(Color.red.opacity(0.07))
                }
            }
    }
}

extension View {
    func accountDetailsGlassRelief(
        cornerRadius: CGFloat = AccountDetailsTheme.rowCornerRadius,
        destructiveTint: Bool = false
    ) -> some View {
        modifier(AccountDetailsGlassReliefModifier(cornerRadius: cornerRadius, destructiveTint: destructiveTint))
    }
}

struct AccountDetailsGlassHeader: View {
    let onBack: () -> Void
    let onSave: () -> Void
    var saveDisabled: Bool = true

    var body: some View {
        HStack {
            ProcessGlassIconButton(systemName: "chevron.down", size: 40, iconSize: 16, action: onBack)

            Spacer()

            Button(action: onSave) {
                Text("Enregistrer")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(saveDisabled ? Color(.tertiaryLabel) : Color.primary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .processGlassEffect(in: Capsule())
            .buttonStyle(ProcessGlassPressStyle())
            .disabled(saveDisabled)
            .opacity(saveDisabled ? 0.72 : 1)
        }
        .padding(.horizontal, AccountDetailsTheme.horizontalPadding)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
}

struct AccountDetailsAvatarSection: View {
    let fullName: String
    let initials: String
    let image: UIImage?
    let onChangePhoto: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Circle().fill(ProfileTheme.avatarAccent)
                        Text(initials.prefix(1).uppercased())
                            .font(.system(size: 52, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .frame(width: 110, height: 110)
            .clipShape(Circle())

            Text(fullName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.primary)
                .multilineTextAlignment(.center)

            Button(action: onChangePhoto) {
                Text("Modifier la photo")
                    .font(.system(size: 15))
                    .foregroundStyle(AccountDetailsTheme.linkText)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 22)
    }
}

struct AccountDetailsCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: AccountDetailsTheme.rowSpacing) {
            content
        }
    }
}

struct AccountDetailsGlassRow<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .accountDetailsGlassRelief()
    }
}

struct AccountDetailsDivider: View {
    var body: some View {
        EmptyView()
    }
}

struct AccountDetailsActionButton: View {
    let title: String
    var destructive: Bool = false
    let action: () -> Void

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: AccountDetailsTheme.actionCornerRadius, style: .continuous)
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(destructive ? Color.red : Color.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background {
                    shape
                        .fill(.clear)
                        .processGlassEffect(in: shape, interactive: false)
                        .overlay {
                            if destructive {
                                shape.fill(Color.red.opacity(0.07))
                            }
                        }
                }
                .contentShape(shape)
        }
        .buttonStyle(ProcessGlassPressStyle())
    }
}

struct AccountDeleteAnimatedButton: View {
    let onConfirm: () -> Void

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: AccountDetailsTheme.actionCornerRadius, style: .continuous)
    }

    var body: some View {
        AnimatedDeleteButton(
            cornerRadius: .init(
                source: AccountDetailsTheme.actionCornerRadius,
                destination: 28
            ),
            customAction: CustomDeleteAction(
                confirmTitle: "Supprimer le compte",
                cancelTitle: "Annuler",
                background: .red,
                foreground: .white
            )
        ) {
            VStack(alignment: .leading, spacing: 15) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Supprimer le compte ?")
                    .font(.title2.bold())
                    .foregroundStyle(Color.primary)

                Text("Cette action est définitive. Toutes tes données seront effacées et tu reviendras au début de Process.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, 10)
        } label: {
            Text("Supprimer le compte")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.red)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background {
                    shape
                        .fill(.clear)
                        .processGlassEffect(in: shape, interactive: false)
                        .overlay {
                            shape.fill(Color.red.opacity(0.07))
                        }
                }
                .contentShape(shape)
        } action: { confirmed in
            if confirmed {
                onConfirm()
            }
        }
    }
}

struct ProfileSummarySectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(ProfileEditTheme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 22)
            .padding(.bottom, 6)
    }
}

struct ProfileSummaryInfoRow: View {
    let item: ProfileSummaryItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(item.label)
                .font(.system(size: 16))
                .foregroundStyle(Color.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(item.displayValue)
                .font(.system(size: 16))
                .foregroundStyle(item.isPlaceholder ? ProfileEditTheme.placeholder : ProfileEditTheme.textSecondary)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
}

struct ProfileEditAvatarButton: View {
    let initials: String
    let image: UIImage?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Circle().fill(ProfileTheme.avatarAccent)
                        Text(initials.prefix(1).uppercased())
                            .font(.system(size: 58, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .frame(width: 118, height: 118)
            .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 28)
    }
}
