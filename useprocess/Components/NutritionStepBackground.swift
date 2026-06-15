import SwiftUI

/// Fond des étapes nutrition — aligné sur le reste de l'onboarding en mode clair.
struct NutritionStepBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if colorScheme == .dark {
                LinearGradient(
                    colors: [Color.black, Color(red: 0.08, green: 0.1, blue: 0.14)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                OnboardingTheme.screenBackground
            }
        }
        .ignoresSafeArea()
    }
}
