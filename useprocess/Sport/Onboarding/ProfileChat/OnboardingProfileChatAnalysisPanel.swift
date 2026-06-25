//
//  OnboardingProfileChatAnalysisPanel.swift
//  useprocess
//

import SwiftUI

struct OnboardingProfileChatAnalysisPanel: View {
    let phaseLabel: String
    let phaseIndex: Int
    let displayedPercentage: Int
    let progress: Double
    let elapsedSeconds: Int
    let isPaused: Bool
    let isVisible: Bool

    init(
        phaseLabel: String,
        phaseIndex: Int? = nil,
        displayedPercentage: Int,
        progress: Double,
        elapsedSeconds: Int = 0,
        isPaused: Bool = false,
        isVisible: Bool
    ) {
        self.phaseLabel = phaseLabel
        self.phaseIndex = phaseIndex
            ?? OnboardingAnalysisProgressConfig.stepIndex(forPhaseLabel: phaseLabel)
            ?? min(
                OnboardingAnalysisProgressConfig.answersAnalysisSteps.count - 1,
                Int(progress * Double(OnboardingAnalysisProgressConfig.answersAnalysisSteps.count))
            )
        self.displayedPercentage = displayedPercentage
        self.progress = progress
        self.elapsedSeconds = elapsedSeconds
        self.isPaused = isPaused
        self.isVisible = isVisible
    }

    private var steps: [OnboardingAnalysisProgressConfig.ProgressStep] {
        OnboardingAnalysisProgressConfig.answersAnalysisSteps
    }

    private var isComplete: Bool {
        progress >= 0.999
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            thinkingHeader

            VStack(alignment: .leading, spacing: 20) {
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    if index <= phaseIndex {
                        analysisStepBlock(
                            step: step,
                            stepIndex: index,
                            state: stepState(for: index)
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                if !isComplete {
                    skeletonPills
                        .transition(.opacity)
                }
            }
        }
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 12)
        .animation(OnboardingProfileChatAnswerReveal.spring, value: isVisible)
        .animation(.easeInOut(duration: 0.35), value: phaseIndex)
        .animation(.easeInOut(duration: 0.25), value: isPaused)
    }

    // MARK: - Header

    private var thinkingHeader: some View {
        HStack(spacing: 10) {
            ThinkingDotGrid(isAnimating: !isComplete && !isPaused)

            Text(thinkingTitle)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(OnboardingTheme.bodyText)
                .contentTransition(.opacity)

            Spacer(minLength: 0)

            if elapsedSeconds > 0, !isComplete {
                Text("\(elapsedSeconds)s")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(OnboardingTheme.mutedText)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
        }
    }

    private var thinkingTitle: String {
        if isComplete {
            return "Analyse terminée"
        }
        if isPaused {
            return "En attente de ta réponse…"
        }
        return "Réflexion en cours"
    }

    // MARK: - Steps

    private enum StepVisualState {
        case completed
        case active
    }

    private func stepState(for index: Int) -> StepVisualState {
        if index < phaseIndex || (index == phaseIndex && isComplete) {
            return .completed
        }
        return .active
    }

    @ViewBuilder
    private func analysisStepBlock(
        step: OnboardingAnalysisProgressConfig.ProgressStep,
        stepIndex: Int,
        state: StepVisualState
    ) -> some View {
        let isActive = state == .active && !isComplete

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: state == .completed ? "checkmark.circle.fill" : "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(
                        state == .completed
                            ? OnboardingProfileChatDepthStyle.chatAccentViolet
                            : OnboardingTheme.bodyText
                    )
                    .frame(width: 18, height: 18)
                    .symbolEffect(.pulse, options: .repeating, isActive: isActive && !isPaused)

                Text(step.query)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(
                        state == .completed
                            ? OnboardingTheme.mutedText
                            : OnboardingTheme.primaryText
                    )
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let count = step.resultCount, state == .completed || (isActive && progress > 0.08) {
                Text("\(count) sources")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(OnboardingTheme.mutedText)
                    .padding(.leading, 26)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(step.sources.enumerated()), id: \.element.id) { pillIndex, pill in
                        AnalysisSourcePillView(pill: pill)
                            .opacity(pillOpacity(stepIndex: stepIndex, pillIndex: pillIndex, state: state))
                            .offset(y: pillOffset(stepIndex: stepIndex, pillIndex: pillIndex, state: state))
                    }
                }
                .padding(.leading, 26)
                .padding(.trailing, 4)
            }
            .scrollClipDisabled()
        }
    }

    private func pillOpacity(stepIndex: Int, pillIndex: Int, state: StepVisualState) -> Double {
        if state == .completed { return 0.88 }
        let threshold = Double(pillIndex + 1) * 0.14
        let segmentStart = Double(stepIndex) / Double(steps.count)
        let local = (progress - segmentStart) * Double(steps.count)
        return local >= threshold ? 1 : 0.35
    }

    private func pillOffset(stepIndex: Int, pillIndex: Int, state: StepVisualState) -> CGFloat {
        if state == .completed { return 0 }
        let threshold = Double(pillIndex + 1) * 0.14
        let segmentStart = Double(stepIndex) / Double(steps.count)
        let local = (progress - segmentStart) * Double(steps.count)
        return local >= threshold ? 0 : 6
    }

    // MARK: - Skeleton

    private var skeletonPills: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                AnalysisSkeletonPill()
                    .opacity(0.45 + Double(index) * 0.12)
            }
        }
        .padding(.leading, 26)
    }
}

// MARK: - Subviews

private struct ThinkingDotGrid: View {
    let isAnimating: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.16, paused: !isAnimating)) { context in
            let pulsePhase = Int(context.date.timeIntervalSinceReferenceDate / 0.16) % 9

            VStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { column in
                            let index = row * 3 + column
                            Circle()
                                .fill(OnboardingTheme.bodyText.opacity(dotOpacity(index: index, pulsePhase: pulsePhase)))
                                .frame(width: 4, height: 4)
                        }
                    }
                }
            }
        }
    }

    private func dotOpacity(index: Int, pulsePhase: Int) -> Double {
        let distance = abs(index - pulsePhase)
        return max(0.28, 1.0 - Double(distance) * 0.22)
    }
}

private struct AnalysisSourcePillView: View {
    let pill: OnboardingAnalysisProgressConfig.SourcePill

    var body: some View {
        HStack(spacing: 7) {
            pillIcon
                .frame(width: 18, height: 18)

            Text(pill.label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(OnboardingTheme.cardBackground)
                .overlay(
                    Capsule()
                        .strokeBorder(OnboardingTheme.softBorder, lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private var pillIcon: some View {
        if let imageName = pill.imageName {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        } else if let systemImage = pill.systemImage {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(OnboardingTheme.bodyText)
        }
    }
}

private struct AnalysisSkeletonPill: View {
    @State private var shimmer = false

    var body: some View {
        Capsule()
            .fill(OnboardingTheme.subtleFill)
            .frame(width: shimmer ? 92 : 78, height: 34)
            .opacity(shimmer ? 0.85 : 0.55)
            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: shimmer)
            .onAppear { shimmer = true }
    }
}
