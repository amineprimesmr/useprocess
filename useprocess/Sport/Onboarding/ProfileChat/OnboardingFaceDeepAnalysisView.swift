import SwiftUI

/// Résultats premier scan onboarding : rétention visible, notes de zones verrouillées.
/// Design liquid glass aligné sur l’écran d’analyse Whoop.
struct OnboardingFaceDeepAnalysisView: View {
    @Environment(\.appTheme) private var theme

    let result: FaceScanResult
    var ringScale: CGFloat = 0.78
    var showsScoreRing: Bool = true
    var showsUnlockTeaser: Bool = true

    @State private var selectedPage: SignalCarouselPage? = .openSignals
    @State private var analysis: OnboardingFaceDeepAnalysis

    private var currentPage: SignalCarouselPage {
        selectedPage ?? .openSignals
    }

    init(
        result: FaceScanResult,
        ringScale: CGFloat = 0.78,
        showsScoreRing: Bool = true,
        showsUnlockTeaser: Bool = true
    ) {
        self.result = result
        self.ringScale = ringScale
        self.showsScoreRing = showsScoreRing
        self.showsUnlockTeaser = showsUnlockTeaser
        _analysis = State(initialValue: OnboardingFaceDeepAnalysisBuilder.build(from: result))
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

    private var openSignalsTitle: String {
        let name = resolvedFirstName
        if name.isEmpty {
            return AppCopy.t("Ce qui gonfle :", en: "What's bloating:")
        }
        return AppCopy.t("Ce qui gonfle, \(name) :", en: "What's bloating, \(name):")
    }

    var body: some View {
        VStack(spacing: 12) {
            if showsScoreRing {
                FaceScanWhoopScoreRing(result: result, showsGlobalScore: false)
                    .scaleEffect(ringScale)
                    .padding(.bottom, 4)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) {
                    ForEach(SignalCarouselPage.allCases, id: \.self) { page in
                        signalPage(page)
                            .padding(.horizontal, 2)
                            .containerRelativeFrame(.horizontal)
                            .frame(maxHeight: .infinity, alignment: .top)
                            .id(page)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne))
            .scrollPosition(id: $selectedPage)
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .frame(minHeight: 360)
            .frame(maxHeight: .infinity)

            signalPageDots

            if showsUnlockTeaser {
                unlockTeaser
            }
        }
        .onChange(of: result) { _, newResult in
            analysis = OnboardingFaceDeepAnalysisBuilder.build(from: newResult)
        }
    }

    private var signalPageDots: some View {
        HStack(spacing: 6) {
            ForEach(SignalCarouselPage.allCases) { page in
                let isSelected = currentPage == page
                ProcessCarouselPageMark(
                    isSelected: isSelected,
                    activeColor: FaceScanWhoopPalette.label,
                    inactiveColor: FaceScanWhoopPalette.label.opacity(0.22)
                )
                .onTapGesture {
                    HapticManager.shared.impact(.light)
                    withAnimation(.easeInOut(duration: 0.28)) {
                        selectedPage = page
                    }
                }
                .accessibilityLabel(page.accessibilityTitle)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(.top, 2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(AppCopy.t("Pages de signaux", en: "Signal pages"))
    }

    @ViewBuilder
    private func signalPage(_ page: SignalCarouselPage) -> some View {
        switch page {
        case .openSignals:
            unlockedCard
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        case .bloatZones:
            bloatZonesCard
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        case .priorities:
            prioritiesCard
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        case .triggers:
            triggersCard
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    // MARK: - Unlocked (rétention + cortisol)

    private var unlockedCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(openSignalsTitle)
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

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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

            VolumeCompositionGoodNewsCallout(
                text: composition.goodNewsPhrase,
                isActive: currentPage == .openSignals
            )
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

    // MARK: - Zones de gonflement (noms lisibles, notes floutées)

    private var bloatZonesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader(
                title: AppCopy.t("Où tu gonfles", en: "Where you bloat"),
                subtitle: AppCopy.t(
                    "Joues, yeux, mâchoire visibles — le reste se débloque avec le plan",
                    en: "Cheeks, eyes, jaw visible — the rest unlocks with the plan"
                ),
                locked: true
            )
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 10)

            VStack(spacing: 0) {
                ForEach(Array(analysis.lockedMetrics.enumerated()), id: \.element.id) { index, metric in
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

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .liquidGlassCard(isDark: theme.isDark)
    }

    private func lockedMetricRow(_ metric: OnboardingFaceDeepAnalysis.LockedMetric) -> some View {
        HStack(spacing: 12) {
            Image(systemName: metric.kind.systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(FaceScanWhoopPalette.label.opacity(0.75))
                .frame(width: 22)

            lockedOrPlainTitle(metric.kind.title, hidden: metric.kind.hidesName)
                .frame(maxWidth: .infinity, alignment: .leading)

            lockedScoreCluster(
                percent: metric.percent,
                zone: metric.zone,
                higherIsWorse: metric.kind.higherIsWorse
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            metric.kind.hidesName
                ? AppCopy.t("Zone verrouillée", en: "Locked zone")
                : AppCopy.t(
                    "\(metric.kind.title), note verrouillée",
                    en: "\(metric.kind.title), score locked"
                )
        )
    }

    private func lockedScoreCluster(
        percent: Int,
        zone: FaceScanIndicators.WellnessZone,
        higherIsWorse: Bool
    ) -> some View {
        HStack(spacing: 8) {
            FaceScanWhoopZoneBar(
                activeZone: zone,
                higherIsWorse: higherIsWorse,
                style: .immersive
            )
            .frame(width: 84)

            Text("\(percent)%")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(FaceScanWhoopPalette.ringColor(for: zone))
                .monospacedDigit()
                .frame(width: 44, alignment: .trailing)
        }
        .blur(radius: 8)
        .opacity(0.78)
        .compositingGroup()
        .overlay {
            Image(systemName: "lock.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(FaceScanWhoopPalette.label.opacity(0.78))
                .padding(7)
                .background {
                    Circle()
                        .fill(FaceScanWhoopPalette.card)
                        .overlay {
                            Circle()
                                .strokeBorder(FaceScanWhoopPalette.label.opacity(0.08), lineWidth: 0.5)
                        }
                }
                .allowsHitTesting(false)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Priorités (titres lisibles, diagnostics floutés)

    private var prioritiesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader(
                title: AppCopy.t("Priorités du plan", en: "Plan priorities"),
                subtitle: AppCopy.t(
                    "Ce que le protocole va viser en premier",
                    en: "What the protocol will target first"
                ),
                locked: true
            )
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 10)

            VStack(spacing: 0) {
                ForEach(Array(analysis.priorities.enumerated()), id: \.element.id) { index, item in
                    if index > 0 {
                        Divider()
                            .overlay(dividerColor)
                            .padding(.leading, 52)
                    }
                    priorityRow(item)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .liquidGlassCard(isDark: theme.isDark)
    }

    private func priorityRow(_ item: OnboardingFaceDeepAnalysis.BloatPriority) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(FaceScanWhoopPalette.label.opacity(0.75))
                .frame(width: 22)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 5) {
                lockedOrPlainTitle(item.title, hidden: item.hidesTitle)

                Text(item.note)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(FaceScanWhoopPalette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .blur(radius: 6.5)
                    .opacity(0.72)
                    .compositingGroup()
                    .overlay(alignment: .center) {
                        miniLockBadge
                    }
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            item.hidesTitle
                ? AppCopy.t("Priorité verrouillée", en: "Locked priority")
                : AppCopy.t(
                    "\(item.title), détail verrouillé",
                    en: "\(item.title), detail locked"
                )
        )
    }

    // MARK: - Déclencheurs

    private var triggersCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader(
                title: AppCopy.t("Ce qui le déclenche", en: "What triggers it"),
                subtitle: AppCopy.t(
                    "Sel et sommeil visibles — les autres leviers restent verrouillés",
                    en: "Salt and sleep visible — the other levers stay locked"
                ),
                locked: true
            )
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 10)

            VStack(spacing: 0) {
                ForEach(Array(analysis.triggers.enumerated()), id: \.element.id) { index, item in
                    if index > 0 {
                        Divider()
                            .overlay(dividerColor)
                            .padding(.leading, 52)
                    }
                    triggerRow(item)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .liquidGlassCard(isDark: theme.isDark)
    }

    private func triggerRow(_ item: OnboardingFaceDeepAnalysis.BloatTrigger) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(FaceScanWhoopPalette.label.opacity(0.75))
                .frame(width: 22)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 5) {
                lockedOrPlainTitle(item.title, hidden: item.hidesTitle)

                Text(item.note)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(FaceScanWhoopPalette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .blur(radius: 6.5)
                    .opacity(0.72)
                    .compositingGroup()
                    .overlay(alignment: .center) {
                        miniLockBadge
                    }
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            item.hidesTitle
                ? AppCopy.t("Déclencheur verrouillé", en: "Locked trigger")
                : AppCopy.t(
                    "\(item.title), détail verrouillé",
                    en: "\(item.title), detail locked"
                )
        )
    }

    // MARK: - Teaser

    private var unlockTeaser: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 13, weight: .semibold))
            Text(AppCopy.t(
                "Débloque les notes de chaque zone après l’onboarding",
                en: "Unlock each zone’s scores after onboarding"
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

    private func lockedOrPlainTitle(_ title: String, hidden: Bool) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(FaceScanWhoopPalette.label)
            .blur(radius: hidden ? 7 : 0)
            .opacity(hidden ? 0.7 : 1)
            .compositingGroup()
            .overlay {
                if hidden { miniLockBadge }
            }
            .accessibilityHidden(hidden)
    }

    private var miniLockBadge: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(FaceScanWhoopPalette.label.opacity(0.7))
            .padding(6)
            .background {
                Circle()
                    .fill(FaceScanWhoopPalette.card)
            }
            .allowsHitTesting(false)
    }

    private var lockBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: "lock.fill")
                .font(.system(size: 10, weight: .bold))
            Text(AppCopy.t("Verrouillé", en: "Locked"))
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

    private var dividerColor: Color {
        theme.isDark ? Color.white.opacity(0.08) : Color.primary.opacity(0.08)
    }
}

// MARK: - Categories

private enum SignalCarouselPage: String, CaseIterable, Identifiable, Hashable {
    case openSignals
    case bloatZones
    case priorities
    case triggers

    var id: String { rawValue }

    @MainActor
    var accessibilityTitle: String {
        switch self {
        case .openSignals: return AppCopy.t("Ce qui gonfle", en: "What's bloating")
        case .bloatZones: return AppCopy.t("Où tu gonfles", en: "Where you bloat")
        case .priorities: return AppCopy.t("Priorités du plan", en: "Plan priorities")
        case .triggers: return AppCopy.t("Ce qui le déclenche", en: "What triggers it")
        }
    }
}

// MARK: - Bonne nouvelle (rapport graisse / rétention)

private struct VolumeCompositionGoodNewsCallout: View {
    let text: String
    var isActive: Bool = true

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
        .onAppear { syncAnimations() }
        .onChange(of: isActive) { _, _ in
            syncAnimations()
        }
    }

    private func syncAnimations() {
        guard isActive else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                arrowOffset = 0
                glow = false
            }
            return
        }
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
                shape.fill(.clear)
                    .processGlassEffect(in: shape, interactive: false)
            }
            .clipShape(shape)
            .processHomeGlassCardShadow(isDark: isDark)
    }
}
