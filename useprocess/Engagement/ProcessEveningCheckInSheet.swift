import SwiftUI

// MARK: - Questions

enum EveningCheckInQuestion: String, CaseIterable, Identifiable {
    case morningRoutine
    case water
    case debloatMeal
    case cardio

    var id: String {
        switch self {
        case .morningRoutine: return EveningCheckInQuestionID.morningRoutine
        case .water: return EveningCheckInQuestionID.water
        case .debloatMeal: return EveningCheckInQuestionID.debloatMeal
        case .cardio: return EveningCheckInQuestionID.cardio
        }
    }

    var yesValue: String { "yes" }
    var noValue: String { "no" }

    var title: String {
        switch self {
        case .morningRoutine: return "Routine"
        case .water: return "3 L d'eau"
        case .debloatMeal: return "Repas debloat"
        case .cardio: return "Cardio"
        }
    }

    var icon: String {
        switch self {
        case .morningRoutine: return "sun.horizon.fill"
        case .water: return "drop.fill"
        case .debloatMeal: return "leaf.fill"
        case .cardio: return "figure.walk"
        }
    }
}

// MARK: - Habit Row

struct EveningCheckInHabitRow: View {
    let question: EveningCheckInQuestion
    let answer: String?
    let isLocked: Bool

    var onYes: () -> Void
    var onNo: () -> Void

    @Environment(\.appTheme) private var theme

    private var isChecked: Bool { answer == question.yesValue }
    private var isFailed: Bool { answer == question.noValue }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(rowAccent.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: question.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(rowAccent)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(question.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.primaryText)
                    .strikethrough(isChecked, color: rowAccent)
                    .lineLimit(1)

                if isChecked {
                    HStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { i in
                            Text("✦")
                                .font(.system(size: 9))
                                .foregroundStyle(rowAccent)
                                .opacity(0.7 + Double(i) * 0.1)
                        }
                    }
                }
            }

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                answerButton(
                    systemName: "checkmark",
                    selected: isChecked,
                    tint: Color(red: 0.35, green: 0.78, blue: 0.45),
                    disabled: isLocked
                ) {
                    guard !isLocked else { return }
                    HapticManager.shared.selection()
                    onYes()
                }

                answerButton(
                    systemName: "xmark",
                    selected: isFailed,
                    tint: Color(red: 0.92, green: 0.38, blue: 0.38),
                    disabled: isLocked
                ) {
                    guard !isLocked else { return }
                    HapticManager.shared.selection()
                    onNo()
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.isDark
                    ? Color.white.opacity(0.06)
                    : Color.white.opacity(0.70)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            isChecked ? rowAccent.opacity(0.30) : theme.coachSurfaceStroke.opacity(0.55),
                            lineWidth: 1
                        )
                }
        }
    }

    private var rowAccent: Color {
        if isChecked { return Color(red: 0.35, green: 0.78, blue: 0.45) }
        if isFailed { return Color(red: 0.92, green: 0.38, blue: 0.38) }
        return theme.secondaryText
    }

    private func answerButton(
        systemName: String,
        selected: Bool,
        tint: Color,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(selected ? .white : theme.secondaryText)
                .frame(width: 34, height: 34)
                .background {
                    Circle()
                        .fill(selected ? tint : theme.primaryText.opacity(theme.isDark ? 0.10 : 0.07))
                }
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
    }
}

// MARK: - Progress Ring

private struct CheckInProgressRing: View {
    let completedCount: Int
    let totalCount: Int

    @Environment(\.appTheme) private var theme

    private var fraction: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(theme.primaryText.opacity(0.08), lineWidth: 4)
                .frame(width: 42, height: 42)

            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    Color(red: 0.35, green: 0.78, blue: 0.45),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 42, height: 42)
                .animation(.spring(response: 0.4, dampingFraction: 0.78), value: fraction)

            Text("\(completedCount)/\(totalCount)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(theme.primaryText)
        }
    }
}

// MARK: - Main content (island)

struct ProcessEveningCheckInIslandContent: View {
    var targetDate: Date = Date()
    var isRequired: Bool = false
    var onCompleted: (() -> Void)? = nil

