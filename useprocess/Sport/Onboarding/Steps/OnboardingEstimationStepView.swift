//
//  OnboardingEstimationStepView.swift
//  Process
//
//  Écran unique « D'après nos estimations ».
//

import SwiftUI

struct OnboardingEstimationStepView: View {
    @Environment(\.scenePhase) private var scenePhase

    let context: OnboardingEstimationContext
    let isAlreadyCompleted: Bool
    var onValidationChanged: ((Bool) -> Void)?

    @State private var projectedDate: Date?
    @State private var titleMessage = ""
    @State private var graphSnapshot: OnboardingEstimationGraphSnapshot?
    @State private var dayOnly = ""
    @State private var monthOnly = ""
    @State private var displayedDay = ""
    @State private var displayedMonth = ""
    @State private var summaryLine = ""
    @State private var curveAnimationProgress: Double = 0
    @State private var isCountdownFinished = false
    @State private var animationTask: Task<Void, Never>?
    @State private var fallbackUnlockTask: Task<Void, Never>?

    private let mainAnimationDuration: TimeInterval = 3.5

    private var engine: OnboardingEstimationEngine { .shared }

    var body: some View {
        EstimationStepLayout(
            titleMessage: titleMessage.isEmpty ? engine.titleMessage(for: context) : titleMessage,
            displayDay: currentDisplayDay,
            displayMonth: currentDisplayMonth,
            graph: {
                if let snapshot = graphSnapshot {
                    OnboardingEstimationGraphView(
                        snapshot: snapshot,
                        curveAnimationProgress: curveAnimationProgress
                    )
                }
            },
            bottom: {
                bottomMessageView
            }
        )
        .onAppear {
            ensureHydrated()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            guard isAlreadyCompleted else { return }
            ensureHydrated()
        }
        .onChange(of: isAlreadyCompleted) { _, completed in
            if completed {
                presentCompletedState()
            }
        }
        .onDisappear {
            cancelRunningTasks()
            resetForNextVisit()
        }
    }

    private func resetForNextVisit() {
        isCountdownFinished = false
        curveAnimationProgress = 0
        displayedDay = ""
        displayedMonth = ""
        onValidationChanged?(false)
    }

    private var currentDisplayDay: String {
        if !displayedDay.isEmpty { return displayedDay }
        if !dayOnly.isEmpty { return dayOnly }
        if let date = projectedDate {
            return "\(Calendar.current.component(.day, from: date))"
        }
        return "..."
    }

    private var currentDisplayMonth: String {
        if !displayedMonth.isEmpty { return displayedMonth }
        if !monthOnly.isEmpty { return monthOnly }
        if let date = projectedDate {
            return formatMonth(date)
        }
        return "..."
    }

    private var bottomMessageView: some View {
        HStack(alignment: .top, spacing: 10) {
            Image("check")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .padding(.top, 1)

            Text(summaryLine)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(OnboardingTheme.bodyText)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(summaryLine.isEmpty ? 0 : 1)
    }

    // MARK: - Hydration / restore

    private func ensureHydrated() {
        let needsContent = projectedDate == nil || graphSnapshot == nil || summaryLine.isEmpty

        if isAlreadyCompleted {
            if needsContent {
                hydrateContent()
            }
            presentCompletedState()
            return
        }

        if needsContent {
            hydrateContent()
        }

        startCountdownAnimation()
    }

    private func hydrateContent() {
        let referenceDate = Date()
        let timeline = engine.computeTimeline(for: context, now: referenceDate)
        let debloatDate = timeline.debloatDate

        projectedDate = debloatDate
        titleMessage = engine.titleMessage(for: context)
        graphSnapshot = OnboardingEstimationGraphSnapshot.make(
            context: context,
            timeline: timeline,
            referenceDate: referenceDate
        )
        summaryLine = engine.summaryLine(for: context)
        updateDateDisplay(date: debloatDate)
    }

    private func presentCompletedState() {
        guard let finalDate = projectedDate else {
            hydrateContent()
            guard let resolvedDate = projectedDate else { return }
            applyDateDisplay(for: resolvedDate)
            updateDateDisplay(date: resolvedDate)
            curveAnimationProgress = 1.0
            finishAnimation()
            return
        }

        applyDateDisplay(for: finalDate)
        updateDateDisplay(date: finalDate)
        curveAnimationProgress = 1.0
        finishAnimation()
    }

    private func startCountdownAnimation() {
        cancelRunningTasks()

        guard let finalDate = projectedDate else { return }

        curveAnimationProgress = 0
        isCountdownFinished = false
        onValidationChanged?(false)

        animationTask = Task { @MainActor in
            await runAnimation(to: finalDate)
            guard !Task.isCancelled else { return }
            finishAnimation()
        }

        fallbackUnlockTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            guard !Task.isCancelled, !isCountdownFinished else { return }
            finishAnimation()
        }
    }

