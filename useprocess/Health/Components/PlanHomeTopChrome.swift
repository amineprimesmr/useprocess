import SwiftUI

/// En-tête accueil Plan — salutation + cluster glass jours validés / statut d'activité.
struct PlanHomeTopChrome: View {
    @Binding var selectedSection: ProcessMainSection
    @Binding var selectedDate: Date
    @Binding var showSettings: Bool
    var onOpenStreak: () -> Void
    var zoomNamespace: Namespace.ID? = nil

    @EnvironmentObject private var profileService: UnifiedProfileService
    @Environment(\.appTheme) private var theme

    @Bindable private var streakStore = ProcessStreakStore.shared
    @Bindable private var planStore = WelcomePlanStore.shared
    @Bindable private var planProgressStore = ProcessPlanProgressStore.shared
    @Bindable private var activityStatusStore = ProcessActivityStatusStore.shared

    private var programProgress: PlanProgressSnapshot { planProgressStore.snapshot }

    private var greetingFirstName: String {
        profileService.currentProfile?.firstName
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var currentActivityStatus: ProcessActivityStatus {
        activityStatusStore.status(for: selectedDate)
    }

    var body: some View {
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
        .padding(.top, 14)
        .padding(.bottom, 4)
        .onAppear {
            activityStatusStore.reload()
            syncProgramProgress()
        }
        .onChange(of: profileService.currentProfile?.userId) { _, _ in
            ProcessDebloatTrajectoryStore.shared.reload()
            activityStatusStore.reload()
            syncProgramProgress()
        }
        .onChange(of: planStore.plan?.id) { _, _ in
            syncProgramProgress()
        }
    }

    private func syncProgramProgress() {
        ProcessDebloatTrajectoryStore.shared.sync(from: planStore.plan)
        planProgressStore.reload(plan: planStore.plan)
    }

    private var homeGreeting: PlanHomeGreeting {
        PlanHomeGreetingBuilder.make(firstName: greetingFirstName)
    }

    private enum GlassClusterMetrics {
        static let streakTileWidth: CGFloat = 54
        static let tileSize: CGFloat = 50
        static let tileCornerRadius: CGFloat = 25
        static let statusIconSize: CGFloat = 34
        static let spacing: CGFloat = 22
        static let mergeOffset: CGFloat = -22
        static let iconSize: CGFloat = 15

        static var tileShape: RoundedRectangle {
            RoundedRectangle(cornerRadius: tileCornerRadius, style: .continuous)
        }
    }

    @ViewBuilder
    private var headerActionsCluster: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: GlassClusterMetrics.spacing) {
                HStack(spacing: GlassClusterMetrics.spacing) {
                    Button(action: openStreak) {
                        streakGlassTile
                            .contentShape(GlassClusterMetrics.tileShape)
                    }
                    .buttonStyle(ProcessGlassPressStyle())
                    .zIndex(1)
                    .accessibilityLabel("Jours validés, \(streakStore.displayValidatedDays)")

                    Button(action: openSettings) {
                        activityStatusGlassTile
                            .contentShape(Circle())
                    }
                    .buttonStyle(ProcessGlassPressStyle())
                    .offset(x: GlassClusterMetrics.mergeOffset, y: 0.0)
                    .zIndex(0)
                    .processZoomSource(id: .settings, namespace: zoomNamespace)
                    .accessibilityLabel("Paramètres, statut \(currentActivityStatus.title)")
                }
            }
        } else {
            HStack(spacing: 10) {
                Button(action: openStreak) {
                    legacyStreakButton
                        .contentShape(Capsule(style: .continuous))
                }
                .buttonStyle(ProcessGlassPressStyle())
                .zIndex(1)
                .accessibilityLabel("Jours validés, \(streakStore.displayValidatedDays)")

                Button(action: openSettings) {
                    legacyActivityStatusButton
                        .contentShape(Circle())
                }
                .buttonStyle(ProcessGlassPressStyle())
                .zIndex(0)
                .processZoomSource(id: .settings, namespace: zoomNamespace)
                .accessibilityLabel("Paramètres, statut \(currentActivityStatus.title)")
            }
        }
    }

    @available(iOS 26.0, *)
    private var streakGlassTile: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: GlassClusterMetrics.iconSize, weight: .semibold))
                .foregroundStyle(streakFlameColor)

            Text("\(streakStore.displayValidatedDays)")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(theme.primaryText)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(width: GlassClusterMetrics.streakTileWidth, height: GlassClusterMetrics.tileSize)
        .glassEffect(ProcessGlass.regular, in: GlassClusterMetrics.tileShape)
    }

    @available(iOS 26.0, *)
    private var activityStatusGlassTile: some View {
        ProcessActivityStatusBadge(
            status: currentActivityStatus,
            size: GlassClusterMetrics.statusIconSize,
            iconSize: 15
        )
        .frame(width: GlassClusterMetrics.tileSize, height: GlassClusterMetrics.tileSize)
        .glassEffect(ProcessGlass.regular, in: Circle())
    }

    private var legacyStreakButton: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(streakFlameColor)
            Text("\(streakStore.displayValidatedDays)")
                .font(.system(size: 15, weight: .bold))
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .processGlassCircle(interactive: true)
    }

    private var legacyActivityStatusButton: some View {
        ProcessActivityStatusBadge(
            status: currentActivityStatus,
            size: 36,
            iconSize: 16
        )
        .frame(width: 44, height: 44)
        .processGlassCircle(interactive: true)
    }

    private var streakFlameColor: Color {
        streakStore.displayValidatedDays > 0 ? ProcessStreakPalette.flame : theme.secondaryText.opacity(0.65)
    }

    private func openSettings() {
        HapticManager.shared.impact(.light)
        showSettings = true
    }

    private func openStreak() {
        onOpenStreak()
    }
}

// MARK: - Progression programme

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
        .accessibilityLabel(
            "\(remainingLabel), \(Int(fillProgress * 100)) pour cent du programme"
        )
    }

    private var remainingLabel: String {
        let days = progress.remainingProgramDays
        guard days > 0 else { return "Terminé" }
        return "\(days) j restant\(days > 1 ? "s" : "")"
    }

    private var progressTrack: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(theme.primaryText.opacity(theme.isDark ? 0.10 : 0.08))

                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.48, green: 0.93, blue: 0.68),
                                Color(red: 0.22, green: 0.72, blue: 0.48)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(4, geometry.size.width * fillProgress))
                    .animation(.spring(response: 0.5, dampingFraction: 0.82), value: fillProgress)
            }
        }
    }
}

// MARK: - Salutation accueil

private struct PlanHomeGreetingLabel: View {
    let greeting: PlanHomeGreeting

    @Environment(\.appTheme) private var theme

    private var greetingGradient: LinearGradient {
        if theme.isDark {
            LinearGradient(
                colors: [
                    Color.white,
                    Color.white.opacity(0.58)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.92),
                    Color.black.opacity(0.42)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    var body: some View {
        Text(greeting.line)
            .font(.system(size: 28, weight: .bold))
            .foregroundStyle(greetingGradient)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
