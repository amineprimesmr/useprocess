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
    private let dateChipCornerRadius: CGFloat = 12

    private var dateChipShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: dateChipCornerRadius, style: .continuous)
    }

    var body: some View {
        GeometryReader { geometry in
            let bottomReserve = continueButtonReserve + geometry.safeAreaInsets.bottom
            let graphHeight = min(280, geometry.size.height * 0.34)

            VStack(spacing: 20) {
                VStack(spacing: 18) {
                    Text(OnboardingCopy.t("D'après nos estimations", en: "Based on our estimates"))
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(OnboardingTheme.bodyText)
                        .frame(maxWidth: .infinity)

                    Text(titleMessage)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(OnboardingTheme.primaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 8)

                    HStack(spacing: 12) {
                        dateChip {
                            Text(displayDay)
                                .font(.system(size: 32, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(OnboardingTheme.primaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.55)
                                .fixedSize(horizontal: true, vertical: false)
                                .padding(.horizontal, 16)
                                .frame(minWidth: 64, minHeight: 46)
                        }
                        .layoutPriority(2)

                        dateChip {
                            Text(displayMonth)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(OnboardingTheme.primaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.55)
                                .padding(.horizontal, 16)
                                .frame(maxWidth: .infinity, minHeight: 46)
                        }
                    }
                    .opacity(displayDay.isEmpty && displayMonth.isEmpty ? 0 : 1)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(displayDay) \(displayMonth)")
                }
                .padding(.horizontal, 40)
                .padding(.top, OnboardingConstants.backOnlyContentTopInset)

                Spacer()
                    .frame(height: 16)

                graph()
                    .frame(height: graphHeight)
                    .clipped()

                Spacer(minLength: 0)

                bottom()
                    .padding(.horizontal, 40)
                    .padding(.bottom, 4)
            }
            .padding(.bottom, bottomReserve)
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }
    }

    private func dateChip<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .processGlassEffect(in: dateChipShape, interactive: false)
    }
}
