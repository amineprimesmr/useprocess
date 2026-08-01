import SwiftUI

/// Bandeau horizontal des jours du programme — page Statistiques / Profil.
struct ProfileProgramDayStrip: View {
    @Binding var selectedDate: Date
    let plan: FaceOriginPlan
    let progress: PlanProgressSnapshot
    let recordsByDay: [String: DebloatDayRecord]

    @Environment(\.appTheme) private var theme

    private var stripDates: [Date] {
        OriginPlanPresenter.journalStripDates(in: plan)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .center, spacing: ProfileProgramDayStripDesign.cellSpacing) {
                    ForEach(stripDates, id: \.self) { date in
                        dayCell(for: date)
                            .id(date)
                            .frame(
                                width: ProfileProgramDayStripDesign.slotWidth,
                                height: ProfileProgramDayStripDesign.slotHeight
                            )
                            .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                content
                                    .opacity(0.62 + (1 - min(abs(phase.value), 1)) * 0.38)
                            }
                    }
                }
                .scrollTargetLayout()
                .padding(.leading, 2)
                .padding(.trailing, 12)
                .frame(height: ProfileProgramDayStripDesign.stripHeight)
            }
            .scrollTargetBehavior(.viewAligned)
            .onAppear {
                scrollToSelected(proxy, animated: false)
            }
            .onChange(of: selectedDate) { _, _ in
                scrollToSelected(proxy, animated: true)
            }
        }
        .frame(height: ProfileProgramDayStripDesign.stripHeight)
    }

    private func scrollToSelected(_ proxy: ScrollViewProxy, animated: Bool) {
        let target = Calendar.current.startOfDay(for: selectedDate)
        if animated {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                proxy.scrollTo(target, anchor: .center)
            }
        } else {
            proxy.scrollTo(target, anchor: .center)
        }
    }

    private func dayCell(for date: Date) -> some View {
        let calendar = Calendar.current
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let isFuture = OriginPlanPresenter.isFutureJournalDate(date)
        let programDay = OriginPlanPresenter.programDay(in: plan, for: date)
        let programDayNumber = programDay.map { $0.globalDayIndex + 1 }
        let dayKey = ProcessStreakStore.dayKey(for: date, calendar: calendar)
        let record = recordsByDay[dayKey]
        let isValidated = record.map {
            $0.countsAsValidatedDay(
                consecutiveCardioMissesBefore: ProcessDebloatValidation.consecutiveCardioMisses(
                    before: $0.dayKey,
                    in: recordsByDay
                )
            )
        } == true
        let isDebloatDay = programDayNumber.map { $0 == progress.totalProgramDays } ?? false
        let isBeyondProgram = programDayNumber.map { $0 > progress.totalProgramDays } ?? false

        return Button {
            HapticManager.shared.impact(.light)
            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                selectedDate = date
            }
        } label: {
            ZStack {
                ProfileProgramDayTileBackground(
                    isDark: theme.isDark,
                    isSelected: isSelected,
                    isDebloatDay: isDebloatDay && !isBeyondProgram,
                    accent: theme.onboardingAccent
                )

                VStack(spacing: 7) {
                    Text(programDayLabel(for: programDayNumber, isBeyondProgram: isBeyondProgram))
                        .font(.system(size: 16, weight: isSelected ? .bold : .semibold, design: .rounded))
                        .foregroundStyle(isSelected ? theme.primaryText : theme.secondaryText.opacity(0.92))
                        .monospacedDigit()
                        .contentTransition(.numericText())

                    dayStatusIcon(
                        isValidated: isValidated,
                        verdict: record?.verdict,
                        isFuture: isFuture,
                        isToday: isToday,
                        isSelected: isSelected,
                        isDebloatDay: isDebloatDay && !isBeyondProgram
                    )
                }
            }
            .frame(
                width: ProfileProgramDayStripDesign.cellWidth,
                height: ProfileProgramDayStripDesign.cellHeight
            )
            .scaleEffect(isSelected ? 1.03 : 1, anchor: .center)
            .animation(.spring(response: 0.32, dampingFraction: 0.78), value: isSelected)
        }
        .buttonStyle(ProfileProgramDayCellButtonStyle())
        .accessibilityLabel(accessibilityLabel(
            for: date,
            programDay: programDayNumber,
            isToday: isToday,
            isValidated: isValidated,
            isDebloatDay: isDebloatDay
        ))
    }

    private func programDayLabel(for programDayNumber: Int?, isBeyondProgram: Bool) -> String {
        guard let programDayNumber, !isBeyondProgram else { return "·" }
        return "\(programDayNumber)"
    }

    private func accessibilityLabel(
        for date: Date,
        programDay: Int?,
        isToday: Bool,
        isValidated: Bool,
        isDebloatDay: Bool
    ) -> String {
        var parts: [String] = []
        if let programDay {
            parts.append("Jour \(programDay) du programme")
        }
        parts.append(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
        if isToday { parts.append("aujourd'hui") }
        if isDebloatDay { parts.append("objectif debloat") }
        if isValidated { parts.append("validé") }
        return parts.joined(separator: ", ")
    }

    @ViewBuilder
    private func dayStatusIcon(
        isValidated: Bool,
        verdict: DebloatDayVerdict?,
        isFuture: Bool,
        isToday: Bool,
        isSelected: Bool,
        isDebloatDay: Bool
    ) -> some View {
        if isDebloatDay {
            Image(systemName: "drop.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(red: 0.45, green: 0.72, blue: 0.95))
                .frame(height: 18)
        } else if isValidated {
            let tint = verdict?.chartColor ?? ProfileProgramDayStripDesign.validatedGreen
            ZStack {
                if isSelected {
                    Circle()
                        .fill(tint.opacity(0.22))
                        .frame(width: 24, height: 24)
                        .blur(radius: 2)
                }
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(height: 18)
        } else if isFuture {
            Circle()
                .strokeBorder(theme.secondaryText.opacity(0.28), lineWidth: 1.5)
                .frame(width: 16, height: 16)
        } else if isToday {
            Circle()
                .fill(theme.onboardingAccent.opacity(0.85))
                .frame(width: 8, height: 8)
        } else {
            Circle()
                .fill(theme.secondaryText.opacity(0.22))
                .frame(width: 6, height: 6)
        }
    }
}

// MARK: - Design

private enum ProfileProgramDayStripDesign {
    static let validatedGreen = Color(red: 0.35, green: 0.78, blue: 0.45)
    static let cellWidth: CGFloat = 44
    static let cellHeight: CGFloat = 56
    static let slotWidth: CGFloat = 50
    static let slotHeight: CGFloat = 64
    static let stripHeight: CGFloat = 76
    static let cellSpacing: CGFloat = 8
}

private struct ProfileProgramDayCellButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.78), value: configuration.isPressed)
    }
}

private struct ProfileProgramDayTileBackground: View {
    let isDark: Bool
    let isSelected: Bool
    let isDebloatDay: Bool
    let accent: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 15, style: .continuous)
            .fill(
                isSelected
                    ? (isDark ? Color.white.opacity(0.12) : Color.white.opacity(0.92))
                    : (isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.04))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(
                        borderColor,
                        lineWidth: isSelected || isDebloatDay ? 1.5 : 0.5
                    )
            }
            .shadow(
                color: isSelected ? accent.opacity(isDark ? 0.18 : 0.12) : .clear,
                radius: 10,
                y: 4
            )
    }

    private var borderColor: Color {
        if isDebloatDay {
            return Color(red: 0.45, green: 0.72, blue: 0.95).opacity(isSelected ? 0.85 : 0.55)
        }
        if isSelected {
            return accent.opacity(0.45)
        }
        return Color.primary.opacity(isDark ? 0.08 : 0.06)
    }
}
