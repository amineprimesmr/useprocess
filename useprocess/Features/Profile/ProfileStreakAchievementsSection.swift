import SwiftUI

// MARK: - Design tokens (réf. Streak & Achievements)

private enum ProfileStreakDesign {
    static var accent: Color { ProcessStreakPalette.flame }
    static var accentDeep: Color { ProcessStreakPalette.flameDeep }
    static var accentGlow: Color { ProcessStreakPalette.flameGlow }
    static let missedFill = Color(red: 0.17, green: 0.17, blue: 0.18)
    static let pillHeight: CGFloat = 52
    static let statCardRadius: CGFloat = 18
}

// MARK: - Section principale

struct ProfileStreakAchievementsSection: View {
    @Binding var selectedDate: Date
    /// Pause l’anim hors onglet / app inactive — la flamme bouge même si streak = 0.
    var isPlaybackActive: Bool = true

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Bindable private var streakStore = ProcessStreakStore.shared
    @Bindable private var planStore = WelcomePlanStore.shared
    @Bindable private var planProgressStore = ProcessPlanProgressStore.shared
    @Bindable private var trajectoryStore = ProcessDebloatTrajectoryStore.shared
    @Bindable private var eveningStore = ProcessEveningCheckInStore.shared

    @State private var heroAppeared = false
    @State private var statsAppeared = false
    @State private var glowPulse = false

    private var snapshot: ProcessStreakSnapshot { streakStore.snapshot }
    private var progress: PlanProgressSnapshot { planProgressStore.snapshot }
    private var flameShouldAnimate: Bool {
        isPlaybackActive && scenePhase == .active
    }

    private var hasSubmittedToday: Bool {
        eveningStore.hasSubmittedToday
    }

