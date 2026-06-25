import SwiftUI
import UIKit

// MARK: - Empty hero (gradient + placeholder)

struct ProfileEmptyHeroSection: View {
    var onAddPhoto: () -> Void
    var onOpenSettings: (() -> Void)? = nil

    var body: some View {
        ZStack {
            ProfileEmptyHeroBackground()

            Button(action: onAddPhoto) {
                VStack(spacing: 10) {
                    Image(systemName: "person.crop.rectangle.badge.plus")
                        .font(.system(size: ProfileTheme.emptyHeroIconSize, weight: .regular))
                        .foregroundStyle(ProfileTheme.textSecondary.opacity(0.85))

                    Text("Clique ici pour ajouter une photo de profil")
                        .font(.system(size: 14))
                        .foregroundStyle(ProfileTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, ProfileTheme.heroTopInset + 48)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity)
        .frame(height: ProfileTheme.heroCoverHeight)
        .clipShape(ProfileTheme.heroBottomShape)
        .overlay(alignment: .topTrailing) {
            if let onOpenSettings {
                ProfileHeroSettingsButton(style: .plain, action: onOpenSettings)
                    .padding(.top, ProfileTheme.heroTopInset + 10)
                    .padding(.trailing, 14)
            }
        }
    }
}

// MARK: - Cover hero (with photo)

struct ProfileCoverPhotoSection: View {
    let image: UIImage
    let displayName: String
    let username: String
    let isPrivate: Bool
    var onChangePhoto: (() -> Void)? = nil
    var onOpenSettings: (() -> Void)? = nil
    var onEditUsername: (() -> Void)? = nil

    var body: some View {
        ZStack(alignment: .bottom) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .overlay {
                    LinearGradient(
                        colors: [.clear, .clear, .black.opacity(0.25), .black.opacity(0.68)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .allowsHitTesting(false)
                }

            ProfileIdentityBlock(
                displayName: displayName,
                username: username,
                isPrivate: isPrivate,
                style: .overlay,
                onEditUsername: onEditUsername
            )
            .padding(.horizontal, ProfileTheme.horizontalPadding)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .frame(height: ProfileTheme.heroCoverHeight)
        .clipShape(ProfileTheme.heroBottomShape)
        .contentShape(ProfileTheme.heroBottomShape)
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 8) {
                if let onChangePhoto {
                    ProfileHeroIconButton(systemName: "camera.fill", action: onChangePhoto)
                }
                if let onOpenSettings {
                    ProfileHeroSettingsButton(style: .overlay, action: onOpenSettings)
                }
            }
            .padding(.top, ProfileTheme.heroTopInset + 10)
            .padding(.trailing, 14)
        }
    }
}

private struct ProfileHeroSettingsButton: View {
    enum Style {
        case overlay
        case plain
    }

    let style: Style
    let action: () -> Void

    var body: some View {
        switch style {
        case .overlay:
            ProfileHeroIconButton(systemName: "gearshape.fill", action: action)
                .accessibilityLabel("Paramètres")
        case .plain:
            Button(action: action) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ProfileTheme.textPrimary)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .processGlassCircle(interactive: true)
            .accessibilityLabel("Paramètres")
        }
    }
}

private struct ProfileHeroIconButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(.black.opacity(0.35), in: Circle())
        }
        .buttonStyle(.plain)
    }
}

enum ProfileIdentityStyle {
    case inline, overlay
}

struct ProfileIdentityBlock: View {
    let displayName: String
    let username: String
    let isPrivate: Bool
    var style: ProfileIdentityStyle = .inline
    var onEditUsername: (() -> Void)? = nil

    private var normalizedTag: String {
        ProcessUsernameTag.normalize(username)
    }

    private var formattedTag: String {
        normalizedTag.isEmpty ? "" : "@\(normalizedTag)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Text(displayName)
                    .font(.system(size: style == .overlay ? 30 : 26, weight: .bold))
                    .foregroundStyle(style == .overlay ? .white : ProfileTheme.textPrimary)

                if isPrivate {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(style == .overlay ? .white.opacity(0.9) : ProfileTheme.textSecondary)
                }
            }

            tagRow
        }
        .shadow(
            color: style == .overlay ? .black.opacity(0.35) : .clear,
            radius: 6,
            y: 2
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var tagRow: some View {
        if normalizedTag.isEmpty {
            if let onEditUsername {
                Button(action: onEditUsername) {
                    Text("Ajouter ton @")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(style == .overlay ? .white.opacity(0.82) : ProfileTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        } else {
            Button {
                UIPasteboard.general.string = formattedTag
                HapticManager.shared.notification(.success)
            } label: {
                Text(formattedTag)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(style == .overlay ? .white.opacity(0.88) : ProfileTheme.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Tag \(formattedTag), copier")
        }
    }
}

struct ProfileActionButtons: View {
    var onShare: () -> Void
    var onEdit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            ProcessGlassWideButton(title: "Partager mon Profil", action: onShare)

            Button(action: onEdit) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .frame(width: 48, height: 48)
            }
            .processGlassButton(
                in: RoundedRectangle(cornerRadius: ProfileTheme.buttonCornerRadius, style: .continuous)
            )
        }
    }
}

// MARK: - Sheets

struct ProfileShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
