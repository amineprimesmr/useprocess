import SwiftUI

/// Hero stats — une seule progression : le programme debloat (jour X / total).
struct ProfileScanEvolutionHero: View {
    @Bindable var historyStore: FaceScanHistoryStore
    @Binding var selectedDate: Date
    var isPlaybackActive: Bool = true
    var onOpenScan: (FaceScanResult) -> Void

    @Environment(\.appTheme) private var theme
    @Bindable private var planProgressStore = ProcessPlanProgressStore.shared
    @Bindable private var planStore = WelcomePlanStore.shared

    private let circleDiameter: CGFloat = 112

    private var displayedScan: FaceScanResult? {
        let dayEnd = Calendar.current.date(
            byAdding: .day,
            value: 1,
            to: Calendar.current.startOfDay(for: selectedDate)
        ) ?? selectedDate
        return historyStore.history.first { $0.createdAt < dayEnd }
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
        let calendar = Calendar.current
        if calendar.isDateInToday(selectedDate), progress.elapsedProgramDays > 0 {
            return progress.elapsedProgramDays
        }
        if let selectedProgramDayNumber {
            return selectedProgramDayNumber
        }
        guard progress.hasPlan, progress.totalProgramDays > 0 else { return 0 }
        return min(progress.totalProgramDays, max(1, progress.elapsedProgramDays))
    }

    private var completionPercent: Int {
        guard progress.hasPlan else { return 0 }
        return Int((min(max(progress.timeProgress, 0), 1) * 100).rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 18) {
                programSummary

                Spacer(minLength: 12)

                scanButton
            }

            progressBar

            if progress.hasPlan {
                programFooter
            }
        }
        .padding(.top, 12)
        .padding(.horizontal, ProfileTheme.horizontalPadding)
        .padding(.bottom, 18)
    }

    private var programSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(progress.hasPlan ? "Programme debloat" : "Programme")
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

            Text(progress.hasPlan ? progress.subtitle : "Aucun plan actif")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.secondaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var programFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            if progress.durationAdjustmentDays != 0 {
                Text(adjustmentLabel)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(
                        progress.durationAdjustmentDays < 0
                            ? Color(red: 0.35, green: 0.78, blue: 0.45)
                            : Color(red: 1.0, green: 0.72, blue: 0.28)
                    )
            }

            if let note = progress.latestEvolutionNote {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color(hex: "aeb2fa"))
                        .padding(.top, 2)

                    Text(note)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var adjustmentLabel: String {
        let days = abs(progress.durationAdjustmentDays)
        let signed = progress.durationAdjustmentDays > 0 ? "+\(days)" : "-\(days)"
        return "\(signed) j sur le programme debloat"
    }

    @ViewBuilder
    private var scanButton: some View {
        if let displayedScan {
            Button {
                HapticManager.shared.impact(.light)
                onOpenScan(displayedScan)
            } label: {
                ProfileScanCircleMedia(
                    result: displayedScan,
                    diameter: circleDiameter,
                    isPlaybackActive: isPlaybackActive
                )
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
                    .frame(width: max(progress.hasPlan ? 8 : 0, geometry.size.width * CGFloat(min(max(progress.timeProgress, 0), 1))))
            }
        }
        .frame(height: 8)
        .accessibilityLabel("Progression debloat \(completionPercent) pour cent")
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
    var isPlaybackActive: Bool = true

    @Environment(\.appTheme) private var theme

    var body: some View {
        FaceScanRecordingMediaView(
            result: result,
            height: diameter,
            displayMode: .featured,
            isPlaybackActive: isPlaybackActive
        )
        .id("\(result.id)-\(isPlaybackActive)")
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
