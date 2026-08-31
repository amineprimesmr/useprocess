import SwiftUI

enum PlanHomeTopChromePlacement {
    /// En-tête dans le scroll (éditeur de layout).
    case embedded
    /// Grande salutation dans le scroll — titre compact dans la toolbar au scroll.
    case scrollHeader
    /// Barre fixe en haut de l’accueil — salutation + actions.
    case stickyTopBar
}

/// En-tête accueil Plan — salutation + cluster glass jours validés / statut d'activité.
struct PlanHomeTopChrome: View {
    @Binding var selectedSection: ProcessMainSection
    @Binding var selectedDate: Date
    var plan: FaceOriginPlan? = nil
    var placement: PlanHomeTopChromePlacement = .embedded
    /// Titre compact affiché dans la toolbar quand la salutation scroll hors écran.
    @Binding var compactToolbarTitle: String?
    /// 0 = fond transparent · 1 = flou léger au scroll (barre sticky uniquement).
    var scrollBlurProgress: CGFloat = 0
    var onOpenStreak: () -> Void

    @EnvironmentObject private var profileService: UnifiedProfileService
    @Environment(\.appTheme) private var theme

    @Bindable private var streakStore = ProcessStreakStore.shared
    @Bindable private var planStore = WelcomePlanStore.shared
    @Bindable private var planProgressStore = ProcessPlanProgressStore.shared

    private var programProgress: PlanProgressSnapshot { planProgressStore.snapshot }

    init(
        selectedSection: Binding<ProcessMainSection>,
        selectedDate: Binding<Date>,
        plan: FaceOriginPlan? = nil,
        placement: PlanHomeTopChromePlacement = .embedded,
        compactToolbarTitle: Binding<String?> = .constant(nil),
        scrollBlurProgress: CGFloat = 0,
        onOpenStreak: @escaping () -> Void
    ) {
        _selectedSection = selectedSection
        _selectedDate = selectedDate
        self.plan = plan
        self.placement = placement
        _compactToolbarTitle = compactToolbarTitle
        self.scrollBlurProgress = scrollBlurProgress
        self.onOpenStreak = onOpenStreak
    }

    var body: some View {
        Group {
            switch placement {
            case .embedded:
                embeddedChrome
            case .scrollHeader:
                scrollHeaderChrome
            case .stickyTopBar:
                stickyTopBarChrome
            }
        }
        .onAppear {
            syncProgramProgress()
        }
        .onChange(of: profileService.currentProfile?.userId) { _, _ in
            syncProgramProgress()
        }
        .onChange(of: planStore.plan?.id) { _, _ in
            syncProgramProgress()
        }
    }

    private var scrollHeaderChrome: some View {
        PlanHomeGreetingLabel(greeting: homeGreeting)
            .padding(.top, 6)
            .padding(.bottom, 2)
            .onGeometryChange(for: Bool.self) {
                let height = abs($0.size.height - 5)
                let offset = $0.frame(in: .global).minY
                return -offset > height
            } action: { scrolled in
                compactToolbarTitle = scrolled ? homeGreeting.line : nil
            }
    }

    private var embeddedChrome: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                PlanHomeGreetingLabel(greeting: homeGreeting)

                if programProgress.hasPlan {
                    PlanHomeProgramProgressBar(progress: programProgress)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            headerActionsCluster
        }
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    private var stickyTopBarChrome: some View {
        HStack(alignment: .center, spacing: 12) {
            PlanHomeGreetingLabel(greeting: homeGreeting, style: .stickyTopBar)
                .layoutPriority(1)

            headerActionsCluster
        }
        .padding(.horizontal, 16)
        .padding(.top, 2)
        .padding(.bottom, 12)
        .background { stickyTopBarBackground }
    }

