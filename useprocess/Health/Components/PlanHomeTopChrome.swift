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
    @Binding var showCalendar: Bool
    var plan: FaceOriginPlan? = nil
    var calendarZoomNamespace: Namespace.ID? = nil
    var placement: PlanHomeTopChromePlacement = .embedded
    /// Titre compact affiché dans la toolbar quand la salutation scroll hors écran.
    @Binding var compactToolbarTitle: String?
    /// 0 = fond transparent · 1 = flou léger au scroll (barre sticky uniquement).
    var scrollBlurProgress: CGFloat = 0
    var onOpenStreak: () -> Void

    @Namespace private var internalCalendarZoomNamespace

    @EnvironmentObject private var profileService: UnifiedProfileService
    @Environment(\.appTheme) private var theme

    @Bindable private var streakStore = ProcessStreakStore.shared
    @Bindable private var planStore = WelcomePlanStore.shared
    @Bindable private var planProgressStore = ProcessPlanProgressStore.shared

    private var programProgress: PlanProgressSnapshot { planProgressStore.snapshot }

    private var greetingFirstName: String {
        profileService.currentProfile?.firstName
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    init(
        selectedSection: Binding<ProcessMainSection>,
        selectedDate: Binding<Date>,
        showCalendar: Binding<Bool>,
        plan: FaceOriginPlan? = nil,
        placement: PlanHomeTopChromePlacement = .embedded,
        compactToolbarTitle: Binding<String?> = .constant(nil),
        calendarZoomNamespace: Namespace.ID? = nil,
        scrollBlurProgress: CGFloat = 0,
        onOpenStreak: @escaping () -> Void
    ) {
        _selectedSection = selectedSection
        _selectedDate = selectedDate
        _showCalendar = showCalendar
        self.plan = plan
        self.placement = placement
        _compactToolbarTitle = compactToolbarTitle
        self.calendarZoomNamespace = calendarZoomNamespace
        self.scrollBlurProgress = scrollBlurProgress
        self.onOpenStreak = onOpenStreak
    }

    private var resolvedCalendarZoomNamespace: Namespace.ID {
        calendarZoomNamespace ?? internalCalendarZoomNamespace
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
        .fullScreenCover(isPresented: $showCalendar) {
            PlanProgramCalendarView(
                selectedDate: $selectedDate,
                plan: plan ?? planStore.plan
            )
            .processZoomTransition(id: .planCalendar, namespace: resolvedCalendarZoomNamespace)
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
        PlanHomeGreetingBuilder.make(firstName: greetingFirstName)
    }

    @ViewBuilder
    private var headerActionsCluster: some View {
        PlanHomeToolbarActions(
            showCalendar: $showCalendar,
            calendarZoomNamespace: resolvedCalendarZoomNamespace,
            onOpenStreak: onOpenStreak
        )
    }
}

// MARK: - Actions toolbar (streak + calendrier)

struct PlanHomeToolbarActions: View {
    @Binding var showCalendar: Bool
    var calendarZoomNamespace: Namespace.ID
    var onOpenStreak: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: GlassClusterMetrics.spacing) {
                HStack(spacing: GlassClusterMetrics.spacing) {
                    Button(action: openCalendar) {
                        Image(systemName: "calendar")
                            .font(.system(size: GlassClusterMetrics.iconSize, weight: .semibold))
                            .foregroundStyle(theme.primaryText)
                            .frame(width: GlassClusterMetrics.tileSize, height: GlassClusterMetrics.tileSize)
                            .contentShape(Circle())
                    }
                    .processGlassButton(in: Circle())
                    .offset(x: GlassClusterMetrics.mergeOffset, y: 0)
                    .zIndex(0)
                    .processZoomSource(id: .planCalendar, namespace: calendarZoomNamespace)
                    .accessibilityLabel(AppCopy.t(
                        "Calendrier, choisir une date",
                        en: "Calendar, choose a date"
                    ))

                    PlanHomeCheckInButton(action: openStreak)
                        .zIndex(1)
                }
            }
        } else {
            HStack(spacing: 6) {
                Button(action: openCalendar) {
                    Image(systemName: "calendar")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(theme.primaryText)
                        .frame(width: 40, height: 40)
                        .contentShape(Circle())
                }
                .processGlassButton(in: Circle())
                .processZoomSource(id: .planCalendar, namespace: calendarZoomNamespace)
                .accessibilityLabel(AppCopy.t(
                    "Calendrier, choisir une date",
                    en: "Calendar, choose a date"
                ))

                PlanHomeCheckInButton(action: openStreak)
            }
        }
    }

    private enum GlassClusterMetrics {
        static let tileSize: CGFloat = 44
        static let spacing: CGFloat = 10
        static let mergeOffset: CGFloat = 14
        static let iconSize: CGFloat = 14
    }

    private func openCalendar() {
        HapticManager.shared.impact(.light)
        withAnimation(ProcessZoomTransitionID.presentationSpring) {
            showCalendar = true
        }
    }

    private func openStreak() {
        onOpenStreak()
    }
}

