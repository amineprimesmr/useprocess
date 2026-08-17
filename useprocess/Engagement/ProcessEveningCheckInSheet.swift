import SwiftUI

enum EveningCheckInFormHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private enum EveningCheckInIslandContentMetrics {
    static let topPadding: CGFloat = 24
    static let bottomPadding: CGFloat = 22
}

// MARK: - Modèle

private enum EveningCheckInQuestion: String, CaseIterable, Identifiable {
    case faceScan
    case morningRoutine
    case water
    case debloatMeal

    var id: String {
        switch self {
        case .faceScan: return EveningCheckInQuestionID.faceScan
        case .morningRoutine: return EveningCheckInQuestionID.morningRoutine
        case .water: return EveningCheckInQuestionID.water
        case .debloatMeal: return EveningCheckInQuestionID.debloatMeal
        }
    }

    var yesValue: String { "yes" }
    var noValue: String { "no" }

    var title: String {
        switch self {
        case .faceScan:
            return AppCopy.t("Scan du jour", en: "Today's scan")
        case .morningRoutine:
            return AppCopy.t("Circuit lymphatique", en: "Lymphatic circuit")
        case .water:
            return AppCopy.t("\(ProcessDailyTargets.hydrationLabel) d'eau", en: "\(ProcessDailyTargets.hydrationLabel) of water")
        case .debloatMeal:
            return AppCopy.t("Repas debloat", en: "Debloat Meal")
        }
    }

    var systemImage: String {
        switch self {
        case .faceScan: return "faceid"
        case .morningRoutine: return "drop.fill"
        case .water: return "drop.fill"
        case .debloatMeal: return "fork.knife"
        }
    }
}

// MARK: - Contenu (capsule Dynamic Island)

struct ProcessEveningCheckInIslandContent: View {
    var targetDate: Date = Date()
    var isRequired: Bool = false
    var isExpanded: Bool = true
    var submitShakeNudge: Int = 0
    var onSubmitted: (() -> Void)? = nil
    var onFinished: (() -> Void)? = nil

    @Bindable private var eveningStore = ProcessEveningCheckInStore.shared
    @Bindable private var trajectoryStore = ProcessDebloatTrajectoryStore.shared
    @Bindable private var faceScanStore = FaceScanHistoryStore.shared

    @State private var phase: Phase = .form
    @State private var answers: [String: String] = [:]
    @State private var analyzingLabel = AppCopy.t("Enregistrement…", en: "Saving…")
    @State private var validationTask: Task<Void, Never>?
    @State private var submittedDayValidated = false
    @State private var hydrationPrefill: ProcessHydrationEveningPrefill?
    @State private var submitShakeTicks: CGFloat = 0

    private enum Phase: Equatable {
        case form
        case analyzing
        case validated
    }

    private var visibleQuestions: [EveningCheckInQuestion] {
        EveningCheckInQuestion.allCases.filter { $0 != .water && $0 != .faceScan }
    }

    private var hasSubmittedTargetDate: Bool {
        eveningStore.hasSubmitted(on: targetDate)
    }

    private var isYesterdayCheckIn: Bool {
        Calendar.current.isDateInYesterday(targetDate)
    }

