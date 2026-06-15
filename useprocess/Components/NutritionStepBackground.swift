import SwiftUI

/// Fond des étapes nutrition — sans asset `nutri` requis.
struct NutritionStepBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Color.black, Color(red: 0.08, green: 0.1, blue: 0.14)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}
