import SwiftUI

/// Slider « glisser pour confirmer » — effet liquid glass (GSConfirm).
struct ProcessLiquidGlassConfirmSlider: View {
    var text: String
    var symbol: String
    var config: Config
    var onProgressChange: (CGFloat) -> Void = { _ in }
    var onFinish: (Bool) -> Void

    @GestureState private var isActive = false
    @State private var offsetX: CGFloat = 0
    @State private var didTriggerProgressHaptic = false

    var body: some View {
        GeometryReader { proxy in
            let rect = proxy.frame(in: .global)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(config.tint.opacity(0.08))
                    .stroke(Color.primary.opacity(0.12), lineWidth: 0.3)

                sliderLabel

                knob(in: rect)
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isActive)
        }
        .frame(height: config.height)
        .onChange(of: config.resetToggle) { _, _ in
            offsetX = 0
            didTriggerProgressHaptic = false
        }
    }

    private var sliderLabel: some View {
        ZStack(alignment: .leading) {
            Text(text)
                .font(config.textFont)
                .foregroundStyle(config.tint.opacity(0.35))

            Text(text)
                .font(config.textFont)
                .foregroundStyle(config.tint)
                .mask(alignment: .leading) {
                    GeometryReader { proxy in
                        let size = proxy.size
                        let maskWidth: CGFloat = 30
                        let width = size.width + (maskWidth * 2)

                        Rectangle()
                            .frame(width: maskWidth)
                            .blur(radius: 5)
                            .rotationEffect(.degrees(15))
                            .offset(x: -maskWidth)
                            .keyframeAnimator(initialValue: CGFloat.zero, repeating: true) { content, offset in
                                content.offset(x: offset)
                            } keyframes: { _ in
                                LinearKeyframe(width, duration: 3)
                            }
                    }
                }
        }
        .fontWeight(.medium)
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.leading, config.height / 2)
        .visualEffect { [config, isActive, offsetX] content, proxy in
            let scale: CGFloat = isActive ? 1.15 : 0.9
            let originalFrame = CGRect(x: offsetX, y: 0, width: config.height, height: config.height)
            let frame = originalFrame.insetBy(
                dx: originalFrame.width * (1 - scale) / 2,
                dy: originalFrame.height * (1 - scale) / 2
            )

            return content.layerEffect(
                ShaderLibrary.liquidLens(
                    .float2(frame.size),
                    .float(frame.minX),
                    .float(12),
                    .float(config.height / 4)
                ),
                maxSampleOffset: proxy.size
            )
        }
    }

    @ViewBuilder
    private func knob(in rect: CGRect) -> some View {
        Image(systemName: symbol)
            .font(config.symbolFont)
            .foregroundStyle(config.tint)
            .frame(width: config.height, height: config.height)
            .clipShape(.circle)
            .keyframeAnimator(initialValue: CGFloat.zero, repeating: config.isSymbolPulsing) { content, opacity in
                content.shadow(color: config.tint.opacity(opacity), radius: 5)
            } keyframes: { _ in
                LinearKeyframe(1, duration: 3)
                LinearKeyframe(0, duration: 3)
            }
            .background {
                ProcessLiquidGlassConfirmKnobBackground(tint: config.tint)
            }
            .contentShape(.circle)
            .scaleEffect(isActive ? 1.12 : 0.92)
            .offset(x: offsetX)
            .highPriorityGesture(
                DragGesture(minimumDistance: SafePressGesture.dragMinimumDistance)
                    .updating($isActive) { _, state, _ in
                        state = true
                    }
                    .onChanged { value in
                        let translation = value.translation.width
                        let maxOffset = max(rect.width - config.height, 0)
                        let cappedOffset = min(max(translation, 0), maxOffset)
                        offsetX = cappedOffset
                        let progress = maxOffset > 0 ? cappedOffset / maxOffset : 0
                        if progress > 0.12, !didTriggerProgressHaptic {
                            didTriggerProgressHaptic = true
                            HapticManager.shared.selection()
                        }
                        onProgressChange(progress)
                    }
                    .onEnded { _ in
                        let maxOffset = max(rect.width - config.height, 0)
                        let isCompleted = maxOffset > 0 && offsetX >= maxOffset - 1
                        onFinish(isCompleted)
                        withAnimation(.smooth) {
                            offsetX = isCompleted ? maxOffset : 0
                        }
                        if !isCompleted {
                            didTriggerProgressHaptic = false
                        }
                    }
            )
    }

    struct Config {
        var tint: Color
        var height: CGFloat
        var textFont: Font = .subheadline
        var symbolFont: Font = .title3
        var isSymbolPulsing = true
        var resetToggle = false
    }
}

private struct ProcessLiquidGlassConfirmKnobBackground: View {
    var tint: Color

    var body: some View {
        if #available(iOS 26.0, *) {
            Circle()
                .fill(.clear)
                .glassEffect(.clear.tint(tint.opacity(0.1)), in: .circle)
                .mask {
                    Rectangle()
                        .overlay {
                            Circle()
                                .padding(2)
                                .blur(radius: 2)
                                .blendMode(.destinationOut)
                        }
                }
        } else {
            Circle()
                .fill(tint.opacity(0.12))
                .overlay {
                    Circle().strokeBorder(tint.opacity(0.22), lineWidth: 0.5)
                }
        }
    }
}