    var body: some View {
        Group {
            switch phase {
            case .form:
                formContent
                    .fixedSize(horizontal: false, vertical: true)
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
        .frame(maxWidth: .infinity, maxHeight: phase == .form ? nil : .infinity, alignment: .top)
        .padding(.top, EveningCheckInIslandContentMetrics.topPadding)
        .padding(.bottom, EveningCheckInIslandContentMetrics.bottomPadding)
        .onAppear {
            applyInitialAnswers()
        }
        .onChange(of: isExpanded) { _, expanded in
            guard expanded, phase == .form else { return }
            applyInitialAnswers()
        }
        .onChange(of: submitShakeNudge) { _, _ in
            shakeSubmitButton()
        }
    }

    // MARK: - Form

    private var formContent: some View {
        VStack(spacing: 0) {
            headerRow

            VStack(spacing: 14) {
                EveningCheckInHabitRow(
                    title: EveningCheckInQuestion.faceScan.title,
                    systemImage: EveningCheckInQuestion.faceScan.systemImage,
                    isChecked: isFaceScanChecked,
                    isLocked: isFaceScanLocked,
                    subtitle: faceScanSubtitle
                ) {
                    handleFaceScanTap()
                }

                if let hydrationPrefill {
                    EveningCheckInHabitRow(
                        title: AppCopy.t("\(ProcessDailyTargets.hydrationLabel) d'eau", en: "\(ProcessDailyTargets.hydrationLabel) of water"),
                        systemImage: "drop.fill",
                        isChecked: hydrationPrefill.metTarget,
                        isLocked: hydrationPrefill.metTarget,
                        subtitle: hydrationPrefill.litersLabel
                    ) {
                        completeHydrationFromChecklist()
                    }
                }

                ForEach(visibleQuestions) { question in
                    EveningCheckInHabitRow(
                        title: question.title,
                        systemImage: question.systemImage,
                        isChecked: answers[question.id] == question.yesValue,
                        isLocked: false
                    ) {
                        toggleQuestion(question)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 8)

            footerBlock
                .padding(.top, 14)
                .padding(.bottom, 4)
        }
        .background {
            GeometryReader { geo in
                Color.clear.preference(
                    key: EveningCheckInFormHeightKey.self,
                    value: geo.size.height
                        + EveningCheckInIslandContentMetrics.topPadding
                        + EveningCheckInIslandContentMetrics.bottomPadding
                )
            }
        }
    }

    private var checklistTotalCount: Int {
        visibleQuestions.count + 2
    }

    private var checklistDoneCount: Int {
        var count = 0
        if isFaceScanChecked { count += 1 }
        if let hydrationPrefill, hydrationPrefill.metTarget {
            count += 1
        }
        for question in visibleQuestions where answers[question.id] == question.yesValue {
            count += 1
        }
        return count
    }

    private var hasFaceScanOnTargetDate: Bool {
        FaceScanCadence.hasScan(on: targetDate, in: faceScanStore.history)
    }

    private var isFaceScanLocked: Bool {
        if hasFaceScanOnTargetDate { return true }
        if Calendar.current.isDateInToday(targetDate), !faceScanStore.canStartTodayScan {
            return true
        }
        return false
    }

    private var isFaceScanChecked: Bool {
        hasFaceScanOnTargetDate
            || answers[EveningCheckInQuestionID.faceScan] == EveningCheckInQuestion.faceScan.yesValue
    }

    private var faceScanSubtitle: String {
        if hasFaceScanOnTargetDate {
            return Calendar.current.isDateInToday(targetDate)
                ? AppCopy.t("Fait aujourd'hui", en: "Done today")
                : AppCopy.t("Scan enregistré", en: "Scan saved")
        }
        if Calendar.current.isDateInToday(targetDate), !faceScanStore.canStartTodayScan {
            return AppCopy.t("Disponible à partir de 6h", en: "Available from 6 AM")
        }
        if Calendar.current.isDateInToday(targetDate) {
            return AppCopy.t("1 scan · matin, même lumière", en: "1 scan · morning, same light")
        }
        return AppCopy.t("Pas encore scanné", en: "Not scanned yet")
    }

    private var headerRow: some View {
        VStack(spacing: 10) {
            EveningCheckInProgressRing(
                done: checklistDoneCount,
                total: max(checklistTotalCount, 1)
            )
            .padding(.bottom, 4)

            Text(titleText)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(subtitleText)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.white.opacity(0.78))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 10)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private var titleText: String {
        if isYesterdayCheckIn {
            return AppCopy.t("Checklist d'hier", en: "Yesterday's Checklist")
        }
        if Calendar.current.isDateInToday(targetDate) {
            return AppCopy.t("Checklist du jour", en: "Today's Checklist")
        }
        return AppCopy.t("Checklist du \(Self.shortDateFormatter.string(from: targetDate))", en: "Checklist for \(Self.shortDateFormatter.string(from: targetDate))")
    }

    private var subtitleText: String {
        if isYesterdayCheckIn {
            return AppCopy.t("Termine les tâches pour garder ta série intacte.", en: "Complete the tasks to keep your streak intact.")
        }
        if checklistDoneCount >= checklistTotalCount, checklistTotalCount > 0 {
            return AppCopy.t("Tout est coché — valide pour enregistrer ta journée.", en: "Everything is checked — validate your day to save it.")
        }
        return AppCopy.t("Coche tes tâches pour valider ta journée et ta série.", en: "Check off your tasks to validate your day and streak.")
    }

    private func applyInitialAnswers() {
        var next = eveningStore.answers(for: targetDate)
        let prefill = ProcessHydrationLogStore.shared.eveningCheckInPrefill(
            for: targetDate,
            healthKitLiters: hydrationHealthKitLiters(for: targetDate)
        )
        hydrationPrefill = prefill
        if prefill.metTarget {
            next[EveningCheckInQuestionID.water] = EveningCheckInQuestion.water.yesValue
        } else if next[EveningCheckInQuestionID.water] == EveningCheckInQuestion.water.yesValue {
            ProcessHydrationLogStore.shared.applyEveningCheckInWaterAnswer(
                EveningCheckInQuestion.water.yesValue,
                for: targetDate,
                dayId: programDayId(for: targetDate)
            )
            let filled = ProcessHydrationLogStore.shared.eveningCheckInPrefill(
                for: targetDate,
                healthKitLiters: hydrationHealthKitLiters(for: targetDate)
            )
            hydrationPrefill = filled
            next[EveningCheckInQuestionID.water] = filled.metTarget
                ? EveningCheckInQuestion.water.yesValue
                : EveningCheckInQuestion.water.noValue
        } else {
            next[EveningCheckInQuestionID.water] = EveningCheckInQuestion.water.noValue
        }
        if next[EveningCheckInQuestionID.morningRoutine] == nil,
           morningRoutinePrefillAnswer(for: targetDate) == EveningCheckInQuestion.morningRoutine.yesValue {
            next[EveningCheckInQuestionID.morningRoutine] = EveningCheckInQuestion.morningRoutine.yesValue
        }
        next[EveningCheckInQuestionID.faceScan] = hasFaceScanOnTargetDate
            ? EveningCheckInQuestion.faceScan.yesValue
            : EveningCheckInQuestion.faceScan.noValue
        // Non répondu = non validé (pas de croix).
        for question in EveningCheckInQuestion.allCases where next[question.id] == nil {
            next[question.id] = question.noValue
        }
        answers = next
    }

    private func morningRoutinePrefillAnswer(for date: Date) -> String? {
        guard let plan = WelcomePlanStore.shared.plan else { return nil }
        guard let day = OriginPlanPresenter.programDay(in: plan, for: date)
            ?? OriginPlanPresenter.todayDay(in: plan, date: date)
        else { return nil }
        let taskId = "\(day.id).core.morning"
        return plan.progress.status(for: taskId, dayId: day.id) == .completed
            ? EveningCheckInQuestion.morningRoutine.yesValue
            : nil
    }

    private func toggleQuestion(_ question: EveningCheckInQuestion) {
        let isYes = answers[question.id] == question.yesValue
        withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
            answers[question.id] = isYes ? question.noValue : question.yesValue
        }
        if question == .water, !isYes {
            completeHydrationFromChecklist()
            return
        }
        if question == .faceScan, !isYes {
            handleFaceScanTap()
            return
        }
        if isYes {
            HapticManager.shared.selection()
        } else {
            HapticManager.shared.impact(.medium)
        }
    }

    private func completeHydrationFromChecklist() {
        guard hydrationPrefill?.metTarget != true else { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
            answers[EveningCheckInQuestionID.water] = EveningCheckInQuestion.water.yesValue
        }
        HapticManager.shared.impact(.medium)
        syncWaterFromChecklistToHome()
    }

    private func handleFaceScanTap() {
        if hasFaceScanOnTargetDate { return }
        if Calendar.current.isDateInToday(targetDate) {
            guard faceScanStore.canStartTodayScan else { return }
            HapticManager.shared.impact(.medium)
            ProcessEveningCheckInPresenter.shared.dismissImmediately()
            PlanHomeTutorialStore.shared.schedulePresentationIfNeeded(
                planAvailable: WelcomePlanStore.shared.plan != nil,
                preferImmediate: true
            )
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
                CoachPlanNavigationBridge.shared.requestHomeFaceScan()
            }
            return
        }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
            answers[EveningCheckInQuestionID.faceScan] = EveningCheckInQuestion.faceScan.yesValue
        }
        HapticManager.shared.impact(.medium)
    }

    private func syncWaterFromChecklistToHome() {
        ProcessHydrationLogStore.shared.applyEveningCheckInWaterAnswer(
            EveningCheckInQuestion.water.yesValue,
            for: targetDate,
            dayId: programDayId(for: targetDate)
        )
        hydrationPrefill = ProcessHydrationLogStore.shared.eveningCheckInPrefill(
            for: targetDate,
            healthKitLiters: hydrationHealthKitLiters(for: targetDate)
        )
        if Calendar.current.isDateInToday(targetDate) {
            Task { await ProcessHydrationTimerStore.shared.syncLiveActivityHydration() }
        }
    }

    private func hydrationHealthKitLiters(for date: Date) -> Double {
        guard Calendar.current.isDateInToday(date) else { return 0 }
        return HealthManager.shared.todaySnapshot.nutrition.waterLiters
    }

    private func programDayId(for date: Date) -> String? {
        guard let plan = WelcomePlanStore.shared.plan else { return nil }
        guard let day = OriginPlanPresenter.programDay(in: plan, for: date)
            ?? OriginPlanPresenter.todayDay(in: plan, date: date)
        else { return nil }
        return day.id
    }

    private var footerBlock: some View {
        let shape = Capsule(style: .continuous)
        return Button {
            guard phase == .form else { return }
            submitCheckIn()
        } label: {
            Text(hasSubmittedTargetDate ? AppCopy.t("Mettre à jour", en: "Update") : AppCopy.t("Valider mon jour", en: "Validate My Day"))
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(shape.fill(Color.white))
                .contentShape(shape)
        }
        .buttonStyle(.processPlain)
        .modifier(EveningCheckInSubmitShakeEffect(shakes: submitShakeTicks))
        .allowsHitTesting(phase == .form)
        .accessibilityLabel(AppCopy.t("Valider mon jour", en: "Validate My Day"))
        .padding(.horizontal, 16)
    }

    // MARK: - Analyzing

    private var analyzingContent: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 40)