    @Environment(\.appTheme) private var theme
    @Bindable private var eveningStore = ProcessEveningCheckInStore.shared
    @Bindable private var streakStore = ProcessStreakStore.shared
    @Bindable private var trajectoryStore = ProcessDebloatTrajectoryStore.shared

    @State private var phase: Phase = .form
    @State private var answers: [String: String] = [:]
    @State private var analyzingLabel = "Enregistrement…"
    @State private var validationTask: Task<Void, Never>?
    @State private var submittedDayValidated = false
    @State private var hydrationPrefill: ProcessHydrationEveningPrefill?

    private enum Phase {
        case form
        case analyzing
        case validated
    }

    private var visibleQuestions: [EveningCheckInQuestion] {
        EveningCheckInQuestion.allCases
    }

    private var completedCount: Int {
        answers.values.filter { $0 == "yes" }.count
    }

    private var isFormComplete: Bool {
        EveningCheckInQuestionID.debloatLevers.allSatisfy { answers[$0] != nil }
            && answers[EveningCheckInQuestionID.morningRoutine] != nil
    }

    private var hasSubmittedTargetDate: Bool {
        eveningStore.hasSubmitted(on: targetDate)
    }

    var body: some View {
        Group {
            switch phase {
            case .form:
                formContent
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            case .analyzing:
                analyzingContent
                    .transition(.opacity)
            case .validated:
                validatedContent
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.46, dampingFraction: 0.86), value: phase)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .processAppPresentationBackground()
        .onAppear {
            applyInitialAnswers()
        }
        .onDisappear {
            validationTask?.cancel()
        }
    }

    // MARK: - Form