    private var programDays: [ProfileProgramStreakDay] {
        ProcessStreakStore.buildProgramStreakWindow(
            plan: planStore.plan,
            progress: progress,
            recordsByDay: trajectoryStore.allRecordsByDay
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            sectionHeader

            streakHeroBlock
                .opacity(heroAppeared ? 1 : 0)
                .offset(y: heroAppeared ? 0 : 18)

            if !programDays.isEmpty {
                programWeekTracker
                    .opacity(heroAppeared ? 1 : 0)
                    .offset(y: heroAppeared ? 0 : 12)
            }

            statsGrid
                .opacity(statsAppeared ? 1 : 0)
                .offset(y: statsAppeared ? 0 : 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, ProfileTheme.horizontalPadding)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .onAppear {
            refreshStores()
            runEntranceAnimations()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            refreshStores()
        }
        .onChange(of: trajectoryStore.snapshot.totalValidatedDays) { _, _ in
            streakStore.sync(from: planStore.plan)
        }
    }

    private func refreshStores() {
        ProcessDebloatTrajectoryStore.shared.reload()
        ProcessDebloatTrajectoryStore.shared.sync(from: planStore.plan)
        ProcessPlanProgressStore.shared.reload(plan: planStore.plan)
        streakStore.sync(from: planStore.plan)
    }

    private func runEntranceAnimations() {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
            heroAppeared = true
        }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.82).delay(0.08)) {
            statsAppeared = true
        }
        glowPulse = true
    }

    private var sectionHeader: some View {
        VStack(spacing: 6) {
            Text("Streak")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(theme.primaryText)
                .frame(maxWidth: .infinity)

            if progress.hasPlan {
                Text(AppCopy.t("Programme debloat · Jour \(progress.elapsedProgramDays)/\(progress.totalProgramDays)", en: "Debloat Program · Day \(progress.elapsedProgramDays)/\(progress.totalProgramDays)"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.secondaryText)
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Hero flamme

    private var streakHeroBlock: some View {
        streakHero
        .frame(maxWidth: .infinity)
        .background(alignment: .top) {
            ProfileStreakHeroGlow(pulse: glowPulse)
                .frame(maxWidth: .infinity)
                .frame(height: 340)
                .offset(y: 8)
                .allowsHitTesting(false)
        }
    }

    private var streakHero: some View {
        VStack(spacing: 14) {
            ZStack {
                TimelineView(
                    .animation(
                        minimumInterval: 1.0 / 30.0,
                        paused: !flameShouldAnimate
                    )
                ) { timeline in
                    ProfileAnimatedFlameView(
                        time: timeline.date.timeIntervalSinceReferenceDate,
                        isActive: flameShouldAnimate
                    )
                }

                VStack(spacing: 2) {
                    ProfileStreakReliefNumber(value: snapshot.currentStreak)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: snapshot.currentStreak)

                    Text(streakDayLabel)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.82))
                        .shadow(color: .black.opacity(0.62), radius: 10, y: 3)
                        .shadow(color: .black.opacity(0.38), radius: 18, y: 0)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background {
                            Capsule(style: .continuous)
                                .fill(Color.black.opacity(0.22))
                                .blur(radius: 8)
                        }
                }
                .offset(y: 10)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 248)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(snapshot.currentStreak) \(streakDayLabel)")

            consistencyBadge
        }
        .frame(maxWidth: .infinity)
    }

    private var streakDayLabel: String {
        snapshot.currentStreak <= 1
            ? AppCopy.t("jour de suite", en: "day in a row")
            : AppCopy.t("jours de suite", en: "days in a row")
    }

    private var showsCountdownBadge: Bool {
        if snapshot.isTodayComplete && snapshot.currentStreak == 0 { return false }
        if !snapshot.isTodayComplete, !hasSubmittedToday { return true }
        return snapshot.currentStreak == 0
    }

    private var consistencyBadge: some View {
        let capsule = Capsule(style: .continuous)

        return TimelineView(.periodic(from: .now, by: 30)) { context in
            let message = consistencyMessage(at: context.date)
            let isCountdown = showsCountdownBadge

            HStack(spacing: isCountdown ? 8 : 6) {
                Text(consistencyEmoji)
                    .font(.system(size: isCountdown ? 16 : 14))
                Text(message)
                    .font(.system(size: isCountdown ? 15 : 13, weight: .semibold))
                    .foregroundStyle(theme.primaryText)
                    .minimumScaleFactor(0.85)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, isCountdown ? 18 : 14)
            .padding(.vertical, isCountdown ? 11 : 8)
            .processGlassEffect(in: capsule, interactive: false)
            .animation(.easeInOut(duration: 0.25), value: message)
        }
    }

    private var consistencyEmoji: String {
        if snapshot.isTodayComplete && snapshot.currentStreak == 0 { return "✅" }
        if showsCountdownBadge { return "⏳" }
        switch snapshot.currentStreak {
        case 0: return "💪"
        case 1...2: return "🔥"
        case 3...6: return "✨"
        case 7...13: return "😊"
        default: return "🏆"
        }
    }

    private func consistencyMessage(at date: Date = Date()) -> String {
        if snapshot.isTodayComplete && snapshot.currentStreak == 0 {
            return AppCopy.t("Premier jour validé !", en: "First day completed!")
        }
        // Compte à rebours tant que le check du jour n'est pas validé.
        if !snapshot.isTodayComplete, !hasSubmittedToday {
            return ProcessEveningCheckInSchedule.streakLaunchMessage(from: date)
        }
        switch snapshot.currentStreak {
        case 0:
            return ProcessEveningCheckInSchedule.streakLaunchMessage(from: date)
        case 1...2:
            return AppCopy.t("Belle régularité !", en: "Great consistency!")
        case 3...6:
            return AppCopy.t("Tu construis l'habitude", en: "You're building the habit")
        case 7...13:
            return AppCopy.t("Régularité incroyable !", en: "Incredible consistency!")
        default:
            return AppCopy.t("Mode Process activé", en: "Process mode activated")
        }
    }

    // MARK: - Semaine programme

    private var streakRange: ClosedRange<Int>? {
        guard let todayIdx = programDays.firstIndex(where: { $0.isToday }) else {
            guard let lastComplete = programDays.lastIndex(where: { $0.isComplete }) else { return nil }
            return lastComplete...lastComplete
        }
        var start = todayIdx
        var end = todayIdx
        while start > 0, programDays[start - 1].isComplete {
            start -= 1
        }
        while end < programDays.count - 1, programDays[end + 1].isComplete {
            end += 1
        }
        return start...end
    }

    private var programWeekTracker: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                ForEach(programDays) { day in
                    Button {
                        HapticManager.shared.selection()
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                            selectedDate = day.date
                        }
                    } label: {
                        Text(day.label)
                            .font(.system(size: 11, weight: day.isToday ? .bold : .medium))
                            .foregroundStyle(dayLabelColor(day))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.processPlain)
                }
            }

            GeometryReader { geometry in
                let count = max(programDays.count, 1)
                let columnWidth = geometry.size.width / CGFloat(count)

                ZStack(alignment: .leading) {
                    if let range = streakRange {
                        Capsule(style: .continuous)
                            .fill(ProfileStreakDesign.accent)
                            .frame(
                                width: columnWidth * CGFloat(range.count) + 4,
                                height: ProfileStreakDesign.pillHeight
                            )
                            .offset(x: columnWidth * CGFloat(range.lowerBound) - 2)
                            .animation(.spring(response: 0.45, dampingFraction: 0.82), value: range.lowerBound)
                            .animation(.spring(response: 0.45, dampingFraction: 0.82), value: range.upperBound)
                    }

                    HStack(spacing: 0) {
                        ForEach(Array(programDays.enumerated()), id: \.element.id) { index, day in
                            programDayColumn(
                                day,
                                inActivePill: streakRange?.contains(index) ?? false
                            )
                            .frame(width: columnWidth)
                        }
                    }
                }
            }
            .frame(height: ProfileStreakDesign.pillHeight)
        }
    }

    private func dayLabelColor(_ day: ProfileProgramStreakDay) -> Color {
        if day.isToday { return theme.primaryText }
        if Calendar.current.isDate(day.date, inSameDayAs: selectedDate) {
            return ProfileStreakDesign.accent
        }
        return theme.secondaryText.opacity(0.75)
    }

    @ViewBuilder
    private func programDayColumn(_ day: ProfileProgramStreakDay, inActivePill: Bool) -> some View {
        Group {
            if day.isFuture {
                Circle()
                    .strokeBorder(Color.white.opacity(theme.isDark ? 0.18 : 0.22), lineWidth: 1.5)
                    .frame(width: 28, height: 28)
            } else if day.isComplete {
                ZStack {
                    Circle()
                        .fill(inActivePill ? Color.black.opacity(0.22) : ProfileStreakDesign.missedFill)
                        .frame(width: 28, height: 28)
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(inActivePill ? Color.black.opacity(0.85) : ProfileStreakDesign.accent)
                }
            } else if day.isToday {
                ProfileStreakTodaySpinner(onPill: inActivePill)
            } else if day.isMissed {
                ZStack {
                    Circle()
                        .fill(ProfileStreakDesign.missedFill)
                        .frame(width: 28, height: 28)
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.35))
                }
            } else {
                Circle()
                    .fill(theme.secondaryText.opacity(0.18))
                    .frame(width: 8, height: 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.38, dampingFraction: 0.78), value: day.isComplete)
    }

    // MARK: - Stats

    private var statsGrid: some View {
        HStack(spacing: 10) {
            statCard(icon: "flame.fill", value: snapshot.currentStreak, label: AppCopy.t("Série actuelle", en: "Current Streak"), accent: ProfileStreakDesign.accent)
            statCard(icon: "rosette", value: snapshot.longestStreak, label: AppCopy.t("Meilleure série", en: "Best Streak"))
            statCard(icon: "checkmark.circle.fill", value: snapshot.totalCompletedDays, label: AppCopy.t("Jours validés", en: "Completed Days"))
        }
    }

    private func statCard(icon: String, value: Int, label: String, accent: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(accent ?? theme.secondaryText.opacity(0.85))

            Text("\(value)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(theme.primaryText)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.spring(response: 0.4, dampingFraction: 0.82), value: value)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.secondaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(statCardBackground)
    }

    @ViewBuilder
    private var statCardBackground: some View {
        RoundedRectangle(cornerRadius: ProfileStreakDesign.statCardRadius, style: .continuous)
            .fill(theme.isDark ? Color.white.opacity(0.06) : Color.white.opacity(0.72))
            .overlay {
                RoundedRectangle(cornerRadius: ProfileStreakDesign.statCardRadius, style: .continuous)
                    .strokeBorder(
                        theme.isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.06),
                        lineWidth: 1
                    )
            }
    }
}

