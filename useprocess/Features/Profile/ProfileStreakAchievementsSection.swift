import SwiftUI

// MARK: - Design tokens (réf. Streak & Achievements)

private enum ProfileStreakDesign {
    static let mint = Color(red: 0.48, green: 0.93, blue: 0.68)
    static let mintDeep = Color(red: 0.22, green: 0.72, blue: 0.48)
    static let mintGlow = Color(red: 0.38, green: 0.88, blue: 0.58)
    static let cardFill = Color(red: 0.13, green: 0.13, blue: 0.14)
    static let cardStroke = Color.white.opacity(0.06)
    static let missedFill = Color(red: 0.17, green: 0.17, blue: 0.18)
    static let pillHeight: CGFloat = 52
    static let statCardRadius: CGFloat = 18
    static let achievementRadius: CGFloat = 16
}

// MARK: - Section principale

struct ProfileStreakAchievementsSection: View {
    @Binding var selectedDate: Date

    @Environment(\.appTheme) private var theme
    @Environment(\.scenePhase) private var scenePhase
    @Bindable private var streakStore = ProcessStreakStore.shared
    @Bindable private var planStore = WelcomePlanStore.shared
    @Bindable private var planProgressStore = ProcessPlanProgressStore.shared
    @Bindable private var trajectoryStore = ProcessDebloatTrajectoryStore.shared

    @State private var heroAppeared = false
    @State private var statsAppeared = false
    @State private var glowPulse = false

    private var snapshot: ProcessStreakSnapshot { streakStore.snapshot }
    private var progress: PlanProgressSnapshot { planProgressStore.snapshot }

    private var programDays: [ProfileProgramStreakDay] {
        ProcessStreakStore.buildProgramStreakWindow(
            plan: planStore.plan,
            progress: progress,
            recordsByDay: trajectoryStore.allRecordsByDay
        )
    }

    private var unlockedAchievements: Int {
        ProcessStreakMilestone.catalog.filter {
            snapshot.longestStreak >= $0.days || snapshot.totalCompletedDays >= $0.days
        }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            sectionHeader

            streakHero
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

            achievementsSection
                .opacity(statsAppeared ? 1 : 0)
                .offset(y: statsAppeared ? 0 : 10)
        }
        .padding(.horizontal, ProfileTheme.horizontalPadding)
        .padding(.top, ProcessMainChromeMetrics.topSafeInset + 48)
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
            Text("Streak & succès")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(theme.primaryText)
                .frame(maxWidth: .infinity)

            if progress.hasPlan {
                Text("Programme debloat · Jour \(progress.elapsedProgramDays)/\(progress.totalProgramDays)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.secondaryText)
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Hero flamme

    private var streakHero: some View {
        VStack(spacing: 14) {
            ZStack {
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                ProfileStreakDesign.mintGlow.opacity(0.42),
                                ProfileStreakDesign.mintDeep.opacity(0.14),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 4,
                            endRadius: 150
                        )
                    )
                    .frame(width: 300, height: 320)
                    .blur(radius: 42)
                    .scaleEffect(glowPulse ? 1.05 : 0.92)
                    .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: glowPulse)
                    .allowsHitTesting(false)

                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: scenePhase != .active)) { timeline in
                    ProfileAnimatedFlameView(
                        time: timeline.date.timeIntervalSinceReferenceDate,
                        isActive: scenePhase == .active
                    )
                }
                .frame(width: 210, height: 252)

                VStack(spacing: 2) {
                    Text("\(snapshot.currentStreak)")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: snapshot.currentStreak)
                        .shadow(color: .black.opacity(0.35), radius: 8, y: 2)

