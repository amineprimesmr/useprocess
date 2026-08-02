import SwiftUI

// MARK: - Modèle

private enum EveningCheckInQuestion: String, CaseIterable, Identifiable {
    case water
    case debloatMeal
    case cardio

    var id: String {
        switch self {
        case .water: return EveningCheckInQuestionID.water
        case .debloatMeal: return EveningCheckInQuestionID.debloatMeal
        case .cardio: return EveningCheckInQuestionID.cardio
        }
    }

    var yesValue: String { "yes" }
    var noValue: String { "no" }

    func prompt() -> String {
        switch self {
        case .water:
            return "Bu \(ProcessDailyTargets.hydrationLabel) d'eau ?"
        case .debloatMeal:
            return "Respecté tes repas debloat ?"
        case .cardio:
            return "Marche inclinée \(DebloatCardioDayCatalog.durationMinutes) min (\(DebloatCardioDayCatalog.inclinePercent)%) ?"
        }
    }
}

/// Bilan du soir — 3 questions binaires, tout visible sans scroll.
struct ProcessEveningCheckInSheet: View {
    var targetDate: Date = Date()
    var isRequired: Bool = false
    var onCompleted: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
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

    enum Metrics {
        static let sheetHeight: CGFloat = 340
        static let cornerRadius: CGFloat = 28
        static let rowShape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        static let rowHeight: CGFloat = 52
    }

    private var visibleQuestions: [EveningCheckInQuestion] {
        EveningCheckInQuestion.allCases.filter { question in
            if question == .water, hydrationPrefill != nil {
                return false
            }
            return true
        }
    }

    private var isFormComplete: Bool {
        visibleQuestions.allSatisfy { answers[$0.id] != nil }
            && answers[EveningCheckInQuestionID.water] != nil
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
        .presentationDetents([.height(Metrics.sheetHeight)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(Metrics.cornerRadius)
        .interactiveDismissDisabled(phase == .analyzing || (isRequired && phase != .validated))
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
            headerRow

            VStack(spacing: 10) {
                if let hydrationPrefill {
                    hydrationPrefillRow(hydrationPrefill)
                }

                ForEach(visibleQuestions) { question in
                    questionRow(question)
                }
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 0)

            footerBlock
        }
    }

    private func questionRow(_ question: EveningCheckInQuestion) -> some View {
        HStack(spacing: 12) {
            Text(questionTitle(question))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.9)

            Spacer(minLength: 8)

            HStack(spacing: 10) {
                answerIconButton(
                    systemName: "checkmark",
                    selected: answers[question.id] == question.yesValue,
                    tint: Color(red: 0.35, green: 0.78, blue: 0.45)
                ) {
                    answers[question.id] = question.yesValue
                }

                answerIconButton(
                    systemName: "xmark",
                    selected: answers[question.id] == question.noValue,
                    tint: Color(red: 0.92, green: 0.38, blue: 0.38)
                ) {
                    answers[question.id] = question.noValue
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: Metrics.rowHeight)
        .frame(maxWidth: .infinity)
        .processEveningCheckInGlass(in: Metrics.rowShape)
    }

    private func questionTitle(_ question: EveningCheckInQuestion) -> String {
        question.prompt()
    }

    private func hydrationPrefillRow(_ prefill: ProcessHydrationEveningPrefill) -> some View {
        HStack(spacing: 12) {
            Image(systemName: prefill.metTarget ? "drop.fill" : "drop")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(
                    prefill.metTarget
                        ? Color(red: 0.35, green: 0.78, blue: 0.45)
                        : theme.secondaryText
                )

            Text(prefill.statusLine)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.9)

            Spacer(minLength: 8)

            Text("Auto")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.secondaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(theme.primaryText.opacity(theme.isDark ? 0.1 : 0.06))
                )
        }
        .padding(.horizontal, 14)
        .frame(height: Metrics.rowHeight)
        .frame(maxWidth: .infinity)
        .processEveningCheckInGlass(in: Metrics.rowShape)
        .accessibilityLabel(prefill.statusLine)
        .accessibilityHint("Réponse remplie depuis ton suivi d'eau dans l'app")
    }

    private func applyInitialAnswers() {
        var next = eveningStore.answers(for: targetDate)
        let prefill = ProcessHydrationLogStore.shared.eveningCheckInPrefill(for: targetDate)
        hydrationPrefill = prefill
        if let prefill {
            // Le suivi Accueil prime sur une ancienne réponse manuelle non soumise.
            next[EveningCheckInQuestionID.water] = prefill.answer
        }
        answers = next
    }