/// Bouton check du jour — pastille rouge à partir de 21h tant que le bilan n’est pas validé.
struct PlanHomeCheckInButton: View {
    var action: () -> Void

    @Environment(\.appTheme) private var theme
    @Bindable private var streakStore = ProcessStreakStore.shared
    @Bindable private var eveningStore = ProcessEveningCheckInStore.shared

    private enum Metrics {
        static let tileSize: CGFloat = 44
        static let iconSize: CGFloat = 12
        static let badgeSize: CGFloat = 10
    }

    private var flameColor: Color {
        streakStore.displayStreak > 0 ? ProcessStreakPalette.flame : theme.secondaryText.opacity(0.65)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 2) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: Metrics.iconSize, weight: .semibold))
                    .foregroundStyle(flameColor)

                Text("\(streakStore.displayStreak)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(theme.primaryText)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
            }
            .frame(width: Metrics.tileSize, height: Metrics.tileSize)
            .contentShape(Circle())
            .overlay(alignment: .topTrailing) {
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    if !eveningStore.hasSubmittedToday,
                       ProcessEveningCheckInSchedule.isBilanWindowOpen(now: context.date) {
                        attentionBadge
                    }
                }
            }
        }
        .processGlassButton(in: Circle())
        .accessibilityLabel(AppCopy.t(
            "Check du jour, série \(streakStore.displayStreak) jours",
            en: "Daily check-in, \(streakStore.displayStreak)-day streak"
        ))
        .accessibilityValue(checkInAccessibilityValue)
    }

    private var checkInAccessibilityValue: String {
        if eveningStore.hasSubmittedToday {
            return AppCopy.t("Check fait", en: "Check-in done")
        }
        if ProcessEveningCheckInSchedule.isBilanWindowOpen() {
            return AppCopy.t("Bilan du soir à faire", en: "Evening check-in needed")
        }
        return AppCopy.t("Bilan du soir à partir de 21h", en: "Evening check-in opens at 9 PM")
    }

    private var attentionBadge: some View {
        Circle()
            .fill(Color.red)
            .frame(width: Metrics.badgeSize, height: Metrics.badgeSize)
            .padding(7)
            .accessibilityHidden(true)
    }
}

// MARK: - Progression programme (scroll accueil)

struct PlanHomeProgramProgressSection: View {
    @Bindable private var planProgressStore = ProcessPlanProgressStore.shared
    @Bindable private var planStore = WelcomePlanStore.shared

    private var programProgress: PlanProgressSnapshot { planProgressStore.snapshot }

    var body: some View {
        Group {
            if programProgress.hasPlan {
                PlanHomeProgramProgressBar(progress: programProgress)
            }
        }
        .onAppear { reloadProgress() }
        .onChange(of: planStore.plan?.id) { _, _ in reloadProgress() }
    }

    private func reloadProgress() {
        ProcessDebloatTrajectoryStore.shared.sync(from: planStore.plan)
        planProgressStore.reload(plan: planStore.plan)
    }
}

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