            ProgressView()
                .controlSize(.large)
                .tint(ProcessStreakPalette.flame)

            Text(analyzingLabel)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(AppCopy.t("On enregistre ton check.", en: "We're saving your check-in."))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))

            Spacer()
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Validated

    private var validatedContent: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 28)

            ZStack {
                Circle()
                    .fill(validatedAccent.opacity(0.22))
                    .frame(width: 84, height: 84)
                Image(systemName: validatedSymbol)
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(validatedAccent)
                    .symbolEffect(.bounce, value: phase)
            }

            VStack(spacing: 8) {
                Text(validatedTitle)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                Text(validatedSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
            }

            Spacer(minLength: 12)

            Button(action: finishAndDismiss) {
                Text(AppCopy.done)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.95))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .contentShape(Capsule(style: .continuous))
            }
            .buttonStyle(.processPlain)
            .processGlassEffect(in: Capsule(style: .continuous), interactive: false)
            .padding(.horizontal, 16)
        }
        .padding(.horizontal, 16)
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
        submittedDayValidated ? AppCopy.t("Jour validé", en: "Day Validated") : AppCopy.t("Check enregistré", en: "Check-In Saved")
    }

    private var validatedSubtitle: String {
        if !submittedDayValidated {
            let record = ProcessDebloatTrajectoryStore.shared.record(for: targetDate)
            let yesCount = record?.yesCount
                ?? ProcessDebloatTrajectoryEngine.yesCount(from: answers)
            if record?.water != true {
                return AppCopy.t("Hydratation manquante — objectif eau requis pour valider.", en: "Hydration is missing — your water goal is required to validate.")
            }
            if record?.debloatMeal != true {
                return AppCopy.t("Repas debloat manquant — équilibre Na/K/Mg requis pour valider.", en: "Debloat meal is missing — Na/K/Mg balance is required to validate.")
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
            return AppCopy.t("\(yesCount)/3 leviers — protocole debloat incomplet.", en: "\(yesCount)/3 levers — debloat protocol incomplete.")
        }
        if let summary = ProcessDebloatTrajectoryStore.shared.record(for: targetDate)?.aiSummary {
            return summary
        }
        let snapshot = trajectoryStore.snapshot
        if Calendar.current.isDateInToday(targetDate), let verdict = snapshot.todayVerdict {
            return AppCopy.t("\(verdict.shortLabel) — score \(Int(snapshot.todayCompositeScore))/100 · \(snapshot.totalValidatedDays) j validés", en: "\(verdict.shortLabel) — score \(Int(snapshot.todayCompositeScore))/100 · \(snapshot.totalValidatedDays) validated days")
        }
        return AppCopy.t("Ta trajectoire debloat est à jour.", en: "Your debloat trajectory is up to date.")
    }

    // MARK: - Actions

    private func submitCheckIn() {
        if answers[EveningCheckInQuestionID.water] == EveningCheckInQuestion.water.yesValue {
            syncWaterFromChecklistToHome()
        }
        let prefill = ProcessHydrationLogStore.shared.eveningCheckInPrefill(
            for: targetDate,
            healthKitLiters: hydrationHealthKitLiters(for: targetDate)
        )
        hydrationPrefill = prefill
        answers[EveningCheckInQuestionID.water] = prefill.metTarget
            ? EveningCheckInQuestion.water.yesValue
            : EveningCheckInQuestion.water.noValue
        answers[EveningCheckInQuestionID.faceScan] = hasFaceScanOnTargetDate
            ? EveningCheckInQuestion.faceScan.yesValue
            : (answers[EveningCheckInQuestionID.faceScan] == EveningCheckInQuestion.faceScan.yesValue
               ? EveningCheckInQuestion.faceScan.yesValue
               : EveningCheckInQuestion.faceScan.noValue)
        for question in EveningCheckInQuestion.allCases where answers[question.id] == nil {
            answers[question.id] = question.noValue
        }
        HapticManager.shared.impact(.medium)

        // Persister tout de suite — sinon un remount / cancel laisse le jour non validé.
        eveningStore.markSubmitted(answers: answers, for: targetDate)
        submittedDayValidated = ProcessDebloatTrajectoryStore.shared
            .record(for: targetDate)?
            .countsAsValidatedDay(
                consecutiveCardioMissesBefore: ProcessDebloatValidation.consecutiveCardioMisses(
                    before: ProcessStreakStore.dayKey(for: targetDate),
                    in: ProcessDebloatTrajectoryStore.shared.allRecordsByDay
                )
            ) == true
        onSubmitted?()

        phase = .analyzing
        analyzingLabel = AppCopy.t("Enregistrement…", en: "Saving…")

        validationTask?.cancel()
        validationTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }

            analyzingLabel = AppCopy.t("Analyse de ton check…", en: "Analyzing your check-in…")
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }

            withAnimation(.spring(response: 0.44, dampingFraction: 0.82)) {
                phase = .validated
            }

            if submittedDayValidated {
                HapticManager.shared.notification(.success)
                ProcessSoundPlayer.playRevolutPaySuccess()
            } else {
                HapticManager.shared.notification(.warning)
            }

            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            finishAndDismiss()
        }
    }

    private func finishAndDismiss() {
        validationTask?.cancel()
        onFinished?()
    }

    private func shakeSubmitButton() {
        HapticManager.shared.notification(.warning)
        withAnimation(.default) {
            submitShakeTicks += 1
        }
    }

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = ProcessAppLanguage.shared.locale
        formatter.dateFormat = "d MMM"
        return formatter
    }()
}

