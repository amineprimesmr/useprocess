import SwiftUI

/// Pages de permission — Santé Apple en version simple ; autres avec animation (à revoir plus tard).
struct PermissionStepView: View {
    enum Kind {
        case notifications
        case healthKit
        case location
    }

    let kind: Kind
    let onComplete: () -> Void
    var onSkip: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var permissionsManager: PermissionsManager
    @EnvironmentObject private var healthManager: HealthManager
    @State private var isRequesting = false

    var body: some View {
        Group {
            if kind == .healthKit {
                simpleHealthKitView
            } else {
                PermissionOnBoarding(config: makeConfig())
            }
        }
        .overlay {
            if isRequesting {
                ProgressView()
                    .tint(OnboardingTheme.primaryText)
                    .scaleEffect(1.2)
            }
        }
    }

    private var simpleHealthKitView: some View {
        ZStack {
            OnboardingTheme.screenBackground.ignoresSafeArea()

            OnboardingStandardStepLayout("Connecte-toi à", "Santé Apple") {
                VStack(spacing: 28) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.pink.opacity(0.9))

                    Text(
                        OnboardingCopy.text(
                            "Tes données restent privées et servent uniquement à personnaliser \(AppBranding.name).",
                            blank: "Description permission à personnaliser"
                        )
                    )
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(OnboardingTheme.bodyText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 8)

                    VStack(spacing: 12) {
                        Button {
                            Task { await requestAndContinue(healthKit: true) }
                        } label: {
                            Text(OnboardingCopy.text("Autoriser l'accès", blank: "Autoriser"))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(OnboardingTheme.filledButtonText(for: colorScheme))
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(
                                    OnboardingTheme.filledButtonBackground(for: colorScheme),
                                    in: RoundedRectangle(cornerRadius: 27)
                                )
                        }
                        .disabled(isRequesting)

                        Button {
                            onSkip?() ?? onComplete()
                        } label: {
                            Text(OnboardingCopy.text("Plus tard", blank: "Ignorer"))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(OnboardingTheme.bodyText)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        }
                        .glassStyle()
                        .buttonBorderShape(.roundedRectangle(radius: 25))
                        .disabled(isRequesting)
                    }
                }
                .padding(.horizontal, 32)

                Spacer()
            }
        }
    }

    private func makeConfig() -> PermissionOnBoarding.Config {
        switch kind {
        case .notifications:
            return .init(
                iPhoneTint: .gray,
                buttonTint: .white,
                initialDelay: 0.4,
                title: OnboardingCopy.text(
                    "Reste informé avec\nles notifications",
                    blank: "Permission\nnotifications"
                ),
                description: OnboardingCopy.text(
                    AppBranding.replacingProcess(in: "\(AppBranding.name) t'enverra des rappels utiles\npour suivre ta progression."),
                    blank: "Description permission à personnaliser"
                ),
                alertButtons: .two,
                activeTap: .two,
                primaryTitle: OnboardingCopy.text("Activer les notifications", blank: "Autoriser"),
                primaryAction: { Task { await requestAndContinue(notifications: true) } },
                secondaryTitle: OnboardingCopy.text("Plus tard", blank: "Ignorer"),
                secondaryAction: { onSkip?() ?? onComplete() }
            )

        case .location:
            return .init(
                iPhoneTint: .gray,
                buttonTint: .white,
                initialDelay: 0.4,
                title: OnboardingCopy.text(
                    "Autorise la\nlocalisation",
                    blank: "Permission\nlocalisation"
                ),
                description: OnboardingCopy.text(
                    "Nous utilisons ta position pour\npersonnaliser ton expérience.",
                    blank: "Description permission à personnaliser"
                ),
                alertButtons: .three,
                activeTap: .two,
                primaryTitle: OnboardingCopy.text("Continuer", blank: "Autoriser"),
                primaryAction: { Task { await requestAndContinue(location: true) } },
                secondaryTitle: OnboardingCopy.text("Plus tard", blank: "Ignorer"),
                secondaryAction: { onSkip?() ?? onComplete() }
            )

        case .healthKit:
            preconditionFailure("Santé Apple utilise simpleHealthKitView")
        }
    }

    @MainActor
    private func requestAndContinue(
        notifications: Bool = false,
        healthKit: Bool = false,
        location: Bool = false
    ) async {
        guard !isRequesting else { return }
        isRequesting = true
        HapticManager.shared.impact(.medium)

        if notifications {
            _ = await permissionsManager.requestNotificationPermission()
        }
        if healthKit {
            await healthManager.requestAuthorizationAsync()
            _ = await permissionsManager.requestLocationPermission()
            _ = await permissionsManager.requestMotionPermission()
        }
        if location {
            _ = await permissionsManager.requestLocationPermission()
        }

        isRequesting = false
        HapticManager.shared.notification(.success)
        try? await Task.sleep(for: .milliseconds(250))
        onComplete()
    }
}