    private func answerIconButton(
        systemName: String,
        selected: Bool,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticManager.shared.selection()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(selected ? .white : theme.secondaryText)
                .frame(width: 36, height: 36)
                .background {
                    Circle()
                        .fill(selected ? tint : theme.primaryText.opacity(theme.isDark ? 0.1 : 0.06))
                }
                .overlay {
                    Circle()
                        .strokeBorder(
                            selected ? tint.opacity(0.5) : theme.coachSurfaceStroke.opacity(0.5),
                            lineWidth: selected ? 0 : 0.75
                        )
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var isYesterdayCheckIn: Bool {
        Calendar.current.isDateInYesterday(targetDate)
    }

    private var headerRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(titleText)
                .font(.title3.weight(.bold))
                .foregroundStyle(theme.primaryText)

            if !isYesterdayCheckIn {
                Text(subtitleText)
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
            }

            if !isYesterdayCheckIn, streakStore.displayValidatedDays > 0, !hasSubmittedTargetDate {
                Text("\(streakStore.displayValidatedDays) jour\(streakStore.displayValidatedDays > 1 ? "s" : "") validé\(streakStore.displayValidatedDays > 1 ? "s" : "") · valide ce soir")
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 16)
    }

    private var titleText: String {
        if isYesterdayCheckIn {
            return "Hier tu as…"
        }
        if Calendar.current.isDateInToday(targetDate) {
            return "Bilan du soir"
        }
        return "Bilan du \(Self.shortDateFormatter.string(from: targetDate))"
    }

    private var subtitleText: String {
        if hydrationPrefill != nil {
            return "Eau déjà suivie · repas debloat obligatoire · cardio idéal chaque jour (min. 3/sem)."
        }
        return "Eau + repas debloat obligatoires · cardio idéal chaque jour (min. 3/sem)."
    }

    private var footerBlock: some View {
        Button(action: submitCheckIn) {
            Text(hasSubmittedTargetDate ? "Mettre à jour" : "Valider mon bilan")
                .font(.headline.weight(.semibold))
                .foregroundStyle(theme.primaryText.opacity(isFormComplete ? 0.92 : 0.45))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .processEveningCheckInGlass(
                    in: Capsule(style: .continuous),
                    interactive: isFormComplete,
                    selected: false
                )
        }
        .buttonStyle(.plain)
        .disabled(!isFormComplete)
        .accessibilityLabel("Valider mon bilan du soir")
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 24)
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

            Text("On enregistre ton bilan.")
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)

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
                    .foregroundStyle(theme.primaryText.opacity(0.92))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .processEveningCheckInGlass(
                        in: Capsule(style: .continuous),
                        interactive: true,
                        selected: false
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 22)
        }
        .padding(.horizontal, 20)
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
                return "Hydratation manquante — objectif eau requis pour valider."
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

    private func submitCheckIn() {
        // Re-sync eau depuis l'Accueil au moment de valider.
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
        dismiss()
    }

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "d MMM"
        return formatter
    }()
}

// MARK: - Glass

private struct ProcessEveningCheckInGlassModifier<S: InsettableShape>: ViewModifier {
    @Environment(\.appTheme) private var theme

    let shape: S
    let interactive: Bool
    let selected: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(
                    interactive ? ProcessGlass.regular : ProcessGlass.regularSurface,
                    in: shape
                )
                .overlay {
                    if selected {
                        shape.strokeBorder(Color.primary.opacity(0.24), lineWidth: 1.2)
                    } else if !theme.isDark {
                        shape.strokeBorder(theme.coachSurfaceStroke.opacity(0.72), lineWidth: 0.75)
                    }
                }
        } else {
            content
                .processGlassEffect(in: shape, interactive: interactive)
                .overlay {
                    if selected {
                        shape.strokeBorder(Color.primary.opacity(0.22), lineWidth: 1)
                    }
                }
        }
    }
}

private extension View {
    func processEveningCheckInGlass<S: InsettableShape>(
        in shape: S,
        interactive: Bool = false,
        selected: Bool = false
    ) -> some View {
        modifier(
            ProcessEveningCheckInGlassModifier(
                shape: shape,
                interactive: interactive,
                selected: selected
            )
        )
    }
}

// MARK: - Bouton d'entrée

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
        return "Bilan du soir"
    }

    private var subtitle: String {
        if isDayValidated {
            return "Tu peux modifier tes réponses si besoin."
        }
        if hasSubmittedToday {
            return "Eau + repas debloat obligatoires. Cardio idéal chaque jour · min. 3/semaine."
        }
        if isEveningWindow {
            return "Eau · repas Na/K/Mg · marche inclinée \(DebloatCardioDayCatalog.durationMinutes) min (\(DebloatCardioDayCatalog.inclinePercent)%)."
        }
        return "Protocole debloat : hydratation + alimentation obligatoires."
    }

    private var isEveningWindow: Bool {
        ProcessEveningCheckInSchedule.isAvailable()
    }

    @ViewBuilder
    private var entryBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        shape
            .fill(.clear)
            .processGlassEffect(in: shape, interactive: true)
    }
}
