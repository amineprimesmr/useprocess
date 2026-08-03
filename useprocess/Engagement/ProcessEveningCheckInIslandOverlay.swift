import SwiftUI

// MARK: - Dynamic Island expand overlay

/// Overlay plein écran simulant une extension Dynamic Island — fond flouté + dimming.
struct ProcessEveningCheckInIslandOverlay: View {
    @Bindable private var presenter = ProcessEveningCheckInPresenter.shared
    @Environment(\.appTheme) private var theme

    var body: some View {
        ZStack {
            if presenter.isPresented {
                backdropLayer
                    .transition(.opacity)
                    .zIndex(900)

                contentLayer
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        )
                    )
                    .zIndex(901)
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.84), value: presenter.isPresented)
    }

    // MARK: - Backdrop

    private var backdropLayer: some View {
        Color.black
            .opacity(0.38)
            .ignoresSafeArea()
            .background(.ultraThinMaterial)
            .ignoresSafeArea()
            .onTapGesture {
                guard !presenter.isRequired else { return }
                presenter.clear()
            }
    }

    // MARK: - Content

    private var contentLayer: some View {
        GeometryReader { geo in
            VStack {
                ProcessEveningCheckInIslandContent(
                    targetDate: presenter.targetDate,
                    isRequired: presenter.isRequired,
                    onCompleted: {
                        presenter.markCompleted()
                    }
                )
                .frame(maxWidth: .infinity)
                .frame(height: geo.size.height * 0.84)
                .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))
                .shadow(color: .black.opacity(0.22), radius: 28, y: 8)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - View modifier

struct EveningCheckInIslandModifier: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            content
                .blur(
                    radius: ProcessEveningCheckInPresenter.shared.isPresented ? 7 : 0
                )
                .animation(.easeInOut(duration: 0.28), value: ProcessEveningCheckInPresenter.shared.isPresented)

            ProcessEveningCheckInIslandOverlay()
        }
    }
}

extension View {
    func eveningCheckInIsland() -> some View {
        modifier(EveningCheckInIslandModifier())
    }
}
