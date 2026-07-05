//
//  TransformationCaseStudyCard.swift
//  Process
//
//  Carte case study avec slider avant/après et infos membre en overlay.
//

import SwiftUI

struct TransformationCaseStudyCard: View {
    let study: TransformationCaseStudy
    var playsIntroHint: Bool = false

    private let bottomTreatmentHeight: CGFloat = 148

    var body: some View {
        ZStack(alignment: .bottom) {
            BeforeAfterComparisonSlider(
                beforeImageName: study.beforeImageName,
                afterImageName: study.afterImageName,
                durationWeeks: study.durationWeeks,
                playsIntroHint: playsIntroHint
            )

            bottomTreatment
        }
        .aspectRatio(3 / 4, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.14), radius: 18, y: 10)
    }

    private var bottomTreatment: some View {
        ZStack(alignment: .bottomLeading) {
            VariableBlurView(
                maxBlurRadius: 14,
                direction: .blurredBottomClearTop,
                startOffset: 0.22
            )
            .frame(height: bottomTreatmentHeight)
            .frame(maxWidth: .infinity, alignment: .bottom)
            .allowsHitTesting(false)

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black.opacity(0.12), location: 0.4),
                    .init(color: .black.opacity(0.48), location: 0.75),
                    .init(color: .black.opacity(0.72), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: bottomTreatmentHeight)
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 12) {
                Text(study.name)
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 8, y: 2)

                HStack(spacing: 8) {
                    metadataChip(study.memberSince)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 22)
        }
        .frame(maxWidth: .infinity, alignment: .bottom)
        .allowsHitTesting(false)
    }

    private func metadataChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .foregroundStyle(.white)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background {
                Capsule(style: .continuous)
                    .fill(.white.opacity(0.16))
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(.white.opacity(0.22), lineWidth: 0.5)
                    }
            }
    }
}
