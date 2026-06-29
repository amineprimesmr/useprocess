import SwiftUI
import UIKit

// MARK: - Contour animé (périmètre carte)

private struct RoutineCardPerimeterProgress: Shape {
    var progress: CGFloat
    var cornerRadius: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let clamped = min(max(progress, 0), 1)
        guard clamped > 0 else { return Path() }

        let inset = rect.insetBy(dx: 1.5, dy: 1.5)
        let radius = min(cornerRadius, min(inset.width, inset.height) / 2)
        var perimeter = Path()

        let topMid = CGPoint(x: inset.midX, y: inset.minY)
        perimeter.move(to: topMid)

        perimeter.addLine(to: CGPoint(x: inset.maxX - radius, y: inset.minY))
        perimeter.addArc(
            center: CGPoint(x: inset.maxX - radius, y: inset.minY + radius),
            radius: radius,
            startAngle: .degrees(-90),
            endAngle: .degrees(0),
            clockwise: false
        )
        perimeter.addLine(to: CGPoint(x: inset.maxX, y: inset.maxY - radius))
        perimeter.addArc(
            center: CGPoint(x: inset.maxX - radius, y: inset.maxY - radius),
            radius: radius,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )
        perimeter.addLine(to: CGPoint(x: inset.minX + radius, y: inset.maxY))
        perimeter.addArc(
            center: CGPoint(x: inset.minX + radius, y: inset.maxY - radius),
            radius: radius,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )
        perimeter.addLine(to: CGPoint(x: inset.minX, y: inset.minY + radius))
        perimeter.addArc(
            center: CGPoint(x: inset.minX + radius, y: inset.minY + radius),
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )
        perimeter.addLine(to: topMid)

        return perimeter.trimmedPath(from: 0, to: clamped)
    }
}

// MARK: - Détecteur maintien (tap court + maintien 5 s)

struct RoutineHoldValidateDetector: UIViewRepresentable {
    var isEnabled: Bool
    var onBegan: () -> Void
    var onProgress: (CGFloat) -> Void
    var onShortTap: () -> Void
    var onCompleted: () -> Void
    var onEnded: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onBegan: onBegan,
            onProgress: onProgress,
            onShortTap: onShortTap,
            onCompleted: onCompleted,
            onEnded: onEnded
        )
    }

    func makeUIView(context: Context) -> RoutineHoldTouchView {
        let view = RoutineHoldTouchView()
        view.coordinator = context.coordinator
        return view
    }

    func updateUIView(_ uiView: RoutineHoldTouchView, context: Context) {
        uiView.isEnabled = isEnabled
        context.coordinator.onBegan = onBegan
        context.coordinator.onProgress = onProgress
        context.coordinator.onShortTap = onShortTap
        context.coordinator.onCompleted = onCompleted
        context.coordinator.onEnded = onEnded
        uiView.attachToScrollViewIfNeeded()
    }

    final class Coordinator {
        var onBegan: () -> Void
        var onProgress: (CGFloat) -> Void
        var onShortTap: () -> Void
        var onCompleted: () -> Void
        var onEnded: () -> Void

        init(
            onBegan: @escaping () -> Void,
            onProgress: @escaping (CGFloat) -> Void,
            onShortTap: @escaping () -> Void,
            onCompleted: @escaping () -> Void,
            onEnded: @escaping () -> Void
        ) {
            self.onBegan = onBegan
            self.onProgress = onProgress
            self.onShortTap = onShortTap
            self.onCompleted = onCompleted
            self.onEnded = onEnded
        }
    }
}

final class RoutineHoldTouchView: UIView {
    weak var coordinator: RoutineHoldValidateDetector.Coordinator?
    var isEnabled = true

