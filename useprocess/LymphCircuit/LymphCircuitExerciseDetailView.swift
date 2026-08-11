import SwiftUI

/// Fiche exercice circuit lymphatique — vidéo démo, geste, bénéfices.
struct LymphCircuitExerciseDetailView: View {
    let step: FaceMorningRoutineCatalog.Step
    var sessionActionTitle: String?
    var onOpenSession: (() -> Void)?

    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    videoHero
                    movementSection
                    benefitsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, sessionActionTitle == nil ? 32 : 108)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let sessionActionTitle, let onOpenSession {
                    sessionCTA(title: sessionActionTitle, action: onOpenSession)
                }
            }
            .processTransparentScrollSurface()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(theme.primaryText.opacity(0.85))
                            .frame(width: 34, height: 34)
                            .background(
                                Circle()
                                    .fill(theme.isDark ? Color.white.opacity(0.1) : Color.black.opacity(0.06))
                            )
                    }
                    .accessibilityLabel(AppCopy.close)
                }
            }
        }
        .processAppPageBackground()
        .processAppPresentationBackground()
    }

    // MARK: - Hero vidéo

    private var videoHero: some View {
        ZStack(alignment: .bottomLeading) {
            LymphCircuitDemoMediaView(step: step, isPip: false)
                .aspectRatio(3 / 4, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(theme.isDark ? 0.5 : 0.12))

            LinearGradient(
                colors: [.clear, .black.opacity(0.35), .black.opacity(0.82)],
                startPoint: .center,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    stepIndexPill
                    if let badge = step.repBadge {
                        durationPill(badge)
                    }
                }

                Text(step.shortTitle)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(theme.isDark ? 0.12 : 0.08), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(theme.isDark ? 0.35 : 0.12), radius: 16, y: 8)
    }

    private var stepIndexPill: some View {
        Text(
            AppCopy.t(
                "Exercice \(step.stepNumber)/\(FaceMorningRoutineCatalog.Step.totalStepCount)",
                en: "Exercise \(step.stepNumber)/\(FaceMorningRoutineCatalog.Step.totalStepCount)"
            )
        )
        .font(.caption.weight(.bold))
        .foregroundStyle(.white.opacity(0.92))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(.white.opacity(0.18)))
    }

    private func durationPill(_ text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "timer")
                .font(.caption2.weight(.bold))
            Text(text)
                .font(.caption.weight(.bold))
                .monospacedDigit()
        }
        .foregroundStyle(.white.opacity(0.92))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(.black.opacity(0.38)))
    }

    // MARK: - Mouvement

    private var movementSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: AppCopy.t("Le mouvement", en: "The movement"),
                icon: "figure.mind.and.body"
            )

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(step.howToSteps.enumerated()), id: \.offset) { index, line in
                    HStack(alignment: .top, spacing: 14) {
                        Text("\(index + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(theme.onboardingAccent)
                            .frame(width: 26, height: 26)
                            .background(
                                Circle()
                                    .fill(theme.onboardingAccent.opacity(0.14))
                            )

                        Text(line)
                            .font(.subheadline)
                            .foregroundStyle(theme.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 3)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)

                    if index < step.howToSteps.count - 1 {
                        Divider()
                            .padding(.leading, 56)
                            .opacity(theme.isDark ? 0.22 : 0.45)
                    }
                }
            }
            .background(sectionCardBackground)
        }
    }

    // MARK: - Bénéfices

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: AppCopy.t("Bénéfices", en: "Benefits"),
                icon: "sparkles"
            )

            VStack(spacing: 10) {
                ForEach(Array(step.benefits.enumerated()), id: \.offset) { _, benefit in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(theme.onboardingAccent)
                            .padding(.top, 1)

                        Text(benefit)
                            .font(.subheadline)
                            .foregroundStyle(theme.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .background(sectionCardBackground)
                }
            }
        }
    }

    // MARK: - Chrome

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.onboardingAccent)
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(theme.primaryText)
        }
    }

    private var sectionCardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(theme.isDark ? Color.white.opacity(0.06) : theme.cardBackgroundStrong)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(theme.isDark ? 0.08 : 0.12), lineWidth: 0.5)
            }
    }

    private func sessionCTA(title: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [
                    theme.background.opacity(0),
                    theme.background.opacity(0.92),
                    theme.background
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 28)
            .allowsHitTesting(false)

            Button(action: action) {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                }
                .foregroundStyle(Color.black.opacity(0.88))
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Capsule(style: .continuous).fill(Color.white))
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5)
                }
            }
            .buttonStyle(.processPlain)
            .padding(.horizontal, 20)
            .padding(.bottom, max(UIApplication.safeAreaBottom, 16))
            .background(theme.background)
        }
    }
}
