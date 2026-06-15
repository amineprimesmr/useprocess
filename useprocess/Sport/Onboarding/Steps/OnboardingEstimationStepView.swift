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
    @State private var animationTask: Task<Void, Never>?

    private let mainAnimationDuration: TimeInterval = 3.5
    private let optimizedHoldDuration: TimeInterval = 1.0

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
            cancelAllAnimations()
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
                    .foregroundStyle(OnboardingTheme.bodyText)
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
                        .foregroundStyle(OnboardingTheme.bodyText)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 40)
    }

    // MARK: - Setup & animation

    private func prepareAndAnimate() {
        cancelAllAnimations()

        curveAnimationProgress = 0
        isCountdownFinished = false
        showingBaselineDate = false
        baselineDisplayDate = nil
        onValidationChanged?(false)

        let finalDate = engine.computeProjectedDate(for: context)
        projectedDate = finalDate
        monthlySecondLine = engine.monthlySecondLine(for: context, projectedDate: finalDate)
        updateDateDisplay(date: finalDate)

        animationTask = Task { @MainActor in
            if context.phase == .optimized,
               let baseline = engine.loadBaselineDate(),
               baseline > finalDate {
                await runOptimizedSequence(baseline: baseline, final: finalDate)
            } else {
                await runBaselineSequence(final: finalDate)
            }

            guard !Task.isCancelled else { return }
            finishAnimation()
        }

        // Filet de sécurité si l'animation est interrompue
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            if !isCountdownFinished {
                finishAnimation()
            }
        }
    }

    /// Première estimation : courbe + date synchronisées une seule fois.
    private func runBaselineSequence(final: Date) async {
        let calendar = Calendar.current
        let now = Date()
        let daysDifference = max(1, calendar.dateComponents([.day], from: now, to: final).day ?? 30)
        let initialDays = Int(Double(daysDifference) * 1.2)
        let startDate = calendar.date(byAdding: .day, value: initialDays, to: now) ?? final

        try? await Task.sleep(nanoseconds: 300_000_000)
        guard !Task.isCancelled else { return }

        await runSynchronizedAnimation(from: startDate, to: final, animateCurve: true)
    }

    /// Deuxième estimation : pause sur la baseline (courbe déjà complète), puis une seule animation vers la date optimisée.
    private func runOptimizedSequence(baseline: Date, final: Date) async {
        baselineDisplayDate = baseline
        showingBaselineDate = true
        curveAnimationProgress = 1.0
        applyDateDisplay(for: baseline)

        try? await Task.sleep(nanoseconds: UInt64(optimizedHoldDuration * 1_000_000_000))
        guard !Task.isCancelled else { return }

        showingBaselineDate = false
        curveAnimationProgress = 0
        applyDateDisplay(for: baseline)

        await runSynchronizedAnimation(from: baseline, to: final, animateCurve: true)
    }

    /// Timeline unique : courbe + date + haptics sur la même horloge.
    private func runSynchronizedAnimation(
        from startDate: Date,
        to endDate: Date,
        animateCurve: Bool
    ) async {
        let calendar = Calendar.current
        let totalDayDelta = abs(calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0)
        let direction = endDate >= startDate ? 1 : -1
        var lastHapticDay = calendar.component(.day, from: startDate)
        var lastHapticMonth = calendar.component(.month, from: startDate)

        let startTime = Date()

        while !Task.isCancelled {
            let elapsed = Date().timeIntervalSince(startTime)
            let progress = min(elapsed / mainAnimationDuration, 1.0)
            let eased = 1.0 - pow(1.0 - progress, 3.0)

            if animateCurve {
                curveAnimationProgress = eased
            }

            let daysMoved = Int(round(Double(totalDayDelta) * progress))
            let displayDate = calendar.date(byAdding: .day, value: daysMoved * direction, to: startDate) ?? endDate
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

        applyDateDisplay(for: endDate)
        updateDateDisplay(date: endDate)
        if animateCurve {
            curveAnimationProgress = 1.0
        }
    }

    private func cancelAllAnimations() {
        animationTask?.cancel()
        animationTask = nil
    }

    private func applyDateDisplay(for date: Date) {
        displayedDay = "\(Calendar.current.component(.day, from: date))"
        displayedMonth = formatMonth(date)
    }

    private func updateDateDisplay(date: Date) {
        dayOnly = "\(Calendar.current.component(.day, from: date))"
        monthOnly = formatMonth(date)
    }

    private func finishAnimation() {
        guard !isCountdownFinished else { return }
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
