import SwiftUI

/// Pages de permission — Santé Apple en version simple ; autres avec animation (à revoir plus tard).
struct PermissionStepView: View {
    enum Kind {
        case notifications
        case healthKit
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

            OnboardingStandardStepLayout(
                OnboardingCopy.t("Connecte-toi à", en: "Connect to"),
                OnboardingCopy.t("Santé Apple", en: "Apple Health")
            ) {
                VStack(spacing: 28) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.pink.opacity(0.9))

                    Text(
                        OnboardingCopy.t(
                            "Tes données restent privées et servent uniquement à personnaliser \(AppBranding.name).",
                            en: "Your data stays private and is only used to personalize \(AppBranding.name)."
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
                            Text(OnboardingCopy.t("Autoriser l'accès", en: "Allow access"))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(OnboardingTheme.filledButtonText(for: colorScheme))
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(
                                    OnboardingTheme.filledButtonBackground(for: colorScheme),
                                    in: RoundedRectangle(cornerRadius: 27)
                                )
                                .contentShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
                        }
                        .disabled(isRequesting)

                        Button {
                            onSkip?() ?? onComplete()
                        } label: {
                            Text(OnboardingCopy.t("Plus tard", en: "Later"))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(OnboardingTheme.bodyText)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        }
                        .processGlassButton(in: RoundedRectangle(cornerRadius: 25, style: .continuous))
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
                title: OnboardingCopy.t(
                    "Reste informé avec\nles notifications",
                    en: "Stay in the loop with\nnotifications"
                ),
                description: OnboardingCopy.t(
                    "\(AppBranding.name) t'enverra des rappels utiles\npour suivre ta progression.",
                    en: "\(AppBranding.name) will send useful reminders\nto track your progress."
                ),
                alertButtons: .two,
                activeTap: .two,
                primaryTitle: OnboardingCopy.t("Activer les notifications", en: "Enable notifications"),
                primaryAction: { Task { await requestAndContinue(notifications: true) } },
                secondaryTitle: OnboardingCopy.t("Plus tard", en: "Later"),
                secondaryAction: { onSkip?() ?? onComplete() }
            )

        case .healthKit:
            preconditionFailure("Santé Apple utilise simpleHealthKitView")
        }
    }

    @MainActor
    private func requestAndContinue(
        notifications: Bool = false,
        healthKit: Bool = false
    ) async {
        guard !isRequesting else { return }
        isRequesting = true
        HapticManager.shared.impact(.medium)

        if notifications {
            _ = await permissionsManager.requestNotificationPermission()
        }
        if healthKit {
            await healthManager.requestAuthorizationAsync()
            _ = await permissionsManager.requestMotionPermission()
        }

        isRequesting = false
        HapticManager.shared.notification(.success)
        try? await Task.sleep(for: .milliseconds(250))
        onComplete()
    }
}