    // MARK: - Animation

    private func runAnimation(to final: Date) async {
        let calendar = Calendar.current
        let now = Date()
        let daysDifference = max(1, calendar.dateComponents([.day], from: now, to: final).day ?? 30)
        let overshootDays = max(daysDifference + 7, Int(ceil(Double(daysDifference) * 1.15)))
        let startDate = calendar.date(byAdding: .day, value: overshootDays, to: now) ?? final

        try? await Task.sleep(nanoseconds: 300_000_000)
        guard !Task.isCancelled else { return }

        let totalDayDelta = abs(calendar.dateComponents([.day], from: startDate, to: final).day ?? 0)
        guard totalDayDelta > 0 else {
            applyDateDisplay(for: final)
            updateDateDisplay(date: final)
            curveAnimationProgress = 1.0
            return
        }

        let direction = final >= startDate ? 1 : -1
        var lastHapticDay = calendar.component(.day, from: startDate)
        var lastHapticMonth = calendar.component(.month, from: startDate)
        let startTime = Date()

        while !Task.isCancelled {
            let elapsed = Date().timeIntervalSince(startTime)
            let progress = min(elapsed / mainAnimationDuration, 1.0)
            let eased = 1.0 - pow(1.0 - progress, 3.0)

            if abs(curveAnimationProgress - eased) > 0.001 {
                curveAnimationProgress = eased
            } else if progress >= 1.0 {
                curveAnimationProgress = 1.0
            }

            let daysMoved = Int(round(Double(totalDayDelta) * progress))
            let displayDate = calendar.date(byAdding: .day, value: daysMoved * direction, to: startDate) ?? final
            applyDateDisplay(for: displayDate)

            let day = calendar.component(.day, from: displayDate)
            let month = calendar.component(.month, from: displayDate)
            if progress > 0, (day != lastHapticDay || month != lastHapticMonth) {
                HapticManager.shared.impact(.soft)
                lastHapticDay = day
                lastHapticMonth = month
            }

            if progress >= 1.0 { break }
            try? await Task.sleep(nanoseconds: 16_000_000)
        }

        guard !Task.isCancelled else { return }

        applyDateDisplay(for: final)
        updateDateDisplay(date: final)
        curveAnimationProgress = 1.0
    }

    private func cancelRunningTasks() {
        animationTask?.cancel()
        animationTask = nil
        fallbackUnlockTask?.cancel()
        fallbackUnlockTask = nil
    }

    private func applyDateDisplay(for date: Date) {
        let day = "\(Calendar.current.component(.day, from: date))"
        let month = formatMonth(date)
        if displayedDay != day { displayedDay = day }
        if displayedMonth != month { displayedMonth = month }
    }

    private func updateDateDisplay(date: Date) {
        dayOnly = "\(Calendar.current.component(.day, from: date))"
        monthOnly = formatMonth(date)
    }

    private func finishAnimation() {
        guard !isCountdownFinished else { return }
        isCountdownFinished = true
        cancelRunningTasks()
        onValidationChanged?(true)
        HapticManager.shared.notification(.success)
    }

    private func formatMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = ProcessAppLanguage.currentLocale
        formatter.dateFormat = "MMMM"
        return formatter.string(from: date).capitalized
    }
}
