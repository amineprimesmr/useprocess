import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins
import QuartzCore

enum VariableBlurDirection {
    case blurredTopClearBottom
    case blurredBottomClearTop
}

struct VariableBlurView: UIViewRepresentable {
    var maxBlurRadius: CGFloat = 12
    var direction: VariableBlurDirection = .blurredTopClearBottom
    var startOffset: CGFloat = -0.08

    func makeUIView(context: Context) -> VariableBlurUIView {
        VariableBlurUIView(
            maxBlurRadius: maxBlurRadius,
            direction: direction,
            startOffset: startOffset
        )
    }

    func updateUIView(_ uiView: VariableBlurUIView, context: Context) {
        uiView.updateBlur(
            maxBlurRadius: maxBlurRadius,
            direction: direction,
            startOffset: startOffset
        )
    }
}

/// Uses CABackdropLayer + CAFilter `variableBlur` — same technique as Apple Music / App Store headers.
/// Credit: https://github.com/nikstar/VariableBlur
final class VariableBlurUIView: UIVisualEffectView {
    private var maxBlurRadius: CGFloat
    private var direction: VariableBlurDirection
    private var startOffset: CGFloat

    init(
        maxBlurRadius: CGFloat = 12,
        direction: VariableBlurDirection = .blurredTopClearBottom,
        startOffset: CGFloat = -0.08
    ) {
        self.maxBlurRadius = maxBlurRadius
        self.direction = direction
        self.startOffset = startOffset
        super.init(effect: UIBlurEffect(style: .regular))
        applyVariableBlur()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateBlur(
        maxBlurRadius: CGFloat,
        direction: VariableBlurDirection,
        startOffset: CGFloat
    ) {
        self.maxBlurRadius = maxBlurRadius
        self.direction = direction
        self.startOffset = startOffset
        applyVariableBlur()
    }

    override func didMoveToWindow() {
        guard let window, let backdropLayer = subviews.first?.layer else { return }
        backdropLayer.setValue(window.traitCollection.displayScale, forKey: "scale")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {}

    private func applyVariableBlur() {
        let filterClassName = String("retliFAC".reversed())
        guard let filterClass = NSClassFromString(filterClassName) as? NSObject.Type else { return }

        let factorySelector = NSSelectorFromString(String(":epyThtiWretlif".reversed()))
        guard
            let variableBlur = filterClass
                .perform(factorySelector, with: "variableBlur")
                .takeUnretainedValue() as? NSObject
        else { return }

        let gradientImage = makeGradientImage(startOffset: startOffset, direction: direction)
        variableBlur.setValue(maxBlurRadius, forKey: "inputRadius")
        variableBlur.setValue(gradientImage, forKey: "inputMaskImage")
        variableBlur.setValue(true, forKey: "inputNormalizeEdges")

        let backdropLayer = subviews.first?.layer
        backdropLayer?.filters = [variableBlur]

        for subview in subviews.dropFirst() {
            subview.alpha = 0
        }
    }

    private func makeGradientImage(
        width: CGFloat = 100,
        height: CGFloat = 100,
        startOffset: CGFloat,
        direction: VariableBlurDirection
    ) -> CGImage {
        let gradient = CIFilter.linearGradient()
        gradient.color0 = CIColor.black
        gradient.color1 = CIColor.clear
        gradient.point0 = CGPoint(x: 0, y: height)
        gradient.point1 = CGPoint(x: 0, y: startOffset * height)

        if case .blurredBottomClearTop = direction {
            gradient.point0.y = 0
            gradient.point1.y = height - gradient.point1.y
        }

        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        return CIContext().createCGImage(gradient.outputImage!, from: rect)!
    }
}
