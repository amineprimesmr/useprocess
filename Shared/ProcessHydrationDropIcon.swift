import SwiftUI
import UIKit

/// Icône goutte hydratation — asset recadré transparent + fallback bundle Media.
enum ProcessHydrationDropIcon {
    static let colorAsset = "hydration_drop"
    static let accent = Color(red: 0.45, green: 0.86, blue: 1.0)

    private static let cachedColorImage: UIImage? = loadColorImage()

    /// Pleine couleur — expanded, lock screen, compact DI, in-app.
    @ViewBuilder
    static func image(side: CGFloat) -> some View {
        if let uiImage = cachedColorImage {
            Image(uiImage: uiImage)
                .renderingMode(.original)
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .scaledToFit()
                .frame(width: side, height: side)
        } else {
            symbolFallback(side: side)
        }
    }

    /// Alias compact — même bitmap couleur (fond transparent, visible sur DI sombre).
    static func compactImage(side: CGFloat) -> some View {
        image(side: side)
    }

    @ViewBuilder
    private static func symbolFallback(side: CGFloat) -> some View {
        Image(systemName: "drop.fill")
            .symbolRenderingMode(.palette)
            .foregroundStyle(accent, Color(red: 0.12, green: 0.55, blue: 0.88))
            .font(.system(size: side * 0.72, weight: .semibold))
            .frame(width: side, height: side)
    }

    private static func loadColorImage() -> UIImage? {
        let bundle = Bundle.main

        if let asset = UIImage(named: colorAsset, in: bundle, compatibleWith: nil) {
            return asset
        }

        let resourceCandidates: [(String, String, String?)] = [
            ("hydration_drop", "png", "Media"),
            ("hydration_drop", "png", nil),
        ]

        for (name, ext, subdirectory) in resourceCandidates {
            if let url = bundle.url(forResource: name, withExtension: ext, subdirectory: subdirectory),
               let data = try? Data(contentsOf: url),
               let image = UIImage(data: data, scale: 3) {
                return image
            }
        }

        return nil
    }
}
