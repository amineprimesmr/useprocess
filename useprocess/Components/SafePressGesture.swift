import SwiftUI
import UIKit

/// Gestes compatibles iOS 26 — évite `DragGesture(minimumDistance: 0)` (crash `_setContext:`).
enum SafePressGesture {
    static var dragMinimumDistance: CGFloat {
        iOS26Stability.isEnabled ? 8 : 0
    }
}

extension View {
    func safePressGesture(
        onPress: @escaping () -> Void,
        onRelease: @escaping () -> Void
    ) -> some View {
        overlay {
            UIKitPressDetector(onPress: onPress, onRelease: onRelease)
        }
    }

    func safeHorizontalDragGesture(
        onChanged: @escaping (DragGesture.Value) -> Void,
        onEnded: @escaping (DragGesture.Value) -> Void = { _ in }
    ) -> some View {
        gesture(
            DragGesture(minimumDistance: SafePressGesture.dragMinimumDistance)
                .onChanged(onChanged)
                .onEnded(onEnded)
        )
    }
}

private struct UIKitPressDetector: UIViewRepresentable {
    let onPress: () -> Void
    let onRelease: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPress: onPress, onRelease: onRelease)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true

        let recognizer = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePress(_:))
        )
        recognizer.minimumPressDuration = 0
        recognizer.cancelsTouchesInView = false
        view.addGestureRecognizer(recognizer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onPress = onPress
        context.coordinator.onRelease = onRelease
    }

    final class Coordinator: NSObject {
        var onPress: () -> Void
        var onRelease: () -> Void
        private var isPressed = false

        init(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) {
            self.onPress = onPress
            self.onRelease = onRelease
        }

        @objc func handlePress(_ recognizer: UILongPressGestureRecognizer) {
            switch recognizer.state {
            case .began:
                guard !isPressed else { return }
                isPressed = true
                onPress()
            case .ended, .cancelled, .failed:
                guard isPressed else { return }
                isPressed = false
                onRelease()
            default:
                break
            }
        }
    }
}
