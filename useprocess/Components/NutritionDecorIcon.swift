import SwiftUI

/// Icône décorative nutrition — asset optionnel avec repli SF Symbol.
struct NutritionDecorIcon: View {
    let name: String
    let systemName: String
    let size: CGFloat

    var body: some View {
        OptionalAssetImage(
            name: name,
            systemName: systemName,
            width: size,
            height: size,
            maxWidth: size
        )
    }
}