    private var formContent: some View {
        VStack(spacing: 0) {
            headerSection

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(visibleQuestions) { question in
                        if question == .water, let prefill = hydrationPrefill {
                            hydrationPrefillRow(prefill)
                        } else {
                            EveningCheckInHabitRow(
                                question: question,
                                answer: answers[question.id],
                                isLocked: false
                            ) {
                                answers[question.id] = question.yesValue
                            } onNo: {
                                answers[question.id] = question.noValue
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 8)
            }

            footerBlock
        }
    }

    private var headerSection: some View {
        VStack(spacing: 4) {
            HStack {
                CheckInProgressRing(
                    completedCount: completedCount,
                    totalCount: EveningCheckInQuestion.allCases.count
                )

                Spacer()

                if !isRequired {
                    Button {
                        ProcessEveningCheckInPresenter.shared.clear()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(theme.secondaryText.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)

            VStack(spacing: 4) {
                Text("Checklist du jour")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(theme.primaryText)
                    .multilineTextAlignment(.center)

                Text(subtitleText)
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
        }
    }

    private var subtitleText: String {
        if hydrationPrefill != nil {
            return "Eau suivie automatiquement · coche les autres missions"
        }
        return "Coche chaque mission accomplie aujourd'hui"
    }

    private func hydrationPrefillRow(_ prefill: ProcessHydrationEveningPrefill) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill((prefill.metTarget
                        ? Color(red: 0.35, green: 0.78, blue: 0.45)
                        : theme.secondaryText).opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: "drop.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(prefill.metTarget
                        ? Color(red: 0.35, green: 0.78, blue: 0.45)
                        : theme.secondaryText)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("3 L d'eau")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.primaryText)
                    .strikethrough(prefill.metTarget, color: Color(red: 0.35, green: 0.78, blue: 0.45))

                Text(prefill.litersLabel)
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
            }

            Spacer(minLength: 8)

            Text("Auto")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.secondaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule(style: .continuous)
                        .fill(theme.primaryText.opacity(theme.isDark ? 0.10 : 0.06))
                )
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.isDark
                    ? Color.white.opacity(0.06)
                    : Color.white.opacity(0.70)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            prefill.metTarget
                                ? Color(red: 0.35, green: 0.78, blue: 0.45).opacity(0.30)
                                : theme.coachSurfaceStroke.opacity(0.55),
                            lineWidth: 1
                        )
                }
        }
    }

    private var footerBlock: some View {
        Button(action: submitCheckIn) {
            Text(hasSubmittedTargetDate ? "Mettre à jour" : "Valider mon jour")
                .font(.headline.weight(.semibold))
                .foregroundStyle(isFormComplete ? Color.black : theme.primaryText.opacity(0.40))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background {
                    Capsule(style: .continuous)
                        .fill(isFormComplete ? Color.white : theme.primaryText.opacity(0.08))
                }
        }
        .buttonStyle(.plain)
        .disabled(!isFormComplete)
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 28)
    }

    // MARK: - Analyzing

    private var analyzingContent: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 80)

            ProgressView()
                .controlSize(.large)
                .tint(theme.onboardingAccent)

            Text(analyzingLabel)
                .font(.title3.weight(.semibold))
                .foregroundStyle(theme.primaryText)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Validated

    private var validatedContent: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 72)

            ZStack {
                Circle()
                    .fill(validatedAccent.opacity(0.18))
                    .frame(width: 88, height: 88)
                Image(systemName: validatedSymbol)
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(validatedAccent)
                    .symbolEffect(.bounce, value: phase)
            }

            VStack(spacing: 8) {
                Text(validatedTitle)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(theme.primaryText)

                Text(validatedSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Button(action: finishAndDismiss) {
                Text("Terminer")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Capsule(style: .continuous).fill(Color.white))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 18)
            .padding(.bottom, 28)
        }
        .padding(.horizontal, 18)
    }

    private var validatedAccent: Color {
        submittedDayValidated
            ? Color(red: 0.35, green: 0.78, blue: 0.45)
            : Color(red: 0.92, green: 0.58, blue: 0.28)
    }

    private var validatedSymbol: String {
        submittedDayValidated ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
    }

    private var validatedTitle: String {
        submittedDayValidated ? "Jour validé" : "Bilan enregistré"
    }

    private var validatedSubtitle: String {
        if !submittedDayValidated {
            let record = ProcessDebloatTrajectoryStore.shared.record(for: targetDate)
            let yesCount = record?.yesCount
                ?? ProcessDebloatTrajectoryEngine.yesCount(from: answers)
            if record?.water != true {
                return "Hydratation manquante — objectif 3 L requis pour valider."
            }
            if record?.debloatMeal != true {
                return "Repas debloat manquant — équilibre Na/K/Mg requis pour valider."
            }
            if let record,
               let failure = ProcessDebloatValidation.failure(
                for: record,
                consecutiveCardioMissesBefore: ProcessDebloatValidation.consecutiveCardioMisses(
                    before: record.dayKey,
                    in: ProcessDebloatTrajectoryStore.shared.allRecordsByDay
                )
               ) {
                return ProcessDebloatValidation.failureMessage(failure)
            }
            return "\(yesCount)/3 leviers — protocole debloat incomplet."
        }
        if let summary = ProcessDebloatTrajectoryStore.shared.record(for: targetDate)?.aiSummary {
            return summary
        }
        let snapshot = trajectoryStore.snapshot
        if Calendar.current.isDateInToday(targetDate), let verdict = snapshot.todayVerdict {
            return "\(verdict.shortLabel) — score \(Int(snapshot.todayCompositeScore))/100 · \(snapshot.totalValidatedDays) j validés"
        }
        return "Ta trajectoire debloat est à jour."
    }

    // MARK: - Actions

    private func applyInitialAnswers() {
        var next = eveningStore.answers(for: targetDate)
        let prefill = ProcessHydrationLogStore.shared.eveningCheckInPrefill(for: targetDate)
        hydrationPrefill = prefill
        if let prefill {
            next[EveningCheckInQuestionID.water] = prefill.answer
        }
        answers = next
    }

    private func submitCheckIn() {
        if let prefill = ProcessHydrationLogStore.shared.eveningCheckInPrefill(for: targetDate) {
            hydrationPrefill = prefill
            answers[EveningCheckInQuestionID.water] = prefill.answer
        }
        guard isFormComplete else { return }
        HapticManager.shared.impact(.medium)
        phase = .analyzing
        analyzingLabel = "Enregistrement…"

        validationTask?.cancel()
        validationTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }

            analyzingLabel = "Analyse de ton bilan…"
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }

            eveningStore.markSubmitted(answers: answers, for: targetDate)
            submittedDayValidated = ProcessDebloatTrajectoryStore.shared
                .record(for: targetDate)?
                .countsAsValidatedDay(
                    consecutiveCardioMissesBefore: ProcessDebloatValidation.consecutiveCardioMisses(
                        before: ProcessStreakStore.dayKey(for: targetDate),
                        in: ProcessDebloatTrajectoryStore.shared.allRecordsByDay
                    )
                ) == true
            onCompleted?()

            withAnimation(.spring(response: 0.44, dampingFraction: 0.82)) {
                phase = .validated
            }

            if submittedDayValidated {
                HapticManager.shared.notification(.success)
                ProcessSoundPlayer.playRevolutPaySuccess()
            } else {
                HapticManager.shared.notification(.warning)
            }

            try? await Task.sleep(for: .seconds(2.2))
            guard !Task.isCancelled else { return }
            finishAndDismiss()
        }
    }

    private func finishAndDismiss() {
        validationTask?.cancel()
        ProcessEveningCheckInPresenter.shared.clear()
    }
}