private struct EveningCheckInSubmitShakeEffect: GeometryEffect {
    var shakes: CGFloat
    var amount: CGFloat = 10
    var shakesPerUnit: CGFloat = 3

    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(
                translationX: amount * sin(shakes * .pi * shakesPerUnit),
                y: 0
            )
        )
    }
}

// MARK: - Progress ring (header)

private struct EveningCheckInProgressRing: View {
    let done: Int
    let total: Int

    private let ringSize: CGFloat = 88
    private let lineWidth: CGFloat = 5
    private let arcBlue = Color(red: 0.58, green: 0.76, blue: 1.0)

    private var progress: CGFloat {
        guard total > 0 else { return 0 }
        return min(1, max(0, CGFloat(done) / CGFloat(total)))
    }

    var body: some View {
        ZStack {
            if progress > 0.001 {
                // Glow sous l’arc uniquement (pas de cercle plein).
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        arcBlue.opacity(0.32),
                        style: StrokeStyle(lineWidth: lineWidth + 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .blur(radius: 3)

                EveningCheckInProgressArc(
                    progress: progress,
                    lineWidth: lineWidth,
                    color: arcBlue
                )
            }

            Text("\(done)/\(total)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.spring(response: 0.4, dampingFraction: 0.82), value: done)
        }
        .frame(width: ringSize, height: ringSize)
        .animation(.spring(response: 0.48, dampingFraction: 0.82), value: progress)
        .accessibilityLabel(AppCopy.t("\(done) sur \(total) tâches cochées", en: "\(done) of \(total) tasks checked"))
    }
}

/// Un seul arc (pas un cercle fermé) avec fondu aux extrémités.
private struct EveningCheckInProgressArc: View, Animatable {
    var progress: CGFloat
    var lineWidth: CGFloat
    var color: Color

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        Canvas { context, size in
            let clamped = min(1, max(0, progress))
            guard clamped > 0.001 else { return }

            let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
            let radius = (min(size.width, size.height) - lineWidth) * 0.5

            // Fondu début / fin le long de l’arc.
            let fadeCount = 24
            for i in 0..<fadeCount {
                let t0 = CGFloat(i) / CGFloat(fadeCount)
                let t1 = CGFloat(i + 1) / CGFloat(fadeCount)
                let mid = (t0 + t1) * 0.5
                let opacity = Self.tipFade(along: mid)
                guard opacity > 0.02 else { continue }

                let a0 = Angle.degrees(-90 + 360 * clamped * Double(t0))
                let a1 = Angle.degrees(-90 + 360 * clamped * Double(t1))

                var segment = Path()
                segment.addArc(
                    center: center,
                    radius: radius,
                    startAngle: a0,
                    endAngle: a1,
                    clockwise: false
                )

                context.stroke(
                    segment,
                    with: .color(color.opacity(opacity)),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                )
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    /// Fondu sur ~18 % au début et à la fin de l’arc.
    private static func tipFade(along t: CGFloat) -> Double {
        let edge: CGFloat = 0.18
        if t < edge { return Double(t / edge) }
        if t > 1 - edge { return Double((1 - t) / edge) }
        return 1
    }
}

// MARK: - Habit row (check + strikethrough + sparks)

private struct EveningCheckInHabitRow: View {
    let title: String
    let systemImage: String
    let isChecked: Bool
    var isLocked: Bool = false
    var subtitle: String? = nil
    var onToggle: (() -> Void)? = nil

    @State private var strikeProgress: CGFloat = 0
    @State private var textWidth: CGFloat = 0
    @State private var checkScale: CGFloat = 1
    @State private var sparksLive = false

    private let doneGreen = Color(red: 0.30, green: 0.82, blue: 0.48)
    private let strikeDuration: TimeInterval = 0.95

    var body: some View {
        Button {
            guard !isLocked else { return }
            onToggle?()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(isChecked ? 0.38 : 0.78))
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    titleStrikeBlock
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let subtitle {
                        Text(subtitle)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.42))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                checkControl
                    .offset(y: 2)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(minHeight: 68)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(isChecked ? 0.05 : 0.08))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)
            }
        }
        .buttonStyle(.processPlain)
        .disabled(isLocked)
        .accessibilityLabel(title)
        .accessibilityValue(isChecked ? AppCopy.t("Validé", en: "Validated") : AppCopy.t("Non validé", en: "Not validated"))
        .accessibilityAddTraits(isChecked ? .isSelected : [])
        .onAppear {
            strikeProgress = isChecked ? 1 : 0
            sparksLive = false
            checkScale = 1
        }
        .onChange(of: isChecked) { _, checked in
            if checked {
                sparksLive = true
                withAnimation(.spring(response: 0.28, dampingFraction: 0.62)) {
                    checkScale = 1.12
                }
                withAnimation(.easeInOut(duration: strikeDuration)) {
                    strikeProgress = 1
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                        checkScale = 1
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + strikeDuration + 0.12) {
                    withAnimation(.easeOut(duration: 0.28)) {
                        sparksLive = false
                    }
                }
            } else {
                sparksLive = false
                withAnimation(.easeIn(duration: 0.2)) {
                    strikeProgress = 0
                    checkScale = 1
                }
            }
        }
    }

    private var titleStrikeBlock: some View {
        Text(title)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(isChecked ? Color.white.opacity(0.42) : Color.white.opacity(0.94))
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .background {
                // Mesure la largeur intrinsèque du texte (pas toute la row).
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .hidden()
                    .background {
                        GeometryReader { geo in
                            Color.clear
                                .preference(key: EveningCheckInTextWidthKey.self, value: geo.size.width)
                        }
                    }
            }
            .onPreferenceChange(EveningCheckInTextWidthKey.self) { textWidth = $0 }
            .overlay(alignment: .leading) {
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Color.white)
                        .frame(width: max(0, textWidth * strikeProgress), height: 2.4)
                        .shadow(color: .white.opacity(0.8), radius: 3.5, y: 0)

                    // Étincelles hors du texte — pas de clip pour qu’elles “sortent”.
                    EveningCheckInTravelingSparks(
                        progress: strikeProgress,
                        textWidth: textWidth,
                        isActive: sparksLive
                    )
                    .frame(width: max(textWidth + 28, 1), height: 44)
                    .offset(x: -6, y: -11)
                }
                .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 22, alignment: .leading)
    }

    private var checkControl: some View {
        ZStack {
            if isChecked {
                Circle()
                    .fill(doneGreen)
                    .frame(width: 34, height: 34)
                    .shadow(color: doneGreen.opacity(0.45), radius: 8, y: 2)

                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Circle()
                    .strokeBorder(
                        Color.white.opacity(0.28),
                        style: StrokeStyle(lineWidth: 1.6, dash: [3.2, 2.6])
                    )
                    .frame(width: 34, height: 34)

                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.48))
            }
        }
        .scaleEffect(checkScale)
        .animation(.spring(response: 0.36, dampingFraction: 0.72), value: isChecked)
    }
}

