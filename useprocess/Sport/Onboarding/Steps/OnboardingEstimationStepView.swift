//
//  OnboardingEstimationStepView.swift
//  Process
//
//  Écran unifié « D'après nos estimations » (baseline + optimized).
//

import SwiftUI

struct OnboardingEstimationStepView: View {
    let context: OnboardingEstimationContext
    var onValidationChanged: ((Bool) -> Void)?

    @State private var projectedDate: Date?
    @State private var dayOnly = ""
    @State private var monthOnly = ""
    @State private var displayedDay = ""
    @State private var displayedMonth = ""
    @State private var monthlySecondLine = ""
    @State private var curveAnimationProgress: Double = 0
    @State private var showingBaselineDate = false
    @State private var baselineDisplayDate: Date?
    @State private var isCountdownFinished = false
    @State private var countdownTask: Task<Void, Never>?
    @State private var dateAnimationTasks: [DispatchWorkItem] = []
    @State private var curveAnimationTimer: Timer?

    private var engine: OnboardingEstimationEngine { .shared }

    var body: some View {
        EstimationStepLayout(
            titleMessage: context.titleMessage,
            displayDay: currentDisplayDay,
            displayMonth: currentDisplayMonth,
            graph: {
                if let date = graphDate {
                    OnboardingEstimationGraphView(
                        projectedDate: date,
                        context: context,
                        curveAnimationProgress: curveAnimationProgress,
                        useAcceleratedCurve: context.phase == .optimized && !showingBaselineDate
                    )
                }
            },
            bottom: {
                bottomMessagesView
            }
        )
        .onAppear {
            prepareAndAnimate()
        }
        .onDisappear {
            countdownTask?.cancel()
            dateAnimationTasks.forEach { $0.cancel() }
            curveAnimationTimer?.invalidate()
        }
    }

    private var graphDate: Date? {
        if showingBaselineDate { return baselineDisplayDate }
        return projectedDate
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

    private var bottomMessagesView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image("check")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)

                Text("Basé sur ton profil")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.top, 8)

            if !monthlySecondLine.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image("check")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)

                    Text(monthlySecondLine)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 40)
    }

    // MARK: - Setup & animation

    private func prepareAndAnimate() {
        curveAnimationProgress = 0
        isCountdownFinished = false
        onValidationChanged?(false)

        let finalDate = engine.computeProjectedDate(for: context)
        projectedDate = finalDate
        monthlySecondLine = engine.monthlySecondLine(for: context, projectedDate: finalDate)

        startCurveAnimation(delay: 0.3)

        _ = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            if !isCountdownFinished {
                finishAnimation()
            }
        }

        if context.phase == .optimized,
           let baseline = engine.loadBaselineDate(),
           baseline > finalDate {
            baselineDisplayDate = baseline
            showingBaselineDate = true
            updateDateDisplay(date: baseline)

            Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }

                showingBaselineDate = false
                curveAnimationProgress = 0
                startCurveAnimation(delay: 0.1)
                _ = animateDateFrom(baseline, to: finalDate) { duration in
                    startCountdownAnimation(totalDuration: duration)
                }
            }
        } else {
            let calendar = Calendar.current
            let now = Date()
            let daysDifference = max(1, calendar.dateComponents([.day], from: now, to: finalDate).day ?? 30)
            let initialDays = Int(Double(daysDifference) * 1.2)
            if let animStart = calendar.date(byAdding: .day, value: initialDays, to: now) {
                _ = animateDateFrom(animStart, to: finalDate) { duration in
                    startCountdownAnimation(totalDuration: duration)
                }
            } else {
                updateDateDisplay(date: finalDate)
                startCountdownAnimation()
            }
        }
    }

    private func startCurveAnimation(delay: TimeInterval) {
        Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            curveAnimationTimer?.invalidate()

            let duration: TimeInterval = 3.0
            let startTime = Date()
            curveAnimationTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { timer in
                let elapsed = Date().timeIntervalSince(startTime)
                let progress = min(elapsed / duration, 1.0)
                curveAnimationProgress = 1.0 - pow(1.0 - progress, 3.0)
                if progress >= 1.0 {
                    timer.invalidate()
                    curveAnimationProgress = 1.0
                }
            }
            if let timer = curveAnimationTimer {
                RunLoop.main.add(timer, forMode: .common)
            }
        }
    }

    @discardableResult
    private func animateDateFrom(
        _ fromDate: Date,
        to toDate: Date,
        startCountdownCallback: ((TimeInterval) -> Void)? = nil
    ) -> TimeInterval {
        let calendar = Calendar.current
        let fromDay = calendar.component(.day, from: fromDate)
        let toDay = calendar.component(.day, from: toDate)
        let fromMonth = formatMonth(fromDate)
        let toMonth = formatMonth(toDate)
        let animationDuration: TimeInterval = 4.0

        displayedDay = "\(fromDay)"
        displayedMonth = fromMonth
        dayOnly = "\(toDay)"
        monthOnly = toMonth

        if fromDay != toDay {
            let daySteps: [Int] = fromDay < toDay
                ? Array(fromDay...toDay)
                : Array((toDay...fromDay).reversed())
            let dayStepDuration = animationDuration / Double(max(daySteps.count, 1))

            dateAnimationTasks.forEach { $0.cancel() }
            dateAnimationTasks.removeAll()

            for (index, day) in daySteps.enumerated() {
                let workItem = DispatchWorkItem {
                    withAnimation(.easeOut(duration: dayStepDuration)) {
                        displayedDay = "\(day)"
                    }
                    if index > 0 {
                        HapticManager.shared.impact(.soft)
                    }
                }
                dateAnimationTasks.append(workItem)
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * dayStepDuration, execute: workItem)
            }
        } else {
            displayedDay = "\(toDay)"
        }

        if fromMonth != toMonth {
            DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration * 0.5) {
                withAnimation(.easeOut(duration: animationDuration * 0.5)) {
                    displayedMonth = toMonth
                }
            }
        } else {
            displayedMonth = toMonth
        }

        startCountdownCallback?(animationDuration)

        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
            updateDateDisplay(date: toDate)
            finishAnimation()
        }

        return animationDuration
    }

    private func startCountdownAnimation(totalDuration: TimeInterval = 4.0) {
        guard let date = projectedDate else { return }

        countdownTask?.cancel()
        let calendar = Calendar.current
        let now = Date()
        let daysDifference = calendar.dateComponents([.day], from: now, to: date).day ?? 0
        let initialDays = max(daysDifference, Int(Double(max(daysDifference, 1)) * 1.2))
        let steps = abs(initialDays - daysDifference)

        guard steps > 0 else { return }

        let stepInterval = totalDuration / Double(steps)
        let direction = initialDays > daysDifference ? -1 : 1

        countdownTask = Task { @MainActor in
            var currentDays = initialDays
            while currentDays != daysDifference {
                if Task.isCancelled { return }
                currentDays += direction
                try? await Task.sleep(nanoseconds: UInt64(stepInterval * 1_000_000_000))
            }
        }
    }

    private func updateDateDisplay(date: Date) {
        dayOnly = "\(Calendar.current.component(.day, from: date))"
        monthOnly = formatMonth(date)
    }

    private func finishAnimation() {
        isCountdownFinished = true
        onValidationChanged?(true)
        HapticManager.shared.notification(.success)
    }

    private func formatMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "MMMM"
        return formatter.string(from: date).capitalized
    }
}