private struct ProfileStreakTodaySpinner: View {
    var onPill: Bool = true
    @State private var rotation: Double = 0

    var body: some View {
        let track = onPill ? Color.black.opacity(0.12) : Color.primary.opacity(0.14)
        let arc = onPill ? Color.black.opacity(0.55) : ProfileStreakDesign.accent

        ZStack {
            Circle()
                .strokeBorder(track, lineWidth: 2)
                .frame(width: 28, height: 28)

            Circle()
                .trim(from: 0, to: 0.28)
                .stroke(arc, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                .frame(width: 28, height: 28)
                .rotationEffect(.degrees(rotation))
        }
        .onAppear {
            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

private struct ProfileStreakReliefNumber: View {
    let value: Int

    private var text: String { "\(value)" }

    var body: some View {
        ZStack {
            Text(text)
                .foregroundStyle(Color.black.opacity(0.50))
                .offset(x: 0, y: 4)

            Text(text)
                .foregroundStyle(ProcessStreakPalette.flameDeep.opacity(0.38))
                .offset(x: 1.5, y: 2.5)

            Text(text)
                .foregroundStyle(Color.white.opacity(0.18))
                .offset(x: -1.2, y: -1.4)

            Text(text)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.62),
                            Color.white.opacity(0.38)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .font(.system(size: 72, weight: .bold, design: .rounded))
        .monospacedDigit()
        .shadow(color: Color.black.opacity(0.22), radius: 8, y: 4)
    }
}

private struct ProfileStreakHeroGlow: View {
    let pulse: Bool

    var body: some View {
        ZStack {
            EllipticalGradient(
                stops: [
                    .init(color: ProcessStreakPalette.flameGlow.opacity(0.13), location: 0.0),
                    .init(color: ProcessStreakPalette.flame.opacity(0.05), location: 0.34),
                    .init(color: ProcessStreakPalette.flameDeep.opacity(0.015), location: 0.58),
                    .init(color: Color.clear, location: 1.0),
                ],
                center: .center,
                startRadiusFraction: 0,
                endRadiusFraction: 0.62
            )

            EllipticalGradient(
                stops: [
                    .init(color: Color.white.opacity(0.07), location: 0.0),
                    .init(color: ProcessStreakPalette.flameGlow.opacity(0.04), location: 0.42),
                    .init(color: Color.clear, location: 1.0),
                ],
                center: UnitPoint(x: 0.5, y: 0.40),
                startRadiusFraction: 0,
                endRadiusFraction: 0.48
            )
        }
        .scaleEffect(x: 0.84, y: 1.12)
        .blur(radius: 26)
        .scaleEffect(pulse ? 1.02 : 0.98)
        .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: pulse)
        .allowsHitTesting(false)
    }
}

// MARK: - Flamme animée

private struct ProfileAnimatedFlameView: View {
    let time: TimeInterval
    var isActive: Bool = true

    private let canvasWidth: CGFloat = 210
    private let canvasHeight: CGFloat = 252

    var body: some View {
        ZStack {
            ambientGlowLayer
                .blendMode(.plusLighter)
                .allowsHitTesting(false)

            flameLayer(
                phase: 0,
                widthScale: 1.18,
                heightScale: 1.12,
                blur: 36,
                opacity: 0.32,
                colors: [
                    ProfileStreakDesign.accentGlow.opacity(0.45),
                    ProfileStreakDesign.accentDeep.opacity(0.03)
                ]
            )
            .blendMode(.plusLighter)

            flameLayer(
                phase: 1.35,
                widthScale: 1.08,
                heightScale: 1.06,
                blur: 24,
                opacity: 0.46,
                colors: [
                    ProfileStreakDesign.accentGlow.opacity(0.58),
                    ProfileStreakDesign.accentDeep.opacity(0.10)
                ]
            )
            .blendMode(.plusLighter)

            flameLayer(
                phase: 2.7,
                widthScale: 0.96,
                heightScale: 1.0,
                blur: 14,
                opacity: 0.72,
                colors: [
                    ProfileStreakDesign.accent.opacity(0.88),
                    ProfileStreakDesign.accentDeep.opacity(0.38)
                ]
            )

            flameLayer(
                phase: 4.1,
                widthScale: 0.68,
                heightScale: 0.82,
                blur: 8,
                opacity: 0.88,
                colors: [
                    Color.white.opacity(0.90),
                    ProfileStreakDesign.accent.opacity(0.82)
                ]
            )

            flickerTongue(phase: 0.8, offset: -0.18, scale: 0.38)
            flickerTongue(phase: 2.2, offset: 0.14, scale: 0.34)
            flickerTongue(phase: 3.6, offset: 0.02, scale: 0.28)
        }
        .frame(width: canvasWidth, height: canvasHeight)
        .accessibilityHidden(true)
        .opacity(isActive ? 1 : 0.92)
    }

    @ViewBuilder
    private var ambientGlowLayer: some View {
        Canvas { context, size in
            let rect = flameDrawRect(in: size, widthScale: 1.22, heightScale: 1.14)
            let path = ProfileFlamePath.make(in: rect, time: time, phase: 0.2)
            context.fill(
                path,
                with: .radialGradient(
                    Gradient(colors: [
                        ProfileStreakDesign.accentGlow.opacity(0.38),
                        ProfileStreakDesign.accentDeep.opacity(0.04),
                        Color.clear
                    ]),
                    center: CGPoint(x: rect.midX, y: rect.midY + rect.height * 0.08),
                    startRadius: 8,
                    endRadius: max(rect.width, rect.height) * 0.95
                )
            )
        }
        .blur(radius: 52)
        .opacity(0.42)
        .scaleEffect(x: 0.92, y: 1.08)
    }

    private func flameDrawRect(in size: CGSize, widthScale: CGFloat, heightScale: CGFloat) -> CGRect {
        let insetX = size.width * (1 - widthScale) / 2
        let insetY = size.height * (1 - heightScale)
        return CGRect(
            x: insetX,
            y: insetY * 0.22,
            width: size.width * widthScale,
            height: size.height * heightScale
        )
    }

    @ViewBuilder
    private func flameLayer(
        phase: Double,
        widthScale: CGFloat,
        heightScale: CGFloat,
        blur: CGFloat,
        opacity: Double,
        colors: [Color]
    ) -> some View {
        Canvas { context, size in
            let rect = flameDrawRect(in: size, widthScale: widthScale, heightScale: heightScale)
            let path = ProfileFlamePath.make(in: rect, time: time, phase: phase)

            context.fill(
                path,
                with: .linearGradient(
                    Gradient(colors: colors),
                    startPoint: CGPoint(x: rect.midX, y: rect.maxY),
                    endPoint: CGPoint(x: rect.midX, y: rect.minY)
                )
            )
        }
        .blur(radius: blur)
        .opacity(opacity)
    }

    @ViewBuilder
    private func flickerTongue(phase: Double, offset: CGFloat, scale: CGFloat) -> some View {
        Canvas { context, size in
            let baseWidth = size.width * scale
            let baseHeight = size.height * scale * 0.78
            let centerX = size.width * (0.5 + offset) + CGFloat(sin(time * 5.4 + phase)) * size.width * 0.035
            let rect = CGRect(
                x: centerX - baseWidth / 2,
                y: size.height * 0.04 + CGFloat(sin(time * 4.1 + phase)) * 5,
                width: baseWidth,
                height: baseHeight
            )
            let path = ProfileFlamePath.make(in: rect, time: time, phase: phase + 1.7, split: 0.62)

            context.fill(
                path,
                with: .linearGradient(
                    Gradient(colors: [
                        Color.white.opacity(0.82),
                        ProfileStreakDesign.accent.opacity(0.28)
                    ]),
                    startPoint: CGPoint(x: rect.midX, y: rect.maxY),
                    endPoint: CGPoint(x: rect.midX, y: rect.minY)
                )
            )
        }
        .blur(radius: 6)
        .opacity(0.5 + sin(time * 6.2 + phase) * 0.2)
        .blendMode(.plusLighter)
    }
}

private enum ProfileFlamePath {
    static func make(
        in rect: CGRect,
        time: TimeInterval,
        phase: Double,
        split: Double = 1
    ) -> Path {
        let width = rect.width
        let height = rect.height
        let centerX = rect.midX
        let bottom = rect.maxY

        let swayPrimary = sin(time * 4.4 + phase) * width * 0.06 * split
        let swaySecondary = sin(time * 6.1 + phase * 1.4) * width * 0.042 * split
        let swayTertiary = cos(time * 3.3 + phase * 0.8) * width * 0.038 * split
        let stretch = sin(time * 2.8 + phase * 0.6) * height * 0.06

        let baseHalf = width * 0.20
        let bellyHalf = width * 0.44
        let bellyY = bottom - height * 0.52 + sin(time * 3.2 + phase) * height * 0.02

        let leftTipX = centerX - width * 0.14 + swayPrimary
        let rightTipX = centerX + width * 0.12 + swaySecondary
        let centerTipX = centerX + swayTertiary * 0.4
        let leftTipY = rect.minY + stretch + height * 0.04
        let rightTipY = rect.minY + stretch * 0.7 + height * 0.07
        let centerTipY = rect.minY + stretch + height * 0.02

        let leftMidX = centerX - bellyHalf * 0.72 + swaySecondary
        let rightMidX = centerX + bellyHalf * 0.78 + swayTertiary
        let midY = bellyY - height * 0.08

        var path = Path()
        path.move(to: CGPoint(x: centerX - baseHalf, y: bottom))
        path.addCurve(
            to: CGPoint(x: leftTipX, y: leftTipY),
            control1: CGPoint(x: centerX - bellyHalf, y: bottom - height * 0.18),
            control2: CGPoint(x: leftMidX, y: midY)
        )
        path.addQuadCurve(
            to: CGPoint(x: centerTipX, y: centerTipY),
            control: CGPoint(x: centerX - width * 0.04 + swayPrimary * 0.3, y: rect.minY + height * 0.12)
        )
        path.addQuadCurve(
            to: CGPoint(x: rightTipX, y: rightTipY),
            control: CGPoint(x: centerX + width * 0.06 + swaySecondary * 0.25, y: rect.minY + height * 0.14)
        )
        path.addCurve(
            to: CGPoint(x: centerX + baseHalf, y: bottom),
            control1: CGPoint(x: rightMidX, y: midY + height * 0.04),
            control2: CGPoint(x: centerX + bellyHalf * 0.92, y: bottom - height * 0.16)
        )
        path.addQuadCurve(
            to: CGPoint(x: centerX - baseHalf, y: bottom),
            control: CGPoint(x: centerX, y: bottom - height * 0.035)
        )
        path.closeSubpath()
        return path
    }
}
