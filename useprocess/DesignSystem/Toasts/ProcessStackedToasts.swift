import SwiftUI

/// Toasts empilés (style SToasts) — glass + stack animé.
struct ProcessStackedToasts: View {
    var glassTintOpacity: CGFloat = 0.42
    @Binding var toasts: [ProcessToast]

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                ProcessStackedToastsModern(glassTintOpacity: glassTintOpacity, toasts: $toasts)
            } else {
                ProcessStackedToastsLegacy(toasts: $toasts)
            }
        }
        .allowsHitTesting(!toasts.isEmpty)
    }
}

@available(iOS 26.0, *)
private struct ProcessStackedToastsModern: View {
    var glassTintOpacity: CGFloat
    @Binding var toasts: [ProcessToast]

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 0) {
                ForEach(toasts.reversed()) { toast in
                    let index = toasts.firstIndex(of: toast) ?? 0

                    ProcessToastRow(
                        glassTintOpacity: glassTintOpacity,
                        toast: toast
                    ) {
                        toasts.removeAll { $0.id == toast.id }
                    }
                    .visualEffect { content, proxy in
                        let minY = proxy.frame(in: .scrollView).minY
                        let progress = minY / 65
                        let offset = min(progress * 10, 20)
                        let scale = min(progress * 0.05, 0.1)

                        return content
                            .scaleEffect(1 - scale, anchor: .bottom)
                            .offset(y: -minY)
                            .offset(y: offset)
                    }
                    .zIndex(Double(index))
                    .transition(
                        .asymmetric(
                            insertion: .offset(y: 500).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        )
                    )
                }
            }
            .frame(maxWidth: .infinity)
        }
        .scrollDisabled(true)
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .frame(height: 90)
        .offset(y: 25 - max(min(CGFloat(toasts.count - 1) * 12.5, 25), 0))
        .background {
            ScrollView(.vertical) { }
                .frame(height: 0)
                .allowsHitTesting(false)
                .safeAreaBar(edge: .bottom, spacing: 0) {
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .frame(height: 90)
                }
                .scrollEdgeEffectStyle(.soft, for: .bottom)
                .opacity(toasts.isEmpty ? 0 : 1)
        }
        .animation(.smooth(duration: 0.3), value: toasts)
    }
}

private struct ProcessStackedToastsLegacy: View {
    @Binding var toasts: [ProcessToast]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(toasts.reversed()) { toast in
                ProcessToastRow(glassTintOpacity: 0.42, toast: toast) {
                    toasts.removeAll { $0.id == toast.id }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: toasts)
    }
}

private struct ProcessToastRow: View {
    var glassTintOpacity: CGFloat
    var toast: ProcessToast
    var onDismiss: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: toast.symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(toast.tintColor.gradient)

            VStack(alignment: .leading, spacing: toast.description.isEmpty ? 0 : 4) {
                Text(toast.title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Color.primary)

                if !toast.description.isEmpty {
                    Text(toast.description)
                        .font(.caption2)
                        .foregroundStyle(Color.secondary)
                }
            }
            .lineLimit(1)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: 310, alignment: .leading)
        .frame(height: toast.description.isEmpty ? 56 : 65)
        .background { toastTintMesh }
        .modifier(ProcessToastGlassModifier(glassTintOpacity: glassTintOpacity, glassTint: glassTint))
        .contentShape(.capsule)
        .compositingGroup()
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.22 : 0.06), radius: 5, x: 0, y: 10)
        .onTapGesture(perform: onDismiss)
        .modifier(ProcessToastSwipeDismissModifier(onDismiss: onDismiss))
        .task {
            guard let autoDismissInterval = toast.autoDismissInterval else { return }
            try? await Task.sleep(for: .seconds(autoDismissInterval))
            if !Task.isCancelled {
                onDismiss()
            }
        }
    }

    @ViewBuilder
    private var toastTintMesh: some View {
        let row1 = Array(repeating: toast.tintColor.opacity(0.15), count: 3)
        let row2 = Array(repeating: toast.tintColor.opacity(0.1), count: 3)
        let row3 = Array(repeating: Color.clear, count: 3)

        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.5, 0.5], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1]
            ],
            colors: row1 + row2 + row3
        )
        .clipShape(.capsule)
    }

    private var glassTint: Color {
        (colorScheme == .dark ? Color.black : Color.white).opacity(glassTintOpacity)
    }
}

private struct ProcessToastGlassModifier: ViewModifier {
    var glassTintOpacity: CGFloat
    var glassTint: Color

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.tint(glassTint), in: .capsule)
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
                .overlay {
                    Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                }
        }
    }
}

private struct ProcessToastSwipeDismissModifier: ViewModifier {
    var onDismiss: () -> Void

    @State private var offsetX: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: offsetX)
            .opacity(offsetX <= -120 ? 0 : 1)
            .gesture(
                DragGesture(minimumDistance: SafePressGesture.dragMinimumDistance)
                    .onChanged { value in
                        offsetX = min(0, value.translation.width)
                    }
                    .onEnded { value in
                        if value.translation.width < -72 {
                            withAnimation(.smooth(duration: 0.22)) {
                                offsetX = -260
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                                onDismiss()
                            }
                        } else {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                offsetX = 0
                            }
                        }
                    }
            )
    }
}
