import SwiftUI

/// Lance le scan depuis l’accueil Plan (ou deep link) — ouvre directement la capture.
@MainActor
@Observable
final class ProcessFaceScanDayCoordinator {
    static let shared = ProcessFaceScanDayCoordinator()

    private(set) var pendingAutoStart = false

    private init() {}

    func requestAutoStart() {
        pendingAutoStart = true
    }

    func consumeAutoStartIfNeeded() -> Bool {
        guard pendingAutoStart else { return false }
        pendingAutoStart = false
        return true
    }

    func cancelPendingAutoStart() {
        pendingAutoStart = false
    }
}

/// Capture visage en plein écran — lancée depuis l’accueil Plan (pas d’onglet dédié).
struct ProcessFaceScanSessionHost: View {
    var onDismiss: () -> Void
    var isActive: Bool = true

    @ObservedObject private var creatorMode = ProcessCreatorModeStore.shared
    @Bindable private var scanDayCoordinator = ProcessFaceScanDayCoordinator.shared

    @State private var sessionToken = UUID()
    @State private var playsArrivalCountdown = false

    var body: some View {
        FaceScanSessionView(
            onDismiss: onDismiss,
            onComplete: { _ in onDismiss() },
            showsMediaImport: creatorMode.allowsPhotoImport,
            usesAppScreenBackground: true,
            playsArrivalCountdown: playsArrivalCountdown,
            arrivalCountdownDelay: playsArrivalCountdown ? 0.15 : 0
        )
        .id(sessionToken)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .processClearUIKitHostingBackground()
        .onAppear {
            consumeAutoStartIfNeeded()
        }
        .onChange(of: isActive) { _, active in
            guard active else { return }
            consumeAutoStartIfNeeded()
        }
        .onChange(of: scanDayCoordinator.pendingAutoStart) { _, pending in
            guard pending, isActive else { return }
            consumeAutoStartIfNeeded()
        }
    }

    private func consumeAutoStartIfNeeded() {
        guard scanDayCoordinator.consumeAutoStartIfNeeded() else { return }
        playsArrivalCountdown = true
        sessionToken = UUID()
    }
}

// MARK: - Onboarding dashboard scan bridge

private struct OnboardingScanPreviewPausedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var onboardingScanPreviewPaused: Bool {
        get { self[OnboardingScanPreviewPausedKey.self] }
        set { self[OnboardingScanPreviewPausedKey.self] = newValue }
    }

    var onboardingDashboardScanSession: OnboardingDashboardScanSession? {
        get { self[OnboardingDashboardScanSessionKey.self] }
        set { self[OnboardingDashboardScanSessionKey.self] = newValue }
    }
}

struct OnboardingDashboardScanSession {
    var onResult: (FaceScanResult) -> Void
    var onCancel: () -> Void
    var onSkipLater: () -> Void
    var onContinue: () -> Void
}

private struct OnboardingDashboardScanSessionKey: EnvironmentKey {
    static let defaultValue: OnboardingDashboardScanSession? = nil
}