private struct EveningCheckInTextWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Étincelles qui partent de la pointe du trait et s’éloignent.
private struct EveningCheckInTravelingSparks: View {
    var progress: CGFloat
    var textWidth: CGFloat
    var isActive: Bool

    private struct Spark: Identifiable {
        let id: Int
        let angle: Double
        let speed: CGFloat
        let size: CGFloat
        let phase: Double
        let birthOffset: Double
    }

    private let sparks: [Spark] = [
        .init(id: 0, angle: -1.15, speed: 18, size: 2.8, phase: 0.0, birthOffset: 0.00),
        .init(id: 1, angle: -0.55, speed: 22, size: 2.1, phase: 0.8, birthOffset: 0.04),
        .init(id: 2, angle: 0.35, speed: 20, size: 2.4, phase: 1.5, birthOffset: 0.08),
        .init(id: 3, angle: 1.05, speed: 24, size: 1.8, phase: 2.2, birthOffset: 0.02),
        .init(id: 4, angle: -1.55, speed: 16, size: 2.0, phase: 2.9, birthOffset: 0.11),
        .init(id: 5, angle: 1.45, speed: 19, size: 1.7, phase: 3.6, birthOffset: 0.06),
        .init(id: 6, angle: -0.25, speed: 26, size: 2.5, phase: 4.1, birthOffset: 0.13),
        .init(id: 7, angle: 0.75, speed: 17, size: 1.9, phase: 4.8, birthOffset: 0.09),
        .init(id: 8, angle: -0.85, speed: 21, size: 2.2, phase: 5.3, birthOffset: 0.15),
        .init(id: 9, angle: 0.15, speed: 23, size: 1.6, phase: 5.9, birthOffset: 0.01)
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isActive)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let tipX = 6 + max(0, textWidth * progress)
            let tipY: CGFloat = 22
            let baseOpacity: Double = {
                guard isActive, progress > 0.03 else { return 0 }
                if progress > 0.97 { return max(0, 1 - Double((progress - 0.97) / 0.03)) }
                return 1
            }()

