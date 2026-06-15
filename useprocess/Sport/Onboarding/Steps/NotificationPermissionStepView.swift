//
//  NotificationPermissionStepView.swift
//  Process
//
//  Page de demande de permission pour les notifications
//

import SwiftUI
import UserNotifications

struct NotificationPermissionStepView: View {
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
                .ignoresSafeArea(.all)

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: OnboardingConstants.scrollContentTopInset)

                (Text("Tu recevras un message ") + Text("à la fin").foregroundColor(OnboardingTheme.accentHighlight) + Text(" de ton essai"))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(OnboardingTheme.primaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 50)

                Image("Notif")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 420)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)

                Spacer()

                Button(action: {
                    Task {
                        await requestNotifications()
                    }
                }) {
                    HStack(spacing: 12) {
                        if isRequesting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: OnboardingTheme.primaryText))
                                .scaleEffect(0.8)
                        }
                        Text("Activer les notifications")
                            .font(.system(size: 20, weight: .black))
                    }
                    .foregroundStyle(OnboardingTheme.primaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .glassStyle()
                .buttonBorderShape(.roundedRectangle(radius: 50))
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
                .disabled(isRequesting)
            }
        }
    }

    @MainActor
    private func requestNotifications() async {
        HapticManager.shared.impact(.medium)
        isRequesting = true

        _ = await permissionsManager.requestNotificationPermission()

        isRequesting = false

        try? await Task.sleep(for: .milliseconds(300))

        HapticManager.shared.notification(.success)
        onComplete()
    }
}
