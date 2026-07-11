import SwiftUI

/// Hero profil compact — jour du programme à gauche, dernier scan rond à droite.
struct ProfileScanEvolutionHero: View {
    @Bindable var historyStore: FaceScanHistoryStore
    let selectedDate: Date
    var onOpenScan: (FaceScanResult) -> Void

    @Environment(\.appTheme) private var theme
    @Bindable private var planProgressStore = ProcessPlanProgressStore.shared
    @Bindable private var planStore = WelcomePlanStore.shared
    @Bindable private var trajectoryStore = ProcessDebloatTrajectoryStore.shared

    private let circleDiameter: CGFloat = 112

    private var displayedScan: FaceScanResult? {
        let dayEnd = Calendar.current.date(
            byAdding: .day,
            value: 1,
            to: Calendar.current.startOfDay(for: selectedDate)
        ) ?? selectedDate
        return historyStore.history
            .filter { $0.createdAt < dayEnd }
            .sorted { $0.createdAt > $1.createdAt }
            .first
    }

    private var progress: PlanProgressSnapshot {
        planProgressStore.snapshot
    }

    private var selectedProgramDayNumber: Int? {
        guard let plan = planStore.plan,
              let day = OriginPlanPresenter.programDay(in: plan, for: selectedDate) else {
            return nil
        }
        return day.globalDayIndex + 1
    }

    private var displayedProgramDay: Int {
        if let selectedProgramDayNumber {
            return selectedProgramDayNumber
        }
        guard progress.hasPlan, progress.totalProgramDays > 0 else { return 0 }
        if progress.validationProgress >= 1 { return progress.totalProgramDays }
        return min(progress.totalProgramDays, max(1, progress.validatedDays + 1))
    }

    private var completionPercent: Int {
        guard progress.hasPlan else { return 0 }
        return Int((min(max(progress.validationProgress, 0), 1) * 100).rounded())
    }

    private var displayedValidatedDays: Int {
        guard progress.hasPlan else { return 0 }
        return progress.validatedDays
    }

    private var displayedStreak: Int {
        if let record = trajectoryStore.record(for: selectedDate), record.checkInSubmitted {
            return record.streakAfterDay
        }
        return progress.currentStreak
    }

    private var displayedWeekLabel: String? {
        guard progress.hasPlan, progress.elapsedProgramDays > 0 else { return nil }
        return "S\(progress.currentWeek)/\(progress.totalWeeks)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 18) {
                programSummary

                Spacer(minLength: 12)

                scanButton
            }

            progressBar

            programMetricsRow
        }
        .padding(.top, ProcessMainChromeMetrics.topSafeInset + 48)
        .padding(.horizontal, ProfileTheme.horizontalPadding)
        .padding(.bottom, 18)
    }

    private var programSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(progress.hasPlan ? "Jour" : "Programme")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(theme.secondaryText)

            Text(dateLabel)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.primaryText.opacity(0.74))

            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text(progress.hasPlan ? "\(displayedProgramDay)" : "—")
                    .font(.system(size: 46, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.primaryText)
                    .monospacedDigit()

                if progress.hasPlan {
                    Text("/ \(progress.totalProgramDays)")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.secondaryText)
                        .monospacedDigit()
                }
            }

            Text(progress.hasPlan ? "\(completionPercent)% du programme validé" : "Aucun plan actif")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var scanButton: some View {
        if let displayedScan {
            Button {
                HapticManager.shared.impact(.light)
                onOpenScan(displayedScan)
            } label: {
                ProfileScanCircleMedia(result: displayedScan, diameter: circleDiameter)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Ouvrir le scan affiché")
        } else {
            ZStack {
                Circle()
                    .fill(theme.cardBackgroundStrong.opacity(theme.isDark ? 0.55 : 0.35))
                    .frame(width: circleDiameter, height: circleDiameter)

                Image(systemName: "face.smiling")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(theme.onboardingAccent.opacity(0.85))
            }
            .accessibilityLabel("Aucun scan")
        }
    }

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(theme.primaryText.opacity(theme.isDark ? 0.10 : 0.07))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.45, green: 0.72, blue: 0.95),
                                Color(hex: "aeb2fa")
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(progress.hasPlan ? 8 : 0, geometry.size.width * CGFloat(min(max(progress.validationProgress, 0), 1))))
            }
        }
        .frame(height: 8)
        .accessibilityLabel("Progression du programme \(completionPercent) pour cent")
    }

    @ViewBuilder
    private var programMetricsRow: some View {
        if progress.hasPlan {
            HStack(spacing: 8) {
                programMetricPill(
                    icon: "checkmark.circle.fill",
                    value: "\(displayedValidatedDays)",
                    label: "validés"
                )

                programMetricPill(
                    icon: "flame.fill",
                    value: "\(displayedStreak)",
                    label: "série"
                )

                if let displayedWeekLabel {
                    programMetricPill(
                        icon: "calendar",
                        value: displayedWeekLabel,
                        label: "semaine"
                    )
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func programMetricPill(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.secondaryText)

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.primaryText)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
        .padding(.horizontal, 10)
        .background(
            Capsule()
                .fill(theme.primaryText.opacity(theme.isDark ? 0.075 : 0.045))
        )
    }

    private var dateLabel: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(selectedDate) { return "Aujourd'hui" }
        if calendar.isDateInYesterday(selectedDate) { return "Hier" }
        return Self.dateFormatter.string(from: selectedDate)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "d MMM"
        return formatter
    }()
}

private struct ProfileScanCircleMedia: View {
    let result: FaceScanResult
    let diameter: CGFloat

    @Environment(\.appTheme) private var theme

    var body: some View {
        FaceScanRecordingMediaView(
            result: result,
            height: diameter,
            displayMode: .featured
        )
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .overlay {
            Circle()
                .strokeBorder(
                    Color.primary.opacity(theme.isDark ? 0.14 : 0.08),
                    lineWidth: 0.5
                )
        }
        .shadow(
            color: Color.black.opacity(theme.isDark ? 0.28 : 0.10),
            radius: 18,
            y: 8
        )
        .accessibilityLabel("Scan du \(result.createdAt.formatted(date: .abbreviated, time: .omitted))")
    }
}
