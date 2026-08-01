//
//  BeforeAfterComparisonSlider.swift
//  Process
//
//  Comparaison avant / après avec curseur glissable au doigt.
//

import SwiftUI

struct BeforeAfterComparisonSlider: View {
    let beforeImageName: String?
    let afterImageName: String?
    let beforeVideoName: String?
    let afterVideoName: String?
    var durationWeeks: Int = 8
    var playsIntroHint: Bool = false

    init(
        beforeImageName: String? = nil,
        afterImageName: String? = nil,
        beforeVideoName: String? = nil,
        afterVideoName: String? = nil,
        durationWeeks: Int = 8,
        playsIntroHint: Bool = false
    ) {
        self.beforeImageName = beforeImageName
        self.afterImageName = afterImageName
        self.beforeVideoName = beforeVideoName
        self.afterVideoName = afterVideoName
        self.durationWeeks = durationWeeks
        self.playsIntroHint = playsIntroHint
    }

    @State private var sliderPosition: CGFloat = 0.74
    @State private var didTriggerDragHaptic = false
    @State private var hasPlayedIntroHint = false
    @State private var isUserDragging = false
    @State private var introHintTask: Task<Void, Never>?

    private let handleSize: CGFloat = 44
    private let dividerWidth: CGFloat = 3
    private let defaultSliderPosition: CGFloat = 0.74

    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width, 1)
            let height = geometry.size.height
            let dividerX = width * sliderPosition

            ZStack(alignment: .leading) {
                comparisonLayer(
                    imageName: afterImageName,
                    videoName: afterVideoName,
                    width: width,
                    height: height,
                    accessibilityLabel: "Après"
                )

                comparisonLayer(
                    imageName: beforeImageName,
                    videoName: beforeVideoName,
                    width: width,
                    height: height,
                    accessibilityLabel: "Avant"
                )
                .mask(alignment: .leading) {
                    Rectangle()
                        .frame(width: dividerX, height: height)
                }

                Rectangle()
                    .fill(.white)
                    .frame(width: dividerWidth, height: height)
                    .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 0)
                    .position(x: dividerX, y: height / 2)

                sliderHandle
                    .position(x: dividerX, y: height / 2)
                    .gesture(sliderDragGesture(width: width))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .onAppear {
            scheduleIntroHintIfNeeded()
        }
        .onDisappear {
            introHintTask?.cancel()
            introHintTask = nil
        }
    }

    @ViewBuilder
    private func comparisonLayer(
        imageName: String?,
        videoName: String?,
        width: CGFloat,
        height: CGFloat,
        accessibilityLabel: String
    ) -> some View {
        if let videoName, let url = TransformationBundledVideo.url(for: videoName) {
            FaceScanSilentVideoLoopView(url: url)
                .frame(width: width, height: height)
                .clipped()
                .accessibilityLabel(accessibilityLabel)
        } else if let imageName {
            Image(imageName)
                .resizable()
                .scaledToFill()
                .frame(width: width, height: height)
                .clipped()
                .accessibilityLabel(accessibilityLabel)
        } else {
            Color.black.opacity(0.12)
                .frame(width: width, height: height)
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
        .contentShape(Circle())
        .accessibilityLabel("Curseur avant après")
        .accessibilityAddTraits(.allowsDirectInteraction)
    }

    private func sliderDragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                cancelIntroHint()
                isUserDragging = true
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                if !didTriggerDragHaptic {
                    didTriggerDragHaptic = true
                    HapticManager.shared.impact(.light)
                }
                let normalized = value.location.x / width
                sliderPosition = min(max(normalized, 0.04), 0.96)
            }
            .onEnded { _ in
                didTriggerDragHaptic = false
                isUserDragging = false
            }
    }

    private func scheduleIntroHintIfNeeded() {
        guard playsIntroHint, !hasPlayedIntroHint else { return }

        introHintTask?.cancel()
        introHintTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled, !isUserDragging, !hasPlayedIntroHint else { return }

            withAnimation(.easeInOut(duration: 0.85)) {
                sliderPosition = 0.55
            }

            try? await Task.sleep(for: .milliseconds(950))
            guard !Task.isCancelled, !isUserDragging else { return }

            withAnimation(.spring(response: 0.62, dampingFraction: 0.84)) {
                sliderPosition = defaultSliderPosition
            }

            hasPlayedIntroHint = true
            introHintTask = nil
        }
    }

    private func cancelIntroHint() {
        introHintTask?.cancel()
        introHintTask = nil
        hasPlayedIntroHint = true
    }
}
