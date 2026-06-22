import SwiftUI
import UIKit

// MARK: - État

struct CoachUserMessageContextState: Equatable {
    let message: CoachMessage
    let bubbleFrame: CGRect
}

// MARK: - Bulle + long-press UIKit (compatible ScrollView)

struct CoachUserMessageBubbleView: View {
    let message: CoachMessage
    var profile: UnifiedUserProfile?
    var font: Font
    var lineSpacing: CGFloat
    var bubbleColor: Color
    var textColor: Color
    var onLongPress: (CGRect) -> Void

    @State private var bubbleFrame: CGRect = .zero

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Spacer(minLength: 48)

            CoachUserThoughtBubbleBody(bubbleColor: bubbleColor) {
                Text(message.text)
                    .font(font)
                    .foregroundStyle(textColor)
                    .lineSpacing(lineSpacing)
                    .multilineTextAlignment(.leading)
            }
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { bubbleFrame = proxy.frame(in: .global) }
                        .onChange(of: proxy.frame(in: .global)) { _, frame in
                            bubbleFrame = frame
                        }
                }
            }
            .overlay {
                CoachBubbleLongPressDetector { globalFrame in
                    let frame = globalFrame.width > 1 ? globalFrame : bubbleFrame
                    guard frame.width > 1, frame.height > 1 else { return }
                    HapticManager.shared.impact(.medium)
                    onLongPress(frame)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            CoachThoughtBubbleTailView(color: bubbleColor)
                .padding(.leading, -7)

            CoachUserChatAvatarView(
                profile: profile,
                bubbleColor: bubbleColor,
                textColor: textColor
            )
        }
    }
}

private extension UIView {
    var enclosingScrollView: UIScrollView? {
        var view: UIView? = self
        while let current = view {
            if let scroll = current as? UIScrollView { return scroll }
            view = current.superview
        }
        return nil
    }
}

/// UILongPressGestureRecognizer — fonctionne dans un ScrollView SwiftUI.
private struct CoachBubbleLongPressDetector: UIViewRepresentable {
    var onLongPress: (CGRect) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onLongPress: onLongPress)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true

        let recognizer = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        recognizer.minimumPressDuration = 0.35
        recognizer.cancelsTouchesInView = false
        recognizer.delegate = context.coordinator
        view.addGestureRecognizer(recognizer)
        context.coordinator.hostView = view
        context.coordinator.longPressRecognizer = recognizer
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onLongPress = onLongPress
        context.coordinator.hostView = uiView
        context.coordinator.attachToScrollViewIfNeeded(from: uiView)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onLongPress: (CGRect) -> Void
        weak var hostView: UIView?
        weak var longPressRecognizer: UILongPressGestureRecognizer?
        private var didAttachScroll = false

        init(onLongPress: @escaping (CGRect) -> Void) {
            self.onLongPress = onLongPress
        }

        func attachToScrollViewIfNeeded(from view: UIView) {
            guard !didAttachScroll,
                  let recognizer = longPressRecognizer,
                  let scrollView = view.enclosingScrollView else { return }
            scrollView.panGestureRecognizer.require(toFail: recognizer)
            didAttachScroll = true
        }

        @objc func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
            guard recognizer.state == .began else { return }
            guard let view = hostView ?? recognizer.view else { return }
            let frame = view.convert(view.bounds, to: nil)
            guard frame.width > 1, frame.height > 1 else { return }
            onLongPress(frame)
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldBeRequiredToFailBy other: UIGestureRecognizer
        ) -> Bool {
            other is UIPanGestureRecognizer
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            false
        }
    }
}

// MARK: - Overlay plein écran (style ChatGPT)

struct CoachUserMessageContextOverlay: View {
    let message: CoachMessage
    let bubbleFrame: CGRect
    var font: Font
    var lineSpacing: CGFloat
    var bubbleColor: Color
    var textColor: Color
    var onEdit: () -> Void
    var onDismiss: () -> Void

    @State private var appeared = false

    private let menuWidth: CGFloat = 232

    var body: some View {
        GeometryReader { geo in
            let origin = geo.frame(in: .global).origin
            let localBubble = bubbleFrame.offsetBy(dx: -origin.x, dy: -origin.y)
            let menuX = clampedMenuX(bubbleMidX: localBubble.midX, containerWidth: geo.size.width)
            let menuY = menuY(bubbleMinY: localBubble.minY)

            ZStack(alignment: .topLeading) {
                Color.black.opacity(appeared ? 0.14 : 0)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .contentShape(Rectangle())
                    .onTapGesture { dismiss() }

                Text(message.text)
                    .font(font)
                    .foregroundStyle(textColor)
                    .lineSpacing(lineSpacing)
                    .padding(.horizontal, CoachUserThoughtBubbleMetrics.horizontalPadding)
                    .padding(.vertical, CoachUserThoughtBubbleMetrics.verticalPadding)
                    .background(
                        bubbleColor,
                        in: RoundedRectangle(
                            cornerRadius: CoachUserThoughtBubbleMetrics.cornerRadius,
                            style: .continuous
                        )
                    )
                    .shadow(color: .black.opacity(0.14), radius: 14, y: 5)
                    .frame(width: max(localBubble.width, 40), height: max(localBubble.height, 36))
                    .position(x: localBubble.midX, y: localBubble.midY)
                    .scaleEffect(appeared ? 1 : 0.97)
                    .opacity(appeared ? 1 : 0)

                menuCard
                    .frame(width: menuWidth)
                    .scaleEffect(appeared ? 1 : 0.9)
                    .opacity(appeared ? 1 : 0)
                    .position(x: menuX, y: menuY)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                appeared = true
            }
        }
    }

    private var menuCard: some View {
        VStack(spacing: 0) {
            menuRow(icon: "square.on.square", title: "Copier") {
                UIPasteboard.general.string = message.text
                HapticManager.shared.notification(.success)
                dismiss()
            }

            menuRow(icon: "pencil", title: "Modifier") {
                HapticManager.shared.impact(.light)
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    onEdit()
                }
            }
        }
        .padding(.vertical, 6)
        .frame(width: menuWidth, alignment: .leading)
        .modifier(CoachMessageContextGlassModifier())
        .shadow(color: .black.opacity(0.12), radius: 24, x: 0, y: 10)
    }

    private func menuRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: 38, height: 38)
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.88))
                }

                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.primary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .processGlassMenuRowStyle()
    }

    private func menuY(bubbleMinY: CGFloat) -> CGFloat {
        let menuHeight: CGFloat = 108
        let preferred = bubbleMinY - menuHeight / 2 - 12
        return max(preferred, menuHeight / 2 + 56)
    }

    private func clampedMenuX(bubbleMidX: CGFloat, containerWidth: CGFloat) -> CGFloat {
        let half = menuWidth / 2
        return min(max(bubbleMidX, half + 14), containerWidth - half - 14)
    }

    private func dismiss() {
        withAnimation(.spring(response: 0.26, dampingFraction: 0.92)) {
            appeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            onDismiss()
        }
    }
}

private struct CoachMessageContextGlassModifier: ViewModifier {
    private let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(ProcessGlass.regularSurface, in: shape)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
        }
    }
}
