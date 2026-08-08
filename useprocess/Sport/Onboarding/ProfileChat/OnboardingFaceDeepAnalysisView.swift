import SwiftUI

/// Résultats premier scan onboarding : rétention + cortisol visibles, reste flouté / locked.
/// Design liquid glass aligné sur l’écran d’analyse Whoop.
struct OnboardingFaceDeepAnalysisView: View {
    @Environment(\.appTheme) private var theme

    let result: FaceScanResult
    var ringScale: CGFloat = 0.78
    var showsScoreRing: Bool = true
    var showsUnlockTeaser: Bool = true

    private var analysis: OnboardingFaceDeepAnalysis {
        OnboardingFaceDeepAnalysisBuilder.build(from: result)
    }

    private var lockedCategories: [LockedCategory] {
        LockedCategory.allCases.compactMap { category in
            let metrics = analysis.lockedMetrics.filter { category.kinds.contains($0.kind) }
            guard !metrics.isEmpty else { return nil }
            return category
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            if showsScoreRing {
                FaceScanWhoopScoreRing(result: result, showsGlobalScore: false)
                    .scaleEffect(ringScale)
                    .padding(.bottom, 4)
            }

            unlockedCard

            ForEach(lockedCategories) { category in
                lockedCategoryCard(
                    category,
                    metrics: analysis.lockedMetrics.filter { category.kinds.contains($0.kind) }
                )
            }

            lockedTextCard(
                title: AppCopy.t("Défauts principaux", en: "Main flaws"),
                subtitle: AppCopy.t("Ce qui alourdit ton visage", en: "What weighs down your face"),
                lines: analysis.primaryFlaws,
                linePrefix: "❌"
            )
            lockedTextCard(
                title: AppCopy.t("Atouts", en: "Strengths"),
                subtitle: AppCopy.t("Tes points forts structurels", en: "Your structural strengths"),
                lines: analysis.strengths,
                linePrefix: "✅"
            )
            lockedSummaryCard

            if showsUnlockTeaser {
                unlockTeaser
            }
        }
    }

    // MARK: - Unlocked (rétention + cortisol)

