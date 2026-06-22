import SwiftUI
import UIKit

// MARK: - Empty hero (gradient + placeholder)

struct ProfileEmptyHeroSection: View {
    var onAddPhoto: () -> Void

    private var totalHeight: CGFloat { ProfileTheme.emptyHeroHeight + ProfileTheme.heroMenuBleedInset }

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
            .padding(.top, ProfileTheme.heroMenuBleedInset + ProfileTheme.emptyHeroTopClearance * 0.35)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(height: totalHeight)
        .frame(maxWidth: .infinity)
        .clipShape(ProfileTheme.heroBottomShape)
        .padding(.top, -ProfileTheme.heroMenuBleedInset)
    }
}

// MARK: - Cover hero (with photo)

struct ProfileCoverPhotoSection: View {
    let image: UIImage
    let displayName: String
    let isPrivate: Bool

    private var totalHeight: CGFloat { ProfileTheme.heroHeight + ProfileTheme.heroMenuBleedInset }

    var body: some View {
        ZStack(alignment: .bottom) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: totalHeight)
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
                isPrivate: isPrivate,
                style: .overlay
            )
            .padding(.horizontal, ProfileTheme.horizontalPadding)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .frame(height: totalHeight)
        .clipShape(ProfileTheme.heroBottomShape)
        .contentShape(ProfileTheme.heroBottomShape)
        .padding(.top, -ProfileTheme.heroMenuBleedInset)
    }
}

enum ProfileIdentityStyle {
    case inline, overlay
}

struct ProfileIdentityBlock: View {
    let displayName: String
    let isPrivate: Bool
    var style: ProfileIdentityStyle = .inline

    var body: some View {
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
        .shadow(
            color: style == .overlay ? .black.opacity(0.35) : .clear,
            radius: 6,
            y: 2
        )
        .frame(maxWidth: .infinity, alignment: .leading)
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