    @ViewBuilder
    private var stickyTopBarBackground: some View {
        let progress = min(max(scrollBlurProgress, 0), 1)

        ZStack(alignment: .bottom) {
            if progress > 0.001 {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(Double(progress) * 0.78)

                LinearGradient(
                    colors: [
                        theme.background.opacity(theme.isDark ? 0.12 : 0.08),
                        theme.background.opacity(0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .opacity(Double(progress) * 0.55)
            }

            if progress > 0.08 {
                LinearGradient(
                    colors: [
                        theme.primaryText.opacity(theme.isDark ? 0.08 : 0.05),
                        .clear
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(height: 10)
                .opacity(Double(progress))
            }
        }
        .ignoresSafeArea(edges: .top)
        .animation(.easeOut(duration: 0.22), value: progress)
    }

    private func syncProgramProgress() {
        ProcessDebloatTrajectoryStore.shared.sync(from: planStore.plan)
        planProgressStore.reload(plan: planStore.plan)
    }

    private var homeGreeting: PlanHomeGreeting {
        PlanHomeGreetingBuilder.make(profile: profileService.currentProfile)
    }

    @ViewBuilder
    private var headerActionsCluster: some View {
        PlanHomeToolbarActions(onOpenStreak: onOpenStreak)
    }
}

// MARK: - Actions toolbar (streak)

struct PlanHomeToolbarActions: View {
    var onOpenStreak: () -> Void

    var body: some View {
        PlanHomeStreakFlameButton(action: onOpenStreak)
    }
}

/// Bouton « ouvrir la page streak » — flamme animée nue, sans container liquid glass.
struct PlanHomeStreakFlameButton: View {
    var action: () -> Void

    @Environment(\.appTheme) private var theme
    @Bindable private var trajectoryStore = ProcessDebloatTrajectoryStore.shared
    @Bindable private var streakStore = ProcessStreakStore.shared

    var body: some View {
        Button(action: action) {
            HStack(spacing: 2) {
                ProfileMiniFlameIcon()
                    .overlay(alignment: .topTrailing) {
                        if !trajectoryStore.snapshot.isTodayComplete {
                            attentionBadge
                        }
                    }

                Text("\(streakStore.displayStreak)")
                    .font(.system(size: ProcessAppHeaderControlMetrics.streakNumberFontSize, weight: .bold))
                    .foregroundStyle(theme.primaryText)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.4, dampingFraction: 0.82), value: streakStore.displayStreak)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
            }
        }
        .buttonStyle(ProcessGlassPressStyle())
        .accessibilityLabel(AppCopy.t(
            "Série, \(streakStore.displayStreak) jours",
            en: "Streak, \(streakStore.displayStreak) days"
        ))
    }

    private var attentionBadge: some View {
        Circle()
            .fill(Color.red)
            .frame(width: ProcessAppHeaderControlMetrics.attentionBadgeSize, height: ProcessAppHeaderControlMetrics.attentionBadgeSize)
            .padding(5)
            .accessibilityHidden(true)
    }
}

// MARK: - Progression programme (scroll accueil)


private struct PlanHomeProgramProgressBar: View {
    let progress: PlanProgressSnapshot

    @Environment(\.appTheme) private var theme

    private var fillProgress: Double {
        min(max(progress.timeProgress, 0), 1)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            progressTrack
                .frame(width: 120, height: 5)

            Text(remainingLabel)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.secondaryText.opacity(0.85))
                .monospacedDigit()
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(AppCopy.t(
            "\(remainingLabel), \(Int(fillProgress * 100)) pour cent du programme",
            en: "\(remainingLabel), \(Int(fillProgress * 100)) percent of the program"
        ))
    }

    private var remainingLabel: String {
        let days = progress.remainingProgramDays
        guard days > 0 else { return AppCopy.done }
        return AppCopy.t(
            "\(days) j restant\(days > 1 ? "s" : "")",
            en: days == 1 ? "1 day left" : "\(days) days left"
        )
    }

    private var progressTrack: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(theme.primaryText.opacity(theme.isDark ? 0.10 : 0.08))

                Capsule(style: .continuous)
                    .fill(ProcessStreakPalette.progressGradient)
                    .frame(width: max(4, geometry.size.width * fillProgress))
                    .animation(.spring(response: 0.5, dampingFraction: 0.82), value: fillProgress)
            }
        }
    }
}

// MARK: - Salutation accueil

private struct PlanHomeGreetingLabel: View {
    enum Style {
        case embedded
        case stickyTopBar
    }

    let greeting: PlanHomeGreeting
    var style: Style = .embedded

    @Environment(\.appTheme) private var theme

    var body: some View {
        Text(greeting.line)
            .font(.system(size: style == .stickyTopBar ? 26 : 28, weight: .bold))
            .foregroundStyle(theme.primaryText)
            .multilineTextAlignment(.leading)
            .lineLimit(style == .stickyTopBar ? 1 : nil)
            .minimumScaleFactor(style == .stickyTopBar ? 0.82 : 1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: style != .stickyTopBar)
    }
}