    private var unlockedCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(AppCopy.t("Signaux ouverts", en: "Open signals"))
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(FaceScanWhoopPalette.label)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 6)

            ForEach(Array(analysis.unlocked.enumerated()), id: \.element.id) { index, metric in
                if index > 0 {
                    Divider()
                        .overlay(dividerColor)
                        .padding(.leading, 52)
                }
                unlockedRow(metric)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
            }

            Divider()
                .overlay(dividerColor)
                .padding(.leading, 16)

            volumeCompositionRow(analysis.volumeComposition)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
        }
        .liquidGlassCard(isDark: theme.isDark)
    }

    /// Bleu uniquement pour la barre « rapport graisse / rétention ».
    private var retentionRatioAccent: Color {
        Color(red: 0.32, green: 0.58, blue: 0.96)
    }

    private func volumeCompositionRow(
        _ composition: OnboardingFaceDeepAnalysis.FacialVolumeComposition
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "circle.lefthalf.filled")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(FaceScanWhoopPalette.secondary)

                    Text(AppCopy.t("GRAISSE", en: "FAT"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(FaceScanWhoopPalette.label)
                        .tracking(0.3)
                }

                Spacer(minLength: 8)

                HStack(spacing: 6) {
                    Text(AppCopy.t("RÉTENTION", en: "RETENTION"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(FaceScanWhoopPalette.label)
                        .tracking(0.3)

                    Image(systemName: "drop.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(retentionRatioAccent)
                }
            }

            GeometryReader { geometry in
                let fatWidth = geometry.size.width * CGFloat(composition.fatPercent) / 100
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(FaceScanWhoopPalette.secondary.opacity(0.55))
                        .frame(width: max(4, fatWidth))

                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(retentionRatioAccent)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 8)

            HStack {
                Text("\(composition.fatPercent)%")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(FaceScanWhoopPalette.secondary)
                    .monospacedDigit()

                Spacer(minLength: 8)

                Text("\(composition.bloatedPercent)%")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(retentionRatioAccent)
                    .monospacedDigit()
            }

            VolumeCompositionGoodNewsCallout(text: composition.goodNewsPhrase)
                .padding(.top, 2)
        }
    }

    private func unlockedRow(_ metric: OnboardingFaceDeepAnalysis.UnlockedMetric) -> some View {
        HStack(spacing: 12) {
            Image(systemName: metric.systemImage)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(FaceScanWhoopPalette.label.opacity(0.88))
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(metric.title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(FaceScanWhoopPalette.label.opacity(0.95))
                    .tracking(0.25)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

                Text(metric.phrase)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(FaceScanWhoopPalette.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            FaceScanWhoopZoneBar(
                activeZone: metric.zone,
                higherIsWorse: metric.higherIsWorse,
                style: .immersive
            )
                .frame(width: 92)

            Text("\(metric.percent)%")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(FaceScanWhoopPalette.ringColor(for: metric.zone))
                .monospacedDigit()
                .frame(width: 52, alignment: .trailing)
        }
    }

    // MARK: - Locked categories

    private func lockedCategoryCard(
        _ category: LockedCategory,
        metrics: [OnboardingFaceDeepAnalysis.LockedMetric]
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader(
                title: category.title,
                subtitle: category.subtitle,
                locked: true
            )
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 10)

            ZStack {
                VStack(spacing: 0) {
                    ForEach(Array(metrics.enumerated()), id: \.element.id) { index, metric in
                        if index > 0 {
                            Divider()
                                .overlay(dividerColor)
                                .padding(.leading, 52)
                        }
                        lockedMetricRow(metric)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 13)
                    }
                }
                .blur(radius: 7)
                .opacity(0.72)

                lockedOverlay(title: category.lockLabel)
                    .padding(.vertical, 18)
            }
        }
        .liquidGlassCard(isDark: theme.isDark)
    }

    private func lockedMetricRow(_ metric: OnboardingFaceDeepAnalysis.LockedMetric) -> some View {
        HStack(spacing: 12) {
            Image(systemName: metric.kind.systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(FaceScanWhoopPalette.label.opacity(0.75))
                .frame(width: 22)

            Text(metric.kind.title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(FaceScanWhoopPalette.label)
                .tracking(0.3)
                .frame(maxWidth: .infinity, alignment: .leading)

            FaceScanWhoopZoneBar(
                activeZone: metric.zone,
                higherIsWorse: metric.kind.higherIsWorse,
                style: .immersive
            )
                .frame(width: 84)

            Text("\(metric.percent)%")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(FaceScanWhoopPalette.ringColor(for: metric.zone))
                .monospacedDigit()
                .frame(width: 40, alignment: .trailing)
        }
    }

    // MARK: - Locked insight cards

    private func lockedTextCard(title: String, subtitle: String, lines: [String], linePrefix: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader(title: title, subtitle: subtitle, locked: true)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 10)

            ZStack {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(lines, id: \.self) { line in
                        HStack(alignment: .top, spacing: 8) {
                            Text(linePrefix)
                                .font(.system(size: 13))
                                .padding(.top, 1)
                            Text(line)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(FaceScanWhoopPalette.label.opacity(0.88))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .blur(radius: 6.5)
                .opacity(0.7)

                lockedOverlay(title: AppCopy.t("Contenu verrouillé", en: "Content locked"))
                    .padding(.vertical, 18)
            }
        }
        .liquidGlassCard(isDark: theme.isDark)
    }

    private var lockedSummaryCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader(
                title: AppCopy.t("Résumé", en: "Summary"),
                subtitle: AppCopy.t("Lecture globale de ton visage", en: "Overall reading of your face"),
                locked: true
            )
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 10)

            ZStack {
                Text(analysis.summary)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(FaceScanWhoopPalette.label.opacity(0.88))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .blur(radius: 6.5)
                    .opacity(0.7)

                lockedOverlay(title: AppCopy.t("Résumé verrouillé", en: "Summary locked"))
                    .padding(.vertical, 18)
            }
        }
        .liquidGlassCard(isDark: theme.isDark)
    }

    // MARK: - Teaser

    private var unlockTeaser: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 13, weight: .semibold))
            Text(AppCopy.t(
                "Débloque l’analyse complète après l’onboarding",
                en: "Unlock the full analysis after onboarding"
            ))
                .font(.system(size: 12.5, weight: .semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .foregroundStyle(FaceScanWhoopPalette.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }

    // MARK: - Shared chrome

    private func cardHeader(title: String, subtitle: String? = nil, locked: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(FaceScanWhoopPalette.label)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(FaceScanWhoopPalette.secondary)
                }
            }

            Spacer(minLength: 0)

            if locked {
                lockBadge
            }
        }
    }

    private var lockBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: "lock.fill")
                .font(.system(size: 10, weight: .bold))
            Text(AppCopy.t("Locked", en: "Locked"))
                .font(.system(size: 10, weight: .bold))
                .textCase(.uppercase)
                .tracking(0.4)
        }
        .foregroundStyle(FaceScanWhoopPalette.secondary)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(FaceScanWhoopPalette.label.opacity(0.08))
        )
    }

    private func lockedOverlay(title: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.system(size: 18, weight: .semibold))
            Text(title)
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(FaceScanWhoopPalette.label.opacity(0.88))
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(FaceScanWhoopPalette.label.opacity(0.08), lineWidth: 0.5)
                )
        )
        .allowsHitTesting(false)
    }

    private var dividerColor: Color {
        theme.isDark ? Color.white.opacity(0.08) : Color.primary.opacity(0.08)
    }
}

