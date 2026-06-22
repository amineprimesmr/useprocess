import SwiftUI

/// Side menu style X — implémentation fidèle à [Balaji Venkatesh / XStyleSideBar](https://github.com/balajivenkatesh/XStyleSideBar).
struct CustomSideMenu<MenuContent: View, Content: View>: View {
    var isEnabled: Bool = true
    var sideBarWidth: CGFloat = 300
    @Binding var isExpanded: Bool
    @ViewBuilder var menuContent: (_ progress: CGFloat) -> MenuContent
    @ViewBuilder var content: (_ progress: CGFloat) -> Content

    @State private var progress: CGFloat = 0
    @State private var xOffset: CGFloat = 0
    @State private var haptics = false

    var body: some View {
        ZStack(alignment: .leading) {
            menuContent(progress)
                .frame(width: sideBarWidth)
                .frame(maxHeight: .infinity)
                .opacity(progress)
                .scaleEffect(0.95 + (0.05 * progress), anchor: .leading)

            content(progress)
                .containerRelativeFrame(.horizontal)
                .frame(maxHeight: .infinity)
                .background {
                    SideMenuPanelShape()
                        .fill(.background)
                        .ignoresSafeArea()
                }
                .overlay {
                    SideMenuPanelShape()
                        .fill(.fill.tertiary)
                        .stroke(.fill.secondary, lineWidth: 1)
                        .ignoresSafeArea()
                        .contentShape(.rect)
                        .onTapGesture {
                            withAnimation(animation) {
                                dismissMenu()
                            }
                        }
                        .opacity(progress)
                }
                .mask {
                    SideMenuPanelShape()
                        .ignoresSafeArea()
                }
                // Pas de .compositingGroup() — casse le press natif liquid glass (iOS 26).
                .shadow(color: .black.opacity(0.06 * progress), radius: 5, x: -10, y: 0)
                .offset(x: xOffset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(.rect)
        .gesture(
            CustomSideMenuGesture(isEnabled: isEnabled, isExpanded: $isExpanded) { gesture in
                let state = gesture.state
                let translation = gesture.translation(in: gesture.view).x + (isExpanded ? sideBarWidth : 0)
                let velocity = gesture.velocity(in: gesture.view).x / 5

                if state == .began || state == .changed {
                    xOffset = min(max(translation, 0), sideBarWidth)
                    progress = xOffset / sideBarWidth
                    publishProgress()
                } else {
                    withAnimation(animation) {
                        if (xOffset + velocity) > (sideBarWidth / 2) {
                            expandMenu()
                        } else {
                            dismissMenu()
                        }
                    }
                }
            }
        )
        .sensoryFeedback(.impact(weight: .light), trigger: haptics)
        .onChange(of: isExpanded) { _, newValue in
            withAnimation(animation) {
                if newValue, progress != 1 {
                    expandMenu()
                }
                if !newValue, progress != 0 {
                    dismissMenu()
                }
            }
        }
        .onAppear {
            if isExpanded {
                xOffset = sideBarWidth
                progress = 1
            } else {
                xOffset = 0
                progress = 0
            }
            publishProgress()
        }
    }

    private func expandMenu() {
        if !isExpanded { haptics.toggle() }
        xOffset = sideBarWidth
        progress = 1
        isExpanded = true
        publishProgress()
    }

    private func dismissMenu() {
        if isExpanded { haptics.toggle() }
        xOffset = 0
        progress = 0
        isExpanded = false
        publishProgress()
    }

    private func publishProgress() {
        CoachSidebarPresentation.shared.sync(
            offset: xOffset,
            width: sideBarWidth,
            expanded: isExpanded
        )
    }

    private var animation: Animation {
        .interactiveSpring(duration: 0.2, extraBounce: 0.02)
    }
}

private struct SideMenuPanelShape: Shape {
    func path(in rect: CGRect) -> Path {
        if #available(iOS 26.0, *) {
            ConcentricRectangle(corners: .concentric, isUniform: true).path(in: rect)
        } else {
            RoundedRectangle(cornerRadius: 45, style: .continuous).path(in: rect)
        }
    }
}

/// Geste horizontal qui cède aux scroll views tant que contentOffset.x <= 0.
private struct CustomSideMenuGesture: UIGestureRecognizerRepresentable {
    var isEnabled: Bool
    @Binding var isExpanded: Bool
    var handle: (UIPanGestureRecognizer) -> Void

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let gesture = UIPanGestureRecognizer()
        gesture.delegate = context.coordinator
        gesture.maximumNumberOfTouches = 1
        return gesture
    }

    func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {
        recognizer.isEnabled = isEnabled
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        handle(recognizer)
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: CustomSideMenuGesture
        init(parent: CustomSideMenuGesture) { self.parent = parent }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let panGesture = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let velocity = panGesture.velocity(in: panGesture.view)
            let isHorizontalSwipe = abs(velocity.x) > abs(velocity.y)
            return (isHorizontalSwipe && velocity.x > 0) || (isHorizontalSwipe && velocity.x < 0 && parent.isExpanded)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            if let scrollView = otherGestureRecognizer.view as? UIScrollView {
                return scrollView.contentOffset.x <= 0
            }
            return false
        }
    }
}
