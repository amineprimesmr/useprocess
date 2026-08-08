import SwiftUI

/// Écran d’attente analyse repas — checklist loading → check (pas de barres).
struct MealScanAnalyzingView: View {
    let image: UIImage?
    let isAnalysisComplete: Bool
    let onRevealReady: () -> Void

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @State private var director = MealScanAnalysisProgressDirector()
    @State private var sweepOffset: CGFloat = -1
    @State private var pulse = false
    @State private var didStart = false
    @State private var didNotifyReveal = false

    var body: some View {
        ZStack {
            ProcessScreenBackground()

            Circle()
                .fill(theme.onboardingAccent.opacity(colorScheme == .dark ? 0.14 : 0.10))
                .frame(width: 320, height: 320)
                .blur(radius: 50)
                .scaleEffect(pulse ? 1.08 : 0.94)
                .offset(y: -130)

            VStack(spacing: 28) {
                Spacer(minLength: 36)

                photoHero

                VStack(spacing: 8) {
                    Text(AppCopy.t("Analyse du repas", en: "Meal analysis"))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(theme.primaryText)

                    Text(headerSubtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(theme.secondaryText)
                        .animation(.easeInOut(duration: 0.25), value: director.activeStepIndex)
                }

                checklistCard

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            guard !didStart else { return }
            didStart = true
            director.start()
            startAmbientMotion()
            if isAnalysisComplete {
                director.markAnalysisComplete()
            }
        }
        .onDisappear {
            director.stop()
        }
        .onChange(of: isAnalysisComplete) { _, done in
            if done { director.markAnalysisComplete() }
        }
        .onChange(of: director.isRevealReady) { _, ready in
            guard ready, !didNotifyReveal else { return }
            didNotifyReveal = true
            HapticManager.shared.notification(.success)
            onRevealReady()
        }
    }

    private var headerSubtitle: String {
        if director.isRevealReady || director.completedCount == director.steps.count {
            return AppCopy.t("Analyse prête", en: "Analysis ready")
        }
        guard director.steps.indices.contains(director.activeStepIndex) else {
            return AppCopy.t("Préparation…", en: "Preparing…")
        }
        return director.steps[director.activeStepIndex].title
    }

    // MARK: - Photo

    private var photoHero: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 152, height: 152)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .strokeBorder(theme.onboardingAccent.opacity(0.45), lineWidth: 2)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .clear,
                                        theme.onboardingAccent.opacity(0.32),
                                        .clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: 48)
                            .offset(y: sweepOffset * 80)
                            .blendMode(.plusLighter)
                            .mask {
                                RoundedRectangle(cornerRadius: 26, style: .continuous)
                            }
                    }
                    .shadow(color: theme.onboardingAccent.opacity(0.24), radius: 18, y: 8)
                    .scaleEffect(pulse ? 1.02 : 1.0)
            } else {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(theme.cardBackgroundStrong)
                    .frame(width: 152, height: 152)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Checklist

    private var checklistCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(director.steps.enumerated()), id: \.element.id) { index, step in
                let status = director.statuses.indices.contains(index)
                    ? director.statuses[index]
                    : .pending

                checklistRow(step: step, status: status)

                if index < director.steps.count - 1 {
                    Divider()
                        .padding(.leading, 52)
                        .opacity(0.35)
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 14)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(theme.isDark ? Color.white.opacity(0.06) : Color.white.opacity(0.92))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(theme.cardStroke.opacity(0.35), lineWidth: 0.5)
                }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.84), value: director.statuses)
    }

    private func checklistRow(
        step: MealScanAnalysisProgressDirector.Step,
        status: MealScanAnalysisProgressDirector.StepStatus
    ) -> some View {
        HStack(spacing: 14) {
            statusGlyph(status: status, systemImage: step.systemImage)

            Text(step.title)
                .font(.subheadline.weight(status == .loading ? .semibold : .medium))
                .foregroundStyle(
                    status == .pending
                        ? theme.secondaryText.opacity(0.55)
                        : theme.primaryText
                )
                .frame(maxWidth: .infinity, alignment: .leading)

            trailingStatus(status)
        }
        .padding(.vertical, 13)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: step, status: status))
    }

    @ViewBuilder
    private func statusGlyph(
        status: MealScanAnalysisProgressDirector.StepStatus,
        systemImage: String
    ) -> some View {
        ZStack {
            Circle()
                .fill(glyphBackground(status))
                .frame(width: 34, height: 34)

            switch status {
            case .completed:
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(theme.onboardingAccent)
                    .transition(.scale.combined(with: .opacity))
            case .loading:
                ProgressView()
                    .controlSize(.small)
                    .tint(theme.onboardingAccent)
            case .pending:
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.secondaryText.opacity(0.45))
            }
        }
        .animation(.spring(response: 0.36, dampingFraction: 0.78), value: status)
    }

    @ViewBuilder
    private func trailingStatus(_ status: MealScanAnalysisProgressDirector.StepStatus) -> some View {
        switch status {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(theme.onboardingAccent)
                .transition(.scale.combined(with: .opacity))
        case .loading:
            Text(AppCopy.t("…", en: "…"))
                .font(.caption.weight(.bold))
                .foregroundStyle(theme.secondaryText)
        case .pending:
            Circle()
                .strokeBorder(theme.secondaryText.opacity(0.22), lineWidth: 1.5)
                .frame(width: 18, height: 18)
        }
    }

    private func glyphBackground(_ status: MealScanAnalysisProgressDirector.StepStatus) -> Color {
        switch status {
        case .completed:
            return theme.onboardingAccent.opacity(0.16)
        case .loading:
            return theme.onboardingAccent.opacity(0.10)
        case .pending:
            return theme.secondaryText.opacity(0.08)
        }
    }

    private func accessibilityLabel(
        for step: MealScanAnalysisProgressDirector.Step,
        status: MealScanAnalysisProgressDirector.StepStatus
    ) -> String {
        switch status {
        case .completed:
            return AppCopy.t("\(step.title), terminé", en: "\(step.title), done")
        case .loading:
            return AppCopy.t("\(step.title), en cours", en: "\(step.title), in progress")
        case .pending:
            return AppCopy.t("\(step.title), en attente", en: "\(step.title), pending")
        }
    }

    private func startAmbientMotion() {
        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
            pulse = true
        }
        withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
            sweepOffset = 1
        }
    }
}
