//
//  TransformationPreviewStepView.swift
//  Process
//
//  Aperçu avant / après juste avant le paywall.
//

import SwiftUI

struct TransformationPreviewStepView: View {
    let onComplete: () -> Void
    let onBack: (() -> Void)?

    init(onComplete: @escaping () -> Void, onBack: (() -> Void)? = nil) {
        self.onComplete = onComplete
        self.onBack = onBack
    }

    var body: some View {
        ZStack {
            OnboardingTheme.screenBackground
                .ignoresSafeArea(.all)

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: OnboardingConstants.backOnlyContentTopInset)

                (Text("Visualise ta ") + Text("transformation").foregroundColor(OnboardingTheme.accentHighlight))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(OnboardingTheme.primaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 12)

                Text("Glisse pour comparer avant et après")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(OnboardingTheme.bodyText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 28)

                BeforeAfterComparisonSlider(
                    beforeImageName: "leo",
                    afterImageName: "leoprime"
                )
                .aspectRatio(3 / 4, contentMode: .fit)
                .padding(.horizontal, 24)

                Spacer()

                Button {
                    HapticManager.shared.impact(.medium)
                    onComplete()
                } label: {
                    Text("Continuer")
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(OnboardingTheme.primaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .glassStyle()
                .buttonBorderShape(.roundedRectangle(radius: 50))
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            }
        }
    }
}
