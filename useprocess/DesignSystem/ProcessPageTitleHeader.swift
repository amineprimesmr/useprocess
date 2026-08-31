import SwiftUI

/// Titre de page — même taille, police et position que la salutation d'accueil
/// (« Salut {prénom} », voir `PlanHomeGreetingLabel`), avec une légère animation
/// d'entrée (fondu + glissement) à l'apparition de la page.
struct ProcessPageTitleHeader: View {
    let title: String

    @Environment(\.appTheme) private var theme
    @State private var hasAppeared = false

    var body: some View {
        Text(title)
            .font(.system(size: 28, weight: .bold))
            .foregroundStyle(theme.primaryText)
            .multilineTextAlignment(.leading)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
            .padding(.bottom, 2)
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 8)
            .onAppear {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                    hasAppeared = true
                }
            }
    }
}
