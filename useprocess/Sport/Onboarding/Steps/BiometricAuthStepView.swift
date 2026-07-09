//
//  BiometricAuthStepView.swift
//  Process
//
//  Page d'engagement — maintien du doigt pour confirmer.
//

import SwiftUI
import LocalAuthentication

struct BiometricAuthStepView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var profileService: UnifiedProfileService

    let onComplete: () -> Void
    let onBack: (() -> Void)?
    let onAuthenticationComplete: ((Bool) -> Void)?

    @State private var isAuthenticating = false
    @State private var isAuthenticated = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var progress: Double = 0.0
    @State private var isPressed = false
    @State private var pressStartTime: Date?

    /// 0 = ghost visible · 1 = engagement confirmé visuellement
    @State private var commitmentFillProgress: [Double] = [0, 0, 0]
    @State private var hapticMilestonesFired: Set<Int> = []
    @State private var pressTask: Task<Void, Never>?

    private let ghostTextOpacity = 0.34
    private let requiredPressDuration: TimeInterval = 4.0
    private let commitmentGreen = Color(red: 0.13, green: 0.98, blue: 0.47)

    private let commitments = [
        "Tenir mon plan 7 jours sur 7",
        "Scanner mon visage et suivre mes progrès",
        "Faire confiance à Process pour m'accompagner"
    ]

    init(onComplete: @escaping () -> Void, onBack: (() -> Void)? = nil, onAuthenticationComplete: ((Bool) -> Void)? = nil) {
        self.onComplete = onComplete
        self.onBack = onBack
        self.onAuthenticationComplete = onAuthenticationComplete
    }

    var body: some View {
        ZStack {
            OnboardingTheme.screenBackground
                .ignoresSafeArea(.all)

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: OnboardingConstants.titleTopPaddingFromScreenTop)

                Text("Engage-toi envers toi-même")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(OnboardingTheme.primaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 72)

                Text(OnboardingCopy.text("À partir de ce jour, je m'engage à :", blank: "Sous-titre à personnaliser"))
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(OnboardingTheme.bodyText)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 22)

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(commitments.enumerated()), id: \.offset) { index, text in
                        commitmentRow(text: text, index: index)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 36)

                Spacer()

                fingerprintZone
                    .padding(.horizontal, 40)
                    .padding(.bottom, 50)
            }
            .regularWidthContainer(maxWidth: AdaptiveScreenLayout.onboardingChatMaxWidth)
        }
        .alert("Erreur", isPresented: $showError) {
            Button("OK") {
                isAuthenticating = false
                progress = 0.0
            }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Commitment rows

    @ViewBuilder
    private func commitmentRow(text: String, index: Int) -> some View {
        let fill = commitmentFillProgress.indices.contains(index) ? commitmentFillProgress[index] : 0
        let textOpacity = ghostTextOpacity + (1 - ghostTextOpacity) * fill

        HStack(alignment: .top, spacing: 12) {
            commitmentIcon(fill: fill)
                .frame(width: 22, height: 22)
                .padding(.top, 1)

            Text(text)
                .font(.system(size: 14, weight: fill >= 0.98 ? .semibold : .medium))
                .foregroundStyle(OnboardingTheme.primaryText)
                .opacity(textOpacity)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .animation(.easeOut(duration: 0.22), value: fill)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.spring(response: 0.42, dampingFraction: 0.78), value: fill)
    }

    @ViewBuilder
    private func commitmentIcon(fill: Double) -> some View {
        ZStack {
            Circle()
                .strokeBorder(
                    OnboardingTheme.primaryText.opacity(0.18 + 0.12 * (1 - fill)),
                    lineWidth: 1.5
                )
                .scaleEffect(1 - fill * 0.08)
                .opacity(1 - min(1, fill * 1.4))

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(commitmentGreen)
                .scaleEffect(0.35 + 0.65 * fill)
                .opacity(fill)
                .shadow(
                    color: commitmentGreen.opacity(fill * 0.45),
                    radius: fill * 6,
                    x: 0,
                    y: 0
                )
        }
        .animation(.spring(response: 0.44, dampingFraction: 0.68), value: fill)
    }

    private func updateCommitmentFill(progress: Double) {
        let segment = 1.0 / Double(commitments.count)
        for index in commitments.indices {
            let segmentStart = Double(index) * segment
            let fill = min(1, max(0, (progress - segmentStart) / segment))
            if abs(commitmentFillProgress[index] - fill) > 0.008 {
                commitmentFillProgress[index] = fill
            }
            if fill >= 0.92, !hapticMilestonesFired.contains(index) {
                hapticMilestonesFired.insert(index)
                HapticManager.shared.engagementMilestonePulse()
            }
        }
        HapticManager.shared.updateEngagementHoldProgress(progress)
    }

    // MARK: - Fingerprint Zone

    private var fingerprintZone: some View {
        GeometryReader { geometry in
            let side = AdaptiveScreenLayout.biometricZoneSize(containerWidth: geometry.size.width)
            let ringSide = side * (210.0 / 380.0)
            let lightModeRingYOffset: CGFloat = colorScheme == .light ? -7 : 0

            ZStack {
                Image("fingerprint")
                    .resizable()
                    .renderingMode(.original)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: side, height: side)
                    .scaleEffect(isPressed ? 1.05 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)

                ZStack {
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    commitmentGreen.opacity(0.6),
                                    Color(red: 0.20, green: 0.85, blue: 0.60).opacity(0.4),
                                    commitmentGreen.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                        )
                        .frame(width: ringSide, height: ringSide)
                        .rotationEffect(.degrees(-90))
                        .shadow(color: commitmentGreen.opacity(0.5), radius: 8, x: 0, y: 0)
                        .blur(radius: 1)
                        .animation(.easeInOut(duration: 0.1), value: progress)
                }
                .offset(y: lightModeRingYOffset)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .safePressGesture(
                onPress: {
                    if !isPressed { startPress() }
                },
                onRelease: endPress
            )
        }
        .frame(height: 380)
    }

    // MARK: - Actions

    private func startPress() {
        guard !isPressed && !isAuthenticated else { return }

        isPressed = true
        pressStartTime = Date()
        progress = 0.0
        isAuthenticating = true
        hapticMilestonesFired = []

        HapticManager.shared.beginEngagementHoldCrescendo()

        pressTask?.cancel()
        pressTask = Task {
            let startTime = Date()

            while !Task.isCancelled, isPressed, !isAuthenticated {
                let elapsed = Date().timeIntervalSince(startTime)
                let newProgress = min(elapsed / requiredPressDuration, 1.0)

                progress = newProgress
                updateCommitmentFill(progress: newProgress)

                if newProgress >= 1.0 {
                    completeAuthentication()
                    return
                }

                try? await Task.sleep(nanoseconds: 16_666_666)
            }
        }
    }

    private func stopPressTask() {
        pressTask?.cancel()
        pressTask = nil
    }

    private func endPress() {
        guard isPressed else { return }

        isPressed = false
        pressStartTime = nil
        stopPressTask()
        HapticManager.shared.endEngagementHoldCrescendo()
        hapticMilestonesFired = []

        if !isAuthenticated {
            isAuthenticating = false
            withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                progress = 0.0
                commitmentFillProgress = Array(repeating: 0, count: commitments.count)
            }
        }
    }

    private func completeAuthentication() {
        guard !isAuthenticated else { return }

        isPressed = false
        isAuthenticated = true
        progress = 1.0
        stopPressTask()
        HapticManager.shared.endEngagementHoldCrescendo()

        withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
            commitmentFillProgress = Array(repeating: 1, count: commitments.count)
        }

        HapticManager.shared.notification(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            HapticManager.shared.notification(.success)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            onComplete()
        }
    }
}
