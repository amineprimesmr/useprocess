import SwiftUI

extension View {
    /// Rappel boire — banner flottant (fallback si pas de Live Activity système).
    func hydrationTimerIsland() -> some View {
        modifier(ProcessHydrationTimerIslandModifier())
    }
}

private struct ProcessHydrationTimerIslandModifier: ViewModifier {
    @Bindable private var presenter = ProcessHydrationTimerPresenter.shared
    @State private var dismissTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if presenter.presentation != nil {
                    ProcessHydrationTimerFallbackBanner(
                        onFinished: requestDismiss
                    )
                    .padding(.top, 56)
                    .padding(.horizontal, 16)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .opacity
                        )
                    )
                    .zIndex(880)
                }
            }
            .animation(.bouncy(duration: 0.34, extraBounce: 0.04), value: presenter.presentation?.id)
    }

    private func requestDismiss() {
        guard presenter.presentation != nil else { return }
        dismissTask?.cancel()
        dismissTask = Task { @MainActor in
            withAnimation(.easeOut(duration: 0.2)) {
                presenter.clear()
            }
        }
    }
}

// MARK: - Banner fallback (style maquette GO + check)

private struct ProcessHydrationTimerFallbackBanner: View {
    var onFinished: () -> Void

    @Bindable private var timerStore = ProcessHydrationTimerStore.shared
    @State private var isLogging = false

    private enum Palette {
        static let accent = Color(red: 0.32, green: 0.78, blue: 0.96)
        static let alarmBlue = Color(red: 0.10, green: 0.42, blue: 0.82)
    }

    var body: some View {
        HStack(spacing: 12) {
            ProcessHydrationDropIcon.image(side: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(ProcessHydrationCopy.drinkReminderLine)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 6)

            Button {
                guard !isLogging else { return }
                isLogging = true
                Task {
                    _ = await timerStore.logSip(milliliters: 500, celebrateOnHome: true)
                    isLogging = false
                    onFinished()
                }
            } label: {
                ProcessHydrationDropIcon.image(side: 36)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(isLogging)
            .accessibilityLabel(AppCopy.t("Valider l'hydratation", en: "Confirm hydration"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.94))
        }
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.75)
        }
        .shadow(color: .black.opacity(0.28), radius: 16, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(ProcessHydrationCopy.drinkReminderLine)
    }
}
