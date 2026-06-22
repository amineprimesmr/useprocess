//
//  BeforeAfterComparisonSlider.swift
//  Process
//
//  Comparaison avant / après avec curseur glissable au doigt.
//

import SwiftUI

struct BeforeAfterComparisonSlider: View {
    let beforeImageName: String
    let afterImageName: String

    @State private var sliderPosition: CGFloat = 0.5
    @State private var didTriggerDragHaptic = false

    private let handleSize: CGFloat = 44
    private let dividerWidth: CGFloat = 3

    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width, 1)
            let height = geometry.size.height
            let dividerX = width * sliderPosition

            ZStack(alignment: .leading) {
                Image(afterImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipped()
                    .accessibilityLabel("Après")

                Image(beforeImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipped()
                    .mask(alignment: .leading) {
                        Rectangle()
                            .frame(width: dividerX, height: height)
                    }
                    .accessibilityLabel("Avant")

                Rectangle()
                    .fill(.white)
                    .frame(width: dividerWidth, height: height)
                    .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 0)
                    .position(x: dividerX, y: height / 2)

                sliderHandle
                    .position(x: dividerX, y: height / 2)

                VStack {
                    HStack {
                        comparisonBadge("Avant")
                        Spacer(minLength: 0)
                        comparisonBadge("Après")
                    }
                    .padding(14)
                    Spacer(minLength: 0)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !didTriggerDragHaptic {
                            didTriggerDragHaptic = true
                            HapticManager.shared.impact(.light)
                        }
                        let normalized = value.location.x / width
                        sliderPosition = min(max(normalized, 0.04), 0.96)
                    }
                    .onEnded { _ in
                        didTriggerDragHaptic = false
                    }
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private var sliderHandle: some View {
        ZStack {
            Circle()
                .fill(.white)
                .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 2)

            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                Image(systemName: "chevron.right")
            }
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Color.primary.opacity(0.65))
        }
        .frame(width: handleSize, height: handleSize)
        .accessibilityLabel("Curseur avant après")
        .accessibilityAddTraits(.allowsDirectInteraction)
    }

    private func comparisonBadge(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.black.opacity(0.45), in: Capsule())
    }
}
