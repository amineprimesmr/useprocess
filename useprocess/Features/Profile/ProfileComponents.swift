import SwiftUI
import UIKit

// MARK: - Stretchy hero (pull-down overscroll — scroll normal inchangé)

/// Ancre le hero en haut et ne grandit que quand l’utilisateur tire la page vers le bas.
struct ProfileStretchyHeroFrame<Content: View>: View {
    let baseHeight: CGFloat
    @ViewBuilder let content: (_ totalHeight: CGFloat, _ stretch: CGFloat) -> Content

    var body: some View {
        GeometryReader { geo in
            let minY = geo.frame(in: .named("profileScroll")).minY
            let stretch = max(0, minY)
            let totalHeight = baseHeight + stretch

            content(totalHeight, stretch)
                .frame(width: geo.size.width, height: totalHeight, alignment: .top)
                .offset(y: stretch > 0 ? -stretch : 0)
        }
        .frame(height: baseHeight)
    }
}

// MARK: - Empty hero (gradient + placeholder)

struct ProfileEmptyHeroSection: View {
    var onPhotoTap: (CGPoint) -> Void

    var body: some View {
        ProfileStretchyHeroFrame(baseHeight: ProfileTheme.heroCoverHeight) { totalHeight, _ in
            ZStack {
                ProfileEmptyHeroBackground()
                    .frame(height: totalHeight)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .clipped()

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
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .gesture(photoTapGesture)
            }
            .frame(height: totalHeight)
            .clipShape(ProfileTheme.heroBottomShape)
        }
    }

    private var photoTapGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onEnded { value in
                HapticManager.shared.impact(.light)
                onPhotoTap(value.location)
            }
    }
}

// MARK: - Cover hero (with photo)

struct ProfileCoverPhotoSection: View {
    let image: UIImage
    let displayName: String
    let username: String
    let isPrivate: Bool
    var onPhotoTap: ((CGPoint) -> Void)? = nil
    var onEditUsername: (() -> Void)? = nil

    var body: some View {
        ProfileStretchyHeroFrame(baseHeight: ProfileTheme.heroCoverHeight) { totalHeight, _ in
            ZStack(alignment: .bottom) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: totalHeight, alignment: .top)
                    .clipped()
                    .overlay {
                        LinearGradient(
                            colors: [.clear, .clear, .black.opacity(0.25), .black.opacity(0.68)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .allowsHitTesting(false)
                    }

                if let onPhotoTap {
                    VStack(spacing: 0) {
                        Color.clear
                            .frame(height: max(totalHeight * 0.58, 120))
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                                    .onEnded { value in
                                        HapticManager.shared.impact(.light)
                                        onPhotoTap(value.location)
                                    }
                            )
                        Spacer(minLength: 0)
                    }
                    .frame(height: totalHeight)
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
            .frame(height: totalHeight)
            .clipShape(ProfileTheme.heroBottomShape)
            .contentShape(ProfileTheme.heroBottomShape)
        }
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
    var onReferral: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            ProfileReferralInteractiveCard()

            ProcessGlassWideButton(title: "Voir les avantages", icon: "gift.fill", action: onReferral)
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
