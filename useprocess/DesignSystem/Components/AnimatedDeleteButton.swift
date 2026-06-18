import SwiftUI

struct AnimatedButtonCornerRadius {
    var source: CGFloat = 30
    var destination: CGFloat = 45
}

struct CustomDeleteAction {
    var confirmTitle: String
    var cancelTitle: String = "Annuler"
    var background: Color
    var foreground: Color
}

private struct AnimatedButtonProperties {
    var sourceLocation: CGRect = .zero
    var sourceView: UIImage?
    var hideSource: Bool = false
    var animate: Bool = false
    var showDeleteView: Bool = false
}

struct AnimatedDeleteButton<Content: View, Label: View>: View {
    var cornerRadius: AnimatedButtonCornerRadius = .init()
    var customAction: CustomDeleteAction?
    @ViewBuilder var content: Content
    @ViewBuilder var label: Label
    var action: (_ confirmed: Bool) -> Void

    @State private var properties: AnimatedButtonProperties = .init()
    @Environment(\.displayScale) private var displayScale: CGFloat

    var body: some View {
        Button {
            let renderer = ImageRenderer(content:
                label
                    .frame(
                        width: properties.sourceLocation.width,
                        height: properties.sourceLocation.height
                    )
                    .clipShape(.rect(cornerRadius: cornerRadius.source))
            )
            renderer.scale = displayScale
            properties.sourceView = renderer.uiImage

            withoutAnimation {
                properties.showDeleteView = true
            }
        } label: {
            label
                .clipShape(.rect(cornerRadius: cornerRadius.source))
                .contentShape(.rect(cornerRadius: cornerRadius.source))
                .opacity(properties.showDeleteView ? 0 : 1)
        }
        .onGeometryChange(for: CGRect.self, of: {
            $0.frame(in: .global)
        }, action: { newValue in
            properties.sourceLocation = newValue
        })
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $properties.showDeleteView) {
            DeleteButtonConfirmationView(
                customAction: customAction,
                cornerRadius: cornerRadius,
                properties: $properties,
                content: { content },
                action: action
            )
            .ignoresSafeArea()
            .presentationBackground(.clear)
            .persistentSystemOverlays(.hidden)
        }
    }
}

private struct DeleteButtonConfirmationView<Content: View>: View {
    var customAction: CustomDeleteAction?
    var cornerRadius: AnimatedButtonCornerRadius
    @Binding var properties: AnimatedButtonProperties
    @ViewBuilder var content: Content
    var action: (_ confirmed: Bool) -> Void

    var body: some View {
        let animate = properties.animate
        let hideSource = properties.hideSource
        let sourceLocation = properties.sourceLocation

        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(.black.opacity(animate ? 0.4 : 0))

            VStack(spacing: 10) {
                content
                actionButtons
            }
            .allowsHitTesting(animate)
            .padding(20)
            .compositingGroup()
            .geometryGroup()
            .background(.background, in: clipShape)
            .blur(radius: animate ? 0 : 10)
            .opacity(animate ? 1 : 0)
            .background {
                GeometryReader { proxy in
                    let size = proxy.size

                    if let sourceView = properties.sourceView {
                        Image(uiImage: sourceView)
                            .resizable()
                            .frame(
                                width: animate ? size.width : sourceLocation.width,
                                height: animate ? size.height : sourceLocation.height
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .blur(radius: hideSource ? 10 : 0)
                            .opacity(hideSource ? 0 : 1)
                    }
                }
            }
            .mask {
                clipShape
                    .frame(
                        width: animate ? nil : sourceLocation.width,
                        height: animate ? nil : sourceLocation.height
                    )
            }
            .padding(.horizontal, 10)
            .visualEffect { content, proxy in
                content
                    .offset(
                        x: animate ? 0 : sourceLocation.midX - (proxy.size.width / 2),
                        y: animate ? -10 : sourceLocation.midY - (proxy.size.height / 2)
                    )
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: animate ? .bottom : .topLeading
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(animation) {
                properties.animate = true
            }

            Task {
                withAnimation(sourceAnimation) {
                    properties.hideSource = true
                }
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 6) {
            Button {
                dismiss(confirmed: false)
            } label: {
                Text(customAction?.cancelTitle ?? "Annuler")
                    .foregroundStyle(Color.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(.gray.opacity(0.3))
                    .clipShape(.capsule)
            }

            Button {
                dismiss(confirmed: true)
            } label: {
                if let customAction {
                    Text(customAction.confirmTitle)
                        .foregroundStyle(customAction.foreground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(customAction.background.gradient)
                        .clipShape(.capsule)
                } else {
                    Text("Supprimer")
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(.red.gradient)
                        .clipShape(.capsule)
                }
            }
        }
        .fontWeight(.medium)
    }

    private func dismiss(confirmed: Bool) {
        withAnimation(animation, completionCriteria: .removed) {
            properties.animate = false
        } completion: {
            withoutAnimation {
                properties.sourceView = nil
                properties.showDeleteView = false
            }
            action(confirmed)
        }

        Task {
            withAnimation(sourceAnimation.delay(0.08)) {
                properties.hideSource = false
            }
        }
    }

    private var clipShape: AnyShape {
        let radius = properties.animate ? cornerRadius.destination : cornerRadius.source
        return .init(.rect(cornerRadius: radius))
    }

    private var animation: Animation {
        .interpolatingSpring(duration: 0.3)
    }

    private var sourceAnimation: Animation {
        .smooth(duration: 0.15, extraBounce: 0)
    }
}

private extension View {
    func withoutAnimation(_ content: @escaping () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            content()
        }
    }
}