                    Text(streakDayLabel)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.92))
                }
                .offset(y: 10)
            }
            .frame(height: 248)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(snapshot.currentStreak) \(streakDayLabel)")

            consistencyBadge
        }
        .frame(maxWidth: .infinity)
    }

    private var streakDayLabel: String {
        snapshot.currentStreak <= 1 ? "jour de suite" : "jours de suite"
    }

    private var consistencyBadge: some View {
        HStack(spacing: 6) {
            Text(consistencyEmoji)
                .font(.system(size: 14))
            Text(consistencyMessage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ProfileStreakDesign.mintDeep)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(ProfileStreakDesign.mint.opacity(0.22))
        )
    }

    private var consistencyEmoji: String {
        if snapshot.isTodayComplete && snapshot.currentStreak == 0 { return "✅" }
        switch snapshot.currentStreak {
        case 0: return "💪"
        case 1...2: return "🔥"
        case 3...6: return "✨"
        case 7...13: return "😊"
        default: return "🏆"
        }
    }

    private var consistencyMessage: String {
        if snapshot.isTodayComplete && snapshot.currentStreak == 0 {
            return "Premier jour validé !"
        }
        switch snapshot.currentStreak {
        case 0:
            return "Valide ton bilan du soir pour lancer la série"
        case 1...2:
            return "Belle régularité !"
        case 3...6:
            return "Tu construis l'habitude"
        case 7...13:
            return "Régularité incroyable !"
        default:
            return "Mode Process activé"
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
                    .buttonStyle(.plain)
                }
            }

            GeometryReader { geometry in
                let count = max(programDays.count, 1)
                let columnWidth = geometry.size.width / CGFloat(count)

                ZStack(alignment: .leading) {
                    if let range = streakRange {
                        Capsule(style: .continuous)
                            .fill(ProfileStreakDesign.mint)
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
            return ProfileStreakDesign.mint
        }
        return theme.secondaryText.opacity(0.75)
    }

    @ViewBuilder
    private func programDayColumn(_ day: ProfileProgramStreakDay, inActivePill: Bool) -> some View {
        Group {
            if day.isFuture {
                Circle()
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 1.5)
                    .frame(width: 28, height: 28)
            } else if day.isComplete {
                ZStack {
                    Circle()
                        .fill(inActivePill ? Color.black.opacity(0.22) : ProfileStreakDesign.missedFill)
                        .frame(width: 28, height: 28)
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(inActivePill ? Color.black.opacity(0.85) : ProfileStreakDesign.mint)
                }
            } else if day.isToday {
                ProfileStreakTodaySpinner()
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
            statCard(icon: "flame.fill", value: snapshot.currentStreak, label: "Série actuelle")
            statCard(icon: "rosette", value: snapshot.longestStreak, label: "Meilleure série")
            statCard(icon: "checkmark.circle.fill", value: snapshot.totalCompletedDays, label: "Jours validés")
        }
    }

    private func statCard(icon: String, value: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.secondaryText.opacity(0.85))

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
            .fill(ProfileStreakDesign.cardFill)
            .overlay {
                RoundedRectangle(cornerRadius: ProfileStreakDesign.statCardRadius, style: .continuous)
                    .strokeBorder(ProfileStreakDesign.cardStroke, lineWidth: 1)
            }
    }

    // MARK: - Succès

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Succès")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.primaryText)
                Spacer()
                Text("\(unlockedAchievements)/\(ProcessStreakMilestone.catalog.count)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.secondaryText)
                    .monospacedDigit()
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ],
                spacing: 10
            ) {
                ForEach(Array(ProcessStreakMilestone.catalog.enumerated()), id: \.element.id) { index, milestone in
                    achievementCard(milestone, index: index)
                }
            }
        }
    }

    private func achievementCard(_ milestone: ProcessStreakMilestone, index: Int) -> some View {
        let unlocked = snapshot.longestStreak >= milestone.days || snapshot.totalCompletedDays >= milestone.days
        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(unlocked ? ProfileStreakDesign.mint.opacity(0.18) : Color.white.opacity(0.05))
                    .frame(width: 40, height: 40)
                Image(systemName: achievementIcon(for: milestone.days))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(unlocked ? ProfileStreakDesign.mint : theme.secondaryText.opacity(0.4))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(milestone.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(unlocked ? theme.primaryText : theme.secondaryText.opacity(0.55))
                Text(milestone.subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.secondaryText.opacity(unlocked ? 0.85 : 0.45))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Image(systemName: unlocked ? "checkmark.circle.fill" : "lock.fill")
                .font(.system(size: unlocked ? 16 : 12))
                .foregroundStyle(unlocked ? ProfileStreakDesign.mint : theme.secondaryText.opacity(0.35))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: ProfileStreakDesign.achievementRadius, style: .continuous)
                .fill(ProfileStreakDesign.cardFill)
                .overlay {
                    RoundedRectangle(cornerRadius: ProfileStreakDesign.achievementRadius, style: .continuous)
                        .strokeBorder(
                            unlocked ? ProfileStreakDesign.mint.opacity(0.25) : ProfileStreakDesign.cardStroke,
                            lineWidth: 1
                        )
                }
        )
        .opacity(unlocked ? 1 : 0.72)
        .animation(.spring(response: 0.4, dampingFraction: 0.82).delay(Double(index) * 0.04), value: unlocked)
    }

    private func achievementIcon(for days: Int) -> String {
        switch days {
        case 3: return "sparkles"
        case 7: return "flame.fill"
        case 14: return "bolt.fill"
        case 30: return "star.fill"
        case 60: return "crown.fill"
        default: return "trophy.fill"
        }
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

            flameLayer(
                phase: 0,
                widthScale: 1.18,
                heightScale: 1.12,
                blur: 32,
                opacity: 0.38,
                colors: [
                    ProfileStreakDesign.mintGlow.opacity(0.5),
                    ProfileStreakDesign.mintDeep.opacity(0.04)
                ]
            )
            .blendMode(.plusLighter)

            flameLayer(
                phase: 1.35,
                widthScale: 1.08,
                heightScale: 1.06,
                blur: 22,
                opacity: 0.52,
                colors: [
                    ProfileStreakDesign.mintGlow.opacity(0.68),
                    ProfileStreakDesign.mintDeep.opacity(0.12)
                ]
            )
            .blendMode(.plusLighter)

            flameLayer(
                phase: 2.7,
                widthScale: 0.96,
                heightScale: 1.0,
                blur: 10,
                opacity: 0.84,
                colors: [
                    ProfileStreakDesign.mint.opacity(0.96),
                    ProfileStreakDesign.mintDeep.opacity(0.45)
                ]
            )

            flameLayer(
                phase: 4.1,
                widthScale: 0.68,
                heightScale: 0.82,
                blur: 4,
                opacity: 0.96,
                colors: [
                    Color.white.opacity(0.94),
                    ProfileStreakDesign.mint.opacity(0.9)
                ]
            )

            flickerTongue(phase: 0.8, offset: -0.18, scale: 0.38)
            flickerTongue(phase: 2.2, offset: 0.14, scale: 0.34)
            flickerTongue(phase: 3.6, offset: 0.02, scale: 0.28)
        }
        .frame(width: canvasWidth, height: canvasHeight)
        .mask(softEdgeMask)
        .accessibilityHidden(true)
        .opacity(isActive ? 1 : 0.92)
    }

    private var softEdgeMask: some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [
                        Color.white,
                        Color.white.opacity(0.92),
                        Color.white.opacity(0.55),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 28,
                    endRadius: 128
                )
            )
            .scaleEffect(x: 0.92, y: 1.02)
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
                        ProfileStreakDesign.mintGlow.opacity(0.55),
                        ProfileStreakDesign.mintDeep.opacity(0.08),
                        Color.clear
                    ]),
                    center: CGPoint(x: rect.midX, y: rect.midY + rect.height * 0.08),
                    startRadius: 8,
                    endRadius: max(rect.width, rect.height) * 0.72
                )
            )
        }
        .blur(radius: 38)
        .opacity(0.72)
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
                        ProfileStreakDesign.mint.opacity(0.28)
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

// MARK: - Spinner jour actuel

private struct ProfileStreakTodaySpinner: View {
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(Color.black.opacity(0.12), lineWidth: 2)
                .frame(width: 28, height: 28)

            Circle()
                .trim(from: 0, to: 0.28)
                .stroke(Color.black.opacity(0.55), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
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