    private var startTime: Date?
    private var timer: Timer?
    private var didComplete = false
    private var didAttachScroll = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        attachToScrollViewIfNeeded()
    }

    func attachToScrollViewIfNeeded() {
        guard !didAttachScroll, let scrollView = enclosingScrollView else { return }
        scrollView.delaysContentTouches = false
        didAttachScroll = true
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isEnabled, let touch = touches.first else { return }
        guard touch.tapCount <= 1 else { return }

        didComplete = false
        startTime = Date()
        coordinator?.onBegan()
        startTimer()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        if !bounds.contains(location) {
            cancelHold()
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !didComplete else {
            resetHold(emitEnded: true)
            return
        }

        let elapsed = elapsedSinceStart()
        if elapsed < 0.35 {
            coordinator?.onShortTap()
        }
        resetHold(emitEnded: true)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        resetHold(emitEnded: true)
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        guard startTime != nil else { return }
        let progress = currentProgress()
        coordinator?.onProgress(progress)

        if progress >= 1, !didComplete {
            didComplete = true
            coordinator?.onCompleted()
            resetHold(emitEnded: true)
        }
    }

    private func cancelHold() {
        resetHold(emitEnded: true)
    }

    private func resetHold(emitEnded: Bool = false) {
        timer?.invalidate()
        timer = nil
        startTime = nil
        coordinator?.onProgress(0)
        if emitEnded {
            coordinator?.onEnded()
        }
    }

    private func elapsedSinceStart() -> TimeInterval {
        guard let startTime else { return 0 }
        return Date().timeIntervalSince(startTime)
    }

    private func currentProgress() -> CGFloat {
        let duration = DailyRoutineCompletionCatalog.holdDurationSeconds
        guard duration > 0 else { return 0 }
        return CGFloat(min(1, elapsedSinceStart() / duration))
    }
}

private extension UIView {
    var enclosingScrollView: UIScrollView? {
        if let scrollView = superview as? UIScrollView { return scrollView }
        return superview?.enclosingScrollView
    }
}

// MARK: - Overlay maintien + succès

struct PlanRoutineHoldValidateOverlay<Content: View>: View {
    let accent: Color
    let cornerRadius: CGFloat
    let isCompleted: Bool
    let isEnabled: Bool
    let onShortTap: () -> Void
    let onValidate: () -> Void
  @ViewBuilder let content: () -> Content

    @State private var holdProgress: CGFloat = 0
    @State private var isHolding = false
    @State private var showSuccessBurst = false
    @State private var cardScale: CGFloat = 1

    var body: some View {
        content()
            .overlay {
                holdChromeOverlay
            }
            .scaleEffect(cardScale)
            .overlay {
                RoutineHoldValidateDetector(
                    isEnabled: isEnabled && !isCompleted,
                    onBegan: beginHold,
                    onProgress: { holdProgress = $0 },
                    onShortTap: {
                        HapticManager.shared.impact(.light)
                        onShortTap()
                    },
                    onCompleted: completeHold,
                    onEnded: endHold
                )
            }
            .accessibilityLabel(isCompleted ? "Routine validée" : "Routine")
            .accessibilityHint(
                isCompleted
                    ? "Validée pour aujourd'hui"
                    : "Maintiens 5 secondes pour valider, ou tape pour les détails"
            )
    }

    @ViewBuilder
    private var holdChromeOverlay: some View {
        ZStack {
            if isHolding && !isCompleted {
                RoutineCardPerimeterProgress(progress: holdProgress, cornerRadius: cornerRadius)
                    .stroke(
                        accent,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: accent.opacity(0.45), radius: 8)
                    .allowsHitTesting(false)
                    .animation(.linear(duration: 0.02), value: holdProgress)

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(accent.opacity(0.18 + Double(holdProgress) * 0.22), lineWidth: 1)
                    .allowsHitTesting(false)
            }

            if isCompleted || showSuccessBurst {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.green.opacity(isCompleted ? 0.55 : 0.35), lineWidth: 2)
                    .allowsHitTesting(false)
            }

            if showSuccessBurst {
                Color.white.opacity(0.28)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            if showSuccessBurst || isCompleted {
                VStack {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white, Color.green)
                            .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
                            .scaleEffect(showSuccessBurst ? 1.12 : 1)
                            .padding(10)
                        Spacer(minLength: 0)
                    }
                    Spacer(minLength: 0)
                }
                .allowsHitTesting(false)
            }
        }
    }

    private func beginHold() {
        guard !isCompleted else { return }
        isHolding = true
        HapticManager.shared.beginContinuousCardHold()
        withAnimation(.easeOut(duration: 0.18)) {
            cardScale = 0.97
        }
    }

    private func endHold() {
        guard isHolding else { return }
        isHolding = false
        holdProgress = 0
        HapticManager.shared.endContinuousCardHold()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
            cardScale = 1
        }
    }

    private func completeHold() {
        guard !isCompleted else { return }
        isHolding = false
        holdProgress = 1
        HapticManager.shared.endContinuousCardHold()
        HapticManager.shared.notification(.success)

        withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
            showSuccessBurst = true
            cardScale = 1.03
        }

        onValidate()

        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.12)) {
            cardScale = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(.easeOut(duration: 0.25)) {
                showSuccessBurst = false
            }
        }
    }
}