// MARK: - Compat wrapper (sheet)

/// Compat : redirige vers le presenter island. Conservé pour les sites d'appel qui instancient encore une sheet.
struct ProcessEveningCheckInSheet: View {
    var targetDate: Date = Date()
    var isRequired: Bool = false
    var onCompleted: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ProcessEveningCheckInIslandContent(
            targetDate: targetDate,
            isRequired: isRequired,
            onCompleted: {
                onCompleted?()
                dismiss()
            }
        )
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(44)
        .interactiveDismissDisabled(isRequired)
    }
}

// MARK: - Entry button

struct ProcessEveningCheckInEntryButton: View {
    var action: () -> Void

    @Environment(\.appTheme) private var theme
    @Bindable private var eveningStore = ProcessEveningCheckInStore.shared
    @Bindable private var streakStore = ProcessStreakStore.shared
    @Bindable private var trajectoryStore = ProcessDebloatTrajectoryStore.shared

    private var todayRecord: DebloatDayRecord? {
        trajectoryStore.record(for: Date())
    }

    private var isDayValidated: Bool {
        guard let record = todayRecord else { return false }
        return record.countsAsValidatedDay(
            consecutiveCardioMissesBefore: ProcessDebloatValidation.consecutiveCardioMisses(
                before: record.dayKey,
                in: trajectoryStore.allRecordsByDay
            )
        )
    }

    private var hasSubmittedToday: Bool {
        eveningStore.hasSubmittedToday
    }

    var body: some View {
        Button(action: {
            HapticManager.shared.impact(.light)
            action()
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(theme.onboardingAccent.opacity(theme.isDark ? 0.22 : 0.14))
                        .frame(width: 40, height: 40)
                    Image(systemName: entrySymbol)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(entrySymbolColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(entryTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.primaryText)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                if !isDayValidated, streakStore.displayValidatedDays > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption.weight(.bold))
                        Text("\(streakStore.displayValidatedDays)")
                            .font(.caption.weight(.bold))
                            .monospacedDigit()
                    }
                    .foregroundStyle(ProcessStreakPalette.flame)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(ProcessStreakPalette.flame.opacity(0.12), in: Capsule())
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.secondaryText.opacity(0.8))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(entryBackground)
        }
        .buttonStyle(ProcessGlassPressStyle())
        .accessibilityLabel(isDayValidated ? "Jour validé" : "Ouvrir le bilan du soir")
    }

    private var entrySymbol: String {
        if isDayValidated { return "checkmark.seal.fill" }
        if hasSubmittedToday { return "exclamationmark.circle.fill" }
        return "moon.stars.fill"
    }

    private var entrySymbolColor: Color {
        if isDayValidated {
            return Color(red: 0.35, green: 0.78, blue: 0.45)
        }
        if hasSubmittedToday {
            return Color(red: 0.92, green: 0.58, blue: 0.28)
        }
        return theme.onboardingAccent
    }

    private var entryTitle: String {
        if isDayValidated { return "Jour validé" }
        if hasSubmittedToday { return "Bilan enregistré" }
        return "Checklist du jour"
    }

    private var subtitle: String {
        if isDayValidated {
            return "Tu peux modifier tes réponses si besoin."
        }
        if hasSubmittedToday {
            return "Routine · 3 L · repas debloat · cardio."
        }
        return "Routine · 3 L d'eau · repas debloat · cardio."
    }

    @ViewBuilder
    private var entryBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        shape
            .fill(.clear)
            .processGlassEffect(in: shape, interactive: true)
    }
}
