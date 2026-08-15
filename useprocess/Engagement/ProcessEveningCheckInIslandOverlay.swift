import SwiftUI

extension View {
    /// Présente le bilan en grande capsule animée depuis le Dynamic Island.
    func eveningCheckInIsland(
        presenter: ProcessEveningCheckInPresenter = .shared,
        onDismiss: @escaping (_ submitted: Bool) -> Void = { _ in }
    ) -> some View {
        modifier(ProcessEveningCheckInIslandModifier(presenter: presenter, onDismiss: onDismiss))
    }
}

private struct ProcessEveningCheckInIslandModifier: ViewModifier {
    var presenter: ProcessEveningCheckInPresenter
    var onDismiss: (_ submitted: Bool) -> Void

    @State private var isExpanded = false
    @State private var didSubmitCurrentSession = false
    @State private var collapseTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        @Bindable var presenter = presenter
        content
            .blur(radius: presenter.presentation != nil && isExpanded ? 7 : 0)
            .allowsHitTesting(presenter.presentation == nil)
            .animation(.easeOut(duration: 0.32), value: isExpanded)
            .overlay {
                if let presentation = presenter.presentation {
                    ProcessEveningCheckInIslandRoot(
                        presentation: presentation,
                        isExpanded: $isExpanded,
                        onSubmitted: {
                            didSubmitCurrentSession = true
                            presenter.markCompleted()
                        },
                        onRequestDismiss: {
                            requestDismiss(allowWithoutSubmit: !presentation.isRequired)
                        }
                    )
                    .transition(.opacity)
                    .zIndex(950)
                }
            }
            .onChange(of: presenter.presentation?.id) { oldID, newID in
                collapseTask?.cancel()
                if newID != nil {
                    if oldID == nil {
                        didSubmitCurrentSession = false
                    }
                    isExpanded = false
                    DispatchQueue.main.async {
                        withAnimation(.bouncy(duration: 0.42, extraBounce: 0.04)) {
                            isExpanded = true
                        }
                    }
                    HapticManager.shared.impact(.medium)
                } else {
                    isExpanded = false
                }
            }
    }

    private func requestDismiss(allowWithoutSubmit: Bool) {
        guard let presentation = presenter.presentation else { return }
        let submitted = didSubmitCurrentSession
            || ProcessEveningCheckInStore.shared.hasSubmitted(on: presentation.targetDate)
        if !allowWithoutSubmit, !submitted { return }

        collapseTask?.cancel()
        withAnimation(.bouncy(duration: 0.32, extraBounce: 0)) {
            isExpanded = false
        }

        collapseTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(320))
            guard !Task.isCancelled else { return }
            presenter.clear()
            onDismiss(submitted)
        }
    }
}

// MARK: - Root (backdrop + capsule)

private struct ProcessEveningCheckInIslandRoot: View {
    let presentation: ProcessEveningCheckInPresentation
    @Binding var isExpanded: Bool
    var onSubmitted: () -> Void
    var onRequestDismiss: () -> Void

    private enum Metrics {
        static let collapsedWidth: CGFloat = 126
        static let collapsedHeight: CGFloat = 37
        static let cornerCollapsed: CGFloat = 20
        static let cornerExpanded: CGFloat = 34
        static let horizontalInset: CGFloat = 12
        static let bottomInset: CGFloat = 28
        /// Plafond — assez d’air pour le formulaire aéré.
        static let expandedHeightRatio: CGFloat = 0.68
        static let expandedFallbackHeight: CGFloat = 420
    }

    @State private var measuredFormHeight: CGFloat = 0
    @State private var submitShakeNudge = 0

    var body: some View {
        GeometryReader { proxy in
            let safeArea = proxy.safeAreaInsets
            let size = proxy.size
            let haveDynamicIsland = safeArea.top >= 59
            let topOffset: CGFloat = haveDynamicIsland
                ? (9 + max(safeArea.top - 59, 0))
                : safeArea.top + 8
            let expandedWidth = size.width - (Metrics.horizontalInset * 2)
            let maxExpanded = min(
                size.height - topOffset - Metrics.bottomInset,
                size.height * Metrics.expandedHeightRatio
            )
            let expandedHeight = min(
                measuredFormHeight > 1 ? measuredFormHeight : Metrics.expandedFallbackHeight,
                maxExpanded
            )
            let canDismissByBackdrop = !presentation.isRequired

            ZStack(alignment: .top) {
                Color.black
                    .opacity(isExpanded ? 0.38 : 0)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if canDismissByBackdrop {
                            HapticManager.shared.impact(.light)
                            onRequestDismiss()
                        } else {
                            submitShakeNudge += 1
                        }
                    }
                    .allowsHitTesting(isExpanded)

                islandCapsule(
                    haveDynamicIsland: haveDynamicIsland,
                    expandedWidth: expandedWidth,
                    expandedHeight: expandedHeight,
                    topOffset: topOffset,
                    safeArea: safeArea
                )
                .zIndex(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private func islandCapsule(
        haveDynamicIsland: Bool,
        expandedWidth: CGFloat,
        expandedHeight: CGFloat,
        topOffset: CGFloat,
        safeArea: EdgeInsets
    ) -> some View {
        let width = isExpanded ? expandedWidth : Metrics.collapsedWidth
        let height = isExpanded ? expandedHeight : Metrics.collapsedHeight
        let corner = isExpanded ? Metrics.cornerExpanded : Metrics.cornerCollapsed

        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)

        ZStack {
            capsuleFill(cornerRadius: corner)

            ProcessEveningCheckInIslandContent(
                targetDate: presentation.targetDate,
                isRequired: presentation.isRequired,
                isExpanded: isExpanded,
                submitShakeNudge: submitShakeNudge,
                onSubmitted: onSubmitted,
                onFinished: onRequestDismiss
            )
            .frame(width: expandedWidth, height: expandedHeight, alignment: .top)
            .opacity(isExpanded ? 1 : 0)
            .blur(radius: isExpanded ? 0 : 8)
            .allowsHitTesting(isExpanded)
            .onPreferenceChange(EveningCheckInFormHeightKey.self) { height in
                guard height > 1, abs(height - measuredFormHeight) > 0.5 else { return }
                measuredFormHeight = height
            }
        }
        .frame(width: width, height: height)
        .animation(.snappy(duration: 0.22), value: measuredFormHeight)
        .clipShape(shape)
        .contentShape(shape)
        .overlay {
            shape.strokeBorder(Color.white.opacity(isExpanded ? 0.16 : 0.22), lineWidth: 0.75)
        }
        .shadow(color: .black.opacity(isExpanded ? 0.45 : 0), radius: 28, y: 16)
        .offset(
            y: haveDynamicIsland
                ? topOffset
                : (isExpanded ? safeArea.top + 10 : -90)
        )
        .opacity(haveDynamicIsland ? 1 : (isExpanded ? 1 : 0))
        .compositingGroup()
        .accessibilityAddTraits(.isModal)
    }

    @ViewBuilder
    private func capsuleFill(cornerRadius: CGFloat) -> some View {
        if #available(iOS 26.0, *) {
            ConcentricRectangle(
                corners: .concentric(minimum: .fixed(min(cornerRadius, 30))),
                isUniform: true
            )
            .fill(Color.black)
        } else {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.black)
        }
    }
}
