import SwiftUI
import UIKit

// MARK: - Stretchy hero (pull-down overscroll — scroll normal inchangé)

/// Ancre le hero en haut et ne grandit que quand l’utilisateur tire la page vers le bas.
struct ProfileStretchyHeroFrame<Content: View>: View {
    let baseHeight: CGFloat
    @ViewBuilder let content: (_ totalHeight: CGFloat, _ stretch: CGFloat) -> Content

    var body: some View {
        GeometryReader { geo in
            let minY = geo.frame(in: .named("processMainScroll")).minY
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

                    Text(AppCopy.t("Clique ici pour ajouter une photo de profil", en: "Tap here to add a profile photo"))
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

private struct ProfileHeroBottomLightGlow: View {
    var height: CGFloat

    var body: some View {
        ZStack(alignment: .bottom) {
            RadialGradient(
                colors: [
                    Color.white.opacity(0.10),
                    Color.white.opacity(0.04),
                    .clear
                ],
                center: UnitPoint(x: 0.5, y: 1.05),
                startRadius: 0,
                endRadius: height * 1.15
            )

            LinearGradient(
                colors: [.clear, Color.white.opacity(0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: height * 0.5)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .allowsHitTesting(false)
    }
}

struct ProfileCoverPhotoSection: View {
    let image: UIImage
    let displayName: String
    let isPrivate: Bool
    var onPhotoTap: ((CGPoint) -> Void)? = nil

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
                        ZStack(alignment: .bottom) {
                            LinearGradient(
                                colors: [.clear, .clear, .black.opacity(0.25), .black.opacity(0.68)],
                                startPoint: .top,
                                endPoint: .bottom
                            )

                            ProfileHeroBottomLightGlow(height: min(totalHeight * 0.26, 96))
                        }
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
                    isPrivate: isPrivate,
                    style: .overlay
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
    var onReferral: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            ProfileReferralInteractiveCard()

            ProcessGlassWideButton(title: AppCopy.t("Voir les avantages", en: "View Benefits"), icon: "gift.fill", action: onReferral)
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
