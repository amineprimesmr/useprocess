//
//  OnboardingStandardStepLayout.swift
//  Process
//
//  Gabarit unique pour toutes les pages questions (aligné sur âge / taille / poids).
//

import SwiftUI

/// Conteneur standard : titre en overlay fixe + zone contenu décalée de façon identique.
struct OnboardingStandardStepLayout<Content: View>: View {
    private let titleView: OnboardingTitleView?
    @ViewBuilder private let content: () -> Content

    /// Page avec titre sur une ligne.
    init(
        title: String,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.titleView = OnboardingTitleView(title)
        self.content = content
    }

    /// Page avec titre sur deux lignes.
    init(
        _ line1: String,
        _ line2: String,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.titleView = OnboardingTitleView(line1, line2)
        self.content = content
    }

    /// Page narrative sans titre (même décalage vertical que les pages avec titre).
    init(@ViewBuilder content: @escaping () -> Content) {
        self.titleView = nil
        self.content = content
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: OnboardingConstants.titleAreaHeight)

                Spacer()
                    .frame(height: OnboardingConstants.titleToContentSpacing)

                content()
            }

            if let titleView {
                titleView
                    .onboardingTitleOverlay()
            }
        }
    }
}
