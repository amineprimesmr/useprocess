//
//  NotificationPermissionStepView.swift
//  Process
//
//  Push notifications — onboarding post-création du plan.
//

import SwiftUI
import UserNotifications

struct NotificationPermissionStepView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var permissionsManager: PermissionsManager

    let onComplete: () -> Void
    let onBack: (() -> Void)?

    @State private var isRequesting = false

    init(onComplete: @escaping () -> Void, onBack: (() -> Void)? = nil) {
        self.onComplete = onComplete
        self.onBack = onBack
    }

    var body: some View {
        ZStack {
            OnboardingTheme.screenBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: OnboardingConstants.backOnlyContentTopInset)

                bellHero
                    .padding(.bottom, 18)

                titleBlock
                    .padding(.horizontal, 28)
                    .padding(.bottom, 22)

                OnboardingPushNotificationPhoneMockup()
                    .padding(.horizontal, 34)
                    .frame(maxWidth: 340)
                    .frame(maxHeight: 430)
                    .layoutPriority(1)

                Spacer(minLength: 8)

                actionButtons
                    .padding(.horizontal, 28)
                    .padding(.bottom, max(28, UIApplication.safeAreaBottom + 8))
            }
        }
        .task {
            await permissionsManager.refreshNotificationAuthorizationStatus()
        }
    }

    private var bellHero: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.46, green: 0.68, blue: 0.98, opacity: 0.42),
                            Color(red: 0.58, green: 0.52, blue: 0.96, opacity: 0.18),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 2,
                        endRadius: 52
                    )
                )
                .frame(width: 104, height: 104)
                .blur(radius: 2)

            Image(systemName: "bell.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: Color(red: 0.40, green: 0.62, blue: 0.96, opacity: 0.45), radius: 10, y: 4)
                .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
        }
        .accessibilityHidden(true)
    }

    private var titleBlock: some View {
        VStack(spacing: 12) {
            Text(OnboardingCopy.t(
                "Laissez-nous vous aider à atteindre vos objectifs",
                en: "Let us help you reach your goals"
            ))
            .font(.system(size: 24, weight: .bold))
            .foregroundStyle(OnboardingTheme.primaryText)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            Text(OnboardingCopy.t(
                "Recevez des mises à jour sur vos progrès et des rappels pour suivre vos objectifs et activités.",
                en: "Get updates on your progress and reminders to stay on track with your goals and activities."
            ))
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(OnboardingTheme.mutedText)
            .multilineTextAlignment(.center)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 14) {
            Button {
                Task { await requestNotifications() }
            } label: {
                HStack(spacing: 12) {
                    if isRequesting {
                        ProgressView()
                            .progressViewStyle(
                                CircularProgressViewStyle(
                                    tint: OnboardingTheme.onboardingPrimaryActionText(for: colorScheme)
                                )
                            )
                            .scaleEffect(0.85)
                    }
                    Text(OnboardingCopy.continueCTA)
                        .font(.system(size: 18, weight: .bold))
                }
                .foregroundStyle(OnboardingTheme.onboardingPrimaryActionText(for: colorScheme))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
            }
            .onboardingPrimaryActionStyle()
            .disabled(isRequesting)

            Button {
                finishStep()
            } label: {
                Text(OnboardingCopy.t("Ignorer pour le moment", en: "Skip for now"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(OnboardingTheme.mutedText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.plain)
            .disabled(isRequesting)
        }
    }

    @MainActor
    private func requestNotifications() async {
        guard !isRequesting else { return }

        HapticManager.shared.impact(.medium)
        isRequesting = true

        let granted = await permissionsManager.requestNotificationPermission()

        if granted {
            if SubscriptionService.shared.isRetentionTrialOfferActive,
               let days = SubscriptionConfiguration.retentionTrialDays(for: .annual), days > 0 {
                await PaywallTrialNotificationService.shared.scheduleTrialEndingReminder(days: days)
            }
            HapticManager.shared.notification(.success)
        }

        isRequesting = false

        try? await Task.sleep(for: .milliseconds(250))
        finishStep()
    }

    @MainActor
    private func finishStep() {
        guard !isRequesting else { return }
        HapticManager.shared.impact(.light)
        onComplete()
    }
}
