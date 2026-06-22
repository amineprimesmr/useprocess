import SwiftUI

// MARK: - Press

/// Sur iOS 26, le glass `.interactive()` gère déjà scale + shimmer — ne pas écraser avec un scale manuel.
struct ProcessGlassPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        if #available(iOS 26.0, *) {
            configuration.label
        } else {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(.spring(response: 0.22, dampingFraction: 0.9), value: configuration.isPressed)
        }
    }
}

// MARK: - Icon button (barre profil)

struct ProcessGlassIconButton: View {
    let systemName: String
    var size: CGFloat = 40
    var iconSize: CGFloat = 17
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(Color.primary)
                .frame(width: size, height: size)
        }
        .processGlassIconButtonStyle()
    }
}

// MARK: - Profile wide button

struct ProcessGlassWideButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(Color.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
        }
        .processGlassButton(
            in: RoundedRectangle(cornerRadius: ProfileTheme.buttonCornerRadius, style: .continuous)
        )
    }
}

enum ProcessGlass {
    static let capsuleRadius: CGFloat = 14
    static let iconSize: CGFloat = 40
    static let spring = Animation.spring(response: 0.32, dampingFraction: 0.86)
    static let pressSpring = Animation.spring(response: 0.28, dampingFraction: 0.9)

    @available(iOS 26.0, *)
    static var regular: Glass { .regular.interactive() }

    /// Fond glass passif (barre de saisie, popovers).
    @available(iOS 26.0, *)
    static var regularSurface: Glass { .regular }

    @available(iOS 26.0, *)
    static var primary: Glass { .regular.tint(Color.processPrimary.opacity(0.9)).interactive() }

    @available(iOS 26.0, *)
    static func filterSelected(_ fill: Color) -> Glass {
        .regular.tint(fill).interactive()
    }

    @available(iOS 26.0, *)
    static var primarySoft: Glass { .regular.tint(Color.processPrimary.opacity(0.55)).interactive() }

    @available(iOS 26.0, *)
    static var dark: Glass { .regular.tint(Color.black.opacity(0.38)).interactive() }

    @available(iOS 26.0, *)
    static func tinted(_ color: Color, opacity: CGFloat = 0.38) -> Glass {
        .regular.tint(color.opacity(opacity)).interactive()
    }
}
