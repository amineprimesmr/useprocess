//
//  EstimationStepLayout.swift
//  Process
//
//  Mise en page partagée des écrans « D'après nos estimations ».
//

import SwiftUI

struct EstimationStepLayout<Graph: View, Bottom: View>: View {
    let titleMessage: String
    let displayDay: String
    let displayMonth: String
    @ViewBuilder let graph: () -> Graph
    @ViewBuilder let bottom: () -> Bottom

    private let continueButtonReserve: CGFloat = 148

    var body: some View {
        GeometryReader { geometry in
            let bottomReserve = continueButtonReserve + geometry.safeAreaInsets.bottom
            let graphHeight = min(200, geometry.size.height * 0.24)

            VStack(spacing: 20) {
                VStack(spacing: 18) {
                    Text("D'après nos estimations")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(OnboardingTheme.bodyText)
                        .frame(maxWidth: .infinity)

                    Text(titleMessage)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(OnboardingTheme.primaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 8)

                    HStack(spacing: 10) {
                        Button(action: {}) {
                            Text(displayDay)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(OnboardingTheme.primaryText)
                                .frame(width: 50, height: 28)
                        }
                        .glassStyle()
                        .controlSize(.large)

                        Button(action: {}) {
                            Text(displayMonth)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(OnboardingTheme.primaryText)
                                .frame(height: 28)
                        }
                        .glassStyle()
                        .controlSize(.large)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, OnboardingConstants.titleTopPaddingFromScreenTop)

                Spacer()
                    .frame(height: 16)

                graph()
                    .frame(height: graphHeight)

                bottom()

                Spacer(minLength: 0)
            }
            .padding(.bottom, bottomReserve)
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }
    }
}