            Canvas { context, _ in
                guard baseOpacity > 0.01 else { return }
                for spark in sparks {
                    // Cycle de vie court qui se relance — sensation d’émission continue.
                    let life = (time * 1.55 + spark.birthOffset + spark.phase * 0.08)
                        .truncatingRemainder(dividingBy: 0.55) / 0.55
                    let ease = 1 - pow(1 - life, 2)
                    let travel = CGFloat(ease) * spark.speed
                    let x = tipX + CGFloat(cos(spark.angle)) * travel
                    let y = tipY + CGFloat(sin(spark.angle)) * travel * 0.85
                    let fade = baseOpacity * (1 - life) * (0.75 + 0.25 * sin(time * 16 + spark.phase))
                    let size = spark.size * (1.15 - CGFloat(life) * 0.55)

                    var circle = Path()
                    circle.addEllipse(in: CGRect(
                        x: x - size / 2,
                        y: y - size / 2,
                        width: size,
                        height: size
                    ))
                    context.fill(circle, with: .color(.white.opacity(fade)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(baseOpacity)
            .animation(.easeOut(duration: 0.18), value: isActive)
        }
    }
}

// MARK: - Compat sheet (anciens call sites éventuels)

/// Ancien sheet — redirige vers le presenter Dynamic Island.
struct ProcessEveningCheckInSheet: View {
    var targetDate: Date = Date()
    var isRequired: Bool = false
    var onCompleted: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                dismiss()
                ProcessEveningCheckInPresenter.shared.present(
                    targetDate: targetDate,
                    isRequired: isRequired,
                    onCompleted: onCompleted
                )
            }
    }
}

