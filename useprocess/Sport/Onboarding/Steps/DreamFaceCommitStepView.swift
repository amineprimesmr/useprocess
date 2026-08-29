//
//  DreamFaceCommitStepView.swift
//  Process
//
//  Engagement « Dream Face » — slider, puis pop-up notifications, juste avant le paywall.
//

import SwiftUI
import UIKit

struct DreamFaceCommitStepView: View {
    @Environment(\.colorScheme) private var colorScheme

    let onComplete: () -> Void

    private let accent = Color(red: 0.42, green: 0.70, blue: 1.0)

    @State private var didFinish = false
    @State private var commitProgress: CGFloat = 0

    var body: some View {
        ZStack {
            canvasColor.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                VStack(spacing: 10) {
                    titleBlock
                    Text(OnboardingCopy.t(
                        "Une promesse que tu te fais.",
                        en: "A promise you make to yourself."
                    ))
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(OnboardingTheme.mutedText)
                    .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 36)

                DreamFaceCommitSlider(
                    accent: accent,
                    isLocked: didFinish,
                    progress: $commitProgress
                ) {
                    Task { await handleCommit() }
                }
                .padding(.horizontal, 28)
                .padding(.top, 32)

                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .processRestoreOpaqueUIKitHostingBackground(hostingFillColor)
    }

    private var canvasColor: Color {
        colorScheme == .dark ? Color.black : Color(red: 0.968, green: 0.972, blue: 0.988)
    }

    private var hostingFillColor: UIColor {
        colorScheme == .dark
            ? .black
            : UIColor(red: 0.968, green: 0.972, blue: 0.988, alpha: 1)
    }

    private var resolvedFirstName: String {
        let profileName = UnifiedProfileService.shared.currentProfile?.firstName
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if OnboardingViewModel.isRealUserFirstName(profileName) {
            return profileName
        }

        let snapshotName = OnboardingProgressService.shared.loadAnswers()?.firstName?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if OnboardingViewModel.isRealUserFirstName(snapshotName) {
            return snapshotName
        }

        return ""
    }

    private var titleRevealProgress: CGFloat {
        if didFinish { return 1 }
        return min(max((commitProgress - 0.06) / 0.78, 0), 1)
    }

    private var promisedTitle: some View {
        Text(OnboardingCopy.t("C'est promis", en: "Committed"))
            .font(.system(size: 26, weight: .bold))
            .foregroundStyle(accent)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var debloatTitle: some View {
        Group {
            if resolvedFirstName.isEmpty {
                Text(OnboardingCopy.t(
                    "Commence à debloat aujourd'hui",
                    en: "Start debloating today"
                ))
            } else {
                (
                    Text(OnboardingCopy.t(
                        "Commence à debloat aujourd'hui ",
                        en: "Start debloating today, "
                    ))
                    + Text(resolvedFirstName).foregroundStyle(accent)
                )
            }
        }
        .font(.system(size: 26, weight: .bold))
        .foregroundStyle(OnboardingTheme.primaryText)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var titleBlock: some View {
        ZStack {
            debloatTitle
                .opacity(1 - titleRevealProgress)
                .scaleEffect(1 - titleRevealProgress * 0.04, anchor: .center)

            promisedTitle
                .opacity(titleRevealProgress)
                .scaleEffect(0.96 + titleRevealProgress * 0.04, anchor: .center)
        }
        .animation(.easeInOut(duration: 0.16), value: titleRevealProgress)
    }

    @MainActor
    private func handleCommit() async {
        guard !didFinish else { return }
        didFinish = true

        _ = await PermissionsManager.shared.requestNotificationPermission(
            analyticsSource: "onboarding_dream_face_commit"
        )

        try? await Task.sleep(for: .milliseconds(280))
        onComplete()
    }
}

private struct DreamFaceCommitSlider: View {
    let accent: Color
    var isLocked: Bool
    @Binding var progress: CGFloat
    let onCommitted: () -> Void

    @State private var isDragging = false
    @State private var didCommit = false
    @State private var chevronPhase = 0.0
    @State private var lastHapticBucket = -1

    private let height: CGFloat = 92
    private let knobInset: CGFloat = 6
    private let commitThreshold: CGFloat = 0.92

    private var idleTrack: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 0.18, alpha: 1)
                : UIColor(white: 0.86, alpha: 1)
        })
    }

    var body: some View {
        GeometryReader { geo in
            let knobSize = height - knobInset * 2
            let maxTravel = max(geo.size.width - knobSize - knobInset * 2, 1)
            let knobX = knobInset + maxTravel * progress

            ZStack {
                Capsule()
                    .fill(idleTrack)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                accent.opacity(0.72),
                                accent,
                                Color(red: 0.28, green: 0.52, blue: 0.98)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(height, knobX + knobSize + knobInset))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .opacity(progress > 0.02 || didCommit ? 1 : 0)

                Text(OnboardingCopy.t("C'est promis", en: "Committed"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .mask(alignment: .leading) {
                        GeometryReader { labelGeo in
                            Rectangle()
                                .frame(width: labelGeo.size.width * labelRevealProgress)
                        }
                    }
                    .allowsHitTesting(false)

                Text(OnboardingCopy.t("Glisse pour confirmer", en: "Slide to confirm"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(idleLabelColor)
                    .frame(maxWidth: .infinity)
                    .mask(alignment: .trailing) {
                        GeometryReader { labelGeo in
                            let remaining = max(0, 1 - labelRevealProgress)
                            Rectangle()
                                .frame(width: labelGeo.size.width * remaining)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                    .allowsHitTesting(false)

                if !didCommit, progress < 0.62 {
                    chevrons
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, 18)
                        .opacity(1 - min(progress / 0.5, 1))
                        .allowsHitTesting(false)
                }

                Circle()
                    .fill(Color.white)
                    .overlay {
                        Circle()
                            .strokeBorder(accent, lineWidth: 3)
                    }
                    .shadow(color: accent.opacity(0.38), radius: isDragging ? 10 : 6, y: 1)
                    .shadow(color: Color.black.opacity(0.16), radius: 8, y: 3)
                    .frame(width: knobSize, height: knobSize)
                    .position(x: knobX + knobSize / 2, y: height / 2)
                    .gesture(dragGesture(maxTravel: maxTravel))
            }
        }
        .frame(height: height)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                chevronPhase = 1
            }
        }
        .onChange(of: isLocked) { _, locked in
            guard locked else { return }
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                progress = 1
                didCommit = true
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(OnboardingCopy.t("Glisse pour confirmer", en: "Slide to confirm"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            complete()
        }
    }

    private var labelRevealProgress: CGFloat {
        if didCommit { return 1 }
        return min(max(progress, 0), 1)
    }

    private var idleLabelColor: Color {
        OnboardingTheme.primaryText.opacity(0.72)
    }

    private var chevrons: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(OnboardingTheme.mutedText)
                    .opacity(0.35 + Double(index) * 0.18 + chevronPhase * 0.22)
                    .offset(x: chevronPhase * 3)
            }
        }
    }

    private func dragGesture(maxTravel: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: SafePressGesture.dragMinimumDistance)
            .onChanged { value in
                guard !didCommit, !isLocked else { return }
                if !isDragging {
                    isDragging = true
                    HapticManager.shared.beginEngagementHoldCrescendo()
                    HapticManager.shared.mediumImpact()
                }
                let next = min(max(value.translation.width / maxTravel, 0), 1)
                progress = next
                HapticManager.shared.updateEngagementHoldProgress(Double(next))
                fireProgressTick(for: next)
            }
            .onEnded { _ in
                guard !didCommit, !isLocked else { return }
                isDragging = false
                HapticManager.shared.endEngagementHoldCrescendo()
                if progress >= commitThreshold {
                    complete()
                } else {
                    // Relâché avant le seuil : jusqu'ici totalement invisible côté
                    // analytics — impossible de distinguer "jamais essayé" de
                    // "a hésité et lâché à mi-parcours".
                    ProcessAnalytics.capture("commitment_slider_released", properties: [
                        "progress": (Double(progress) * 100).rounded() / 100,
                        "source": "onboarding_dream_face_commit"
                    ])
                    lastHapticBucket = -1
                    HapticManager.shared.rigidImpact()
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                        progress = 0
                    }
                }
            }
    }

    private func fireProgressTick(for value: CGFloat) {
        let bucket = Int(value * 10)
        guard bucket > lastHapticBucket, bucket >= 2 else { return }
        lastHapticBucket = bucket
        if bucket >= 8 {
            HapticManager.shared.heavyImpact()
        } else if bucket >= 5 {
            HapticManager.shared.mediumImpact()
        } else {
            HapticManager.shared.rigidImpact()
        }
    }

    private func complete() {
        guard !didCommit else { return }
        didCommit = true
        HapticManager.shared.endEngagementHoldCrescendo()
        HapticManager.shared.engagementMilestonePulse()
        HapticManager.shared.success()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            progress = 1
        }
        onCommitted()
    }
}