// MARK: - Categories

private enum LockedCategory: String, CaseIterable, Identifiable {
    case gaze
    case structure
    case skin
    case harmony

    var id: String { rawValue }

    @MainActor
    var title: String {
        switch self {
        case .gaze: return AppCopy.t("Regard", en: "Gaze")
        case .structure: return AppCopy.t("Structure du visage", en: "Face structure")
        case .skin: return AppCopy.t("Peau & texture", en: "Skin & texture")
        case .harmony: return AppCopy.t("Harmonie globale", en: "Overall harmony")
        }
    }

    @MainActor
    var subtitle: String {
        switch self {
        case .gaze: return AppCopy.t("Yeux, cernes, zone sous les yeux", en: "Eyes, under-eyes, orbital area")
        case .structure: return AppCopy.t("Jawline, pommettes, maxillaire, nez", en: "Jawline, cheekbones, maxilla, nose")
        case .skin: return AppCopy.t("Clarté et reliefs de surface", en: "Clarity and surface relief")
        case .harmony: return AppCopy.t("Proportions, symétrie, volume", en: "Proportions, symmetry, volume")
        }
    }

    @MainActor
    var lockLabel: String {
        switch self {
        case .gaze: return AppCopy.t("3 indicateurs verrouillés", en: "3 indicators locked")
        case .structure: return AppCopy.t("6 indicateurs verrouillés", en: "6 indicators locked")
        case .skin: return AppCopy.t("2 indicateurs verrouillés", en: "2 indicators locked")
        case .harmony: return AppCopy.t("4 indicateurs verrouillés", en: "4 indicators locked")
        }
    }

    var kinds: [OnboardingFaceDeepAnalysis.Kind] {
        switch self {
        case .gaze:
            return [.eyes, .orbitalDepth, .underEyeHealth]
        case .structure:
            return [.midFace, .lowerThird, .upperThird, .cheekbones, .maxillary, .nose]
        case .skin:
            return [.skin, .nasolabialFold]
        case .harmony:
            return [.harmony, .symmetry, .neckWidth, .boneMass]
        }
    }
}

// MARK: - Bonne nouvelle (rapport graisse / rétention)

private struct VolumeCompositionGoodNewsCallout: View {
    let text: String

    @State private var arrowOffset: CGFloat = 0
    @State private var glow = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "arrow.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(FaceScanWhoopPalette.optimal)
                .frame(width: 18, alignment: .center)
                .offset(x: arrowOffset)
                .shadow(color: FaceScanWhoopPalette.optimal.opacity(glow ? 0.45 : 0.1), radius: glow ? 4 : 1)

            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(FaceScanWhoopPalette.optimal)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(FaceScanWhoopPalette.optimal.opacity(0.1))
        }
        .onAppear { startAnimations() }
    }

    private func startAnimations() {
        arrowOffset = 0
        glow = false
        withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
            arrowOffset = 6
            glow = true
        }
    }
}

// MARK: - Liquid glass chrome

private extension View {
    func liquidGlassCard(isDark: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        return self
            .background {
                shape
                    .fill(.clear)
                    .processGlassEffect(in: shape, interactive: false)
            }
            .clipShape(shape)
            .processHomeGlassCardShadow(isDark: isDark)
    }
}