// MARK: - Bouton d'entrée

struct ProcessEveningCheckInEntryButton: View {
    var action: () -> Void

    @Environment(\.appTheme) private var theme
    @Bindable private var eveningStore = ProcessEveningCheckInStore.shared

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
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(
                            hasSubmittedToday
                                ? Color(red: 0.35, green: 0.78, blue: 0.45)
                                : theme.onboardingAccent
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(hasSubmittedToday
                         ? AppCopy.t("Jour validé", en: "Day Validated")
                         : AppCopy.t("Check du jour", en: "Today's Check-In"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.primaryText)
                    Text(hasSubmittedToday
                         ? AppCopy.t("Tu peux modifier tes réponses si besoin.", en: "You can update your answers if needed.")
                         : AppCopy.t("Eau \(ProcessDailyTargets.hydrationLabel) · scan · repas · routine.", en: "Water \(ProcessDailyTargets.hydrationLabel) · scan · meal · routine."))
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                if hasSubmittedToday {
                    Text(AppCopy.t("OK", en: "OK"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color(red: 0.35, green: 0.78, blue: 0.45))
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
        }
        .processGlassButton(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityLabel(hasSubmittedToday ? AppCopy.t("Jour validé", en: "Day Validated") : AppCopy.t("Ouvrir le check du jour", en: "Open Today's Check-In"))
    }
}
