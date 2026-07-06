import SwiftUI

// MARK: - Modèle

private enum EveningCheckInQuestion: String, CaseIterable, Identifiable {
    case water
    case debloatMeal
    case postureCircuit

    var id: String {
        switch self {
        case .water: return EveningCheckInQuestionID.water
        case .debloatMeal: return EveningCheckInQuestionID.debloatMeal
        case .postureCircuit: return EveningCheckInQuestionID.postureCircuit
        }
    }

    var title: String {
        switch self {
        case .water: return "\(ProcessDailyTargets.hydrationLabel) d'eau ?"
        case .debloatMeal: return "Repas debloat ?"
        case .postureCircuit: return "Circuit posture ?"
        }
    }

    var yesValue: String { "yes" }
    var noValue: String { "no" }
}

/// Bilan du soir — 3 questions binaires, tout visible sans scroll.
struct ProcessEveningCheckInSheet: View {
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

    private var isFormComplete: Bool {
        EveningCheckInQuestion.allCases.allSatisfy { answers[$0.id] != nil }
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
        .interactiveDismissDisabled(phase == .form)
        .onAppear {
            answers = eveningStore.answers()
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
                ForEach(EveningCheckInQuestion.allCases) { question in
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
            Text(question.title)
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

    private var headerRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Bilan du soir")
                .font(.title3.weight(.bold))
                .foregroundStyle(theme.primaryText)

            if streakStore.displayStreak > 0, !eveningStore.hasSubmittedToday {
                Text("Streak \(streakStore.displayStreak) jour\(streakStore.displayStreak > 1 ? "s" : "")")
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 16)
    }

    private var footerBlock: some View {
        Button(action: submitCheckIn) {
            Text(eveningStore.hasSubmittedToday ? "Mettre à jour" : "Valider mon bilan")
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
                    .fill(Color(red: 0.35, green: 0.78, blue: 0.45).opacity(0.18))
                    .frame(width: 88, height: 88)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(Color(red: 0.35, green: 0.78, blue: 0.45))
                    .symbolEffect(.bounce, value: phase)
            }

            VStack(spacing: 8) {
                Text("Bilan enregistré")
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

    private var validatedSubtitle: String {
        let snapshot = trajectoryStore.snapshot
        if let summary = ProcessDebloatTrajectoryStore.shared.record(for: Date())?.aiSummary {
            return summary
        }
        if let verdict = snapshot.todayVerdict {
            return "\(verdict.shortLabel) — score \(Int(snapshot.todayCompositeScore))/100 · streak \(snapshot.currentStreak) j"
        }
        return "Ta trajectoire debloat est à jour."
    }

    // MARK: - Actions

    private func submitCheckIn() {
        guard isFormComplete else { return }
        HapticManager.shared.impact(.medium)
        phase = .analyzing
        analyzingLabel = "Enregistrement…"

        validationTask?.cancel()
        validationTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }

            analyzingLabel = "Mise à jour de ta streak…"
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }

            eveningStore.markSubmitted(answers: answers)
            onCompleted?()

            withAnimation(.spring(response: 0.44, dampingFraction: 0.82)) {
                phase = .validated
            }

            HapticManager.shared.notification(.success)
            ProcessSoundPlayer.playRevolutPaySuccess()

            try? await Task.sleep(for: .seconds(2.2))
            guard !Task.isCancelled else { return }
            finishAndDismiss()
        }
    }

    private func finishAndDismiss() {
        validationTask?.cancel()
        dismiss()
    }
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
                    Image(systemName: eveningStore.hasSubmittedToday ? "checkmark.seal.fill" : "moon.stars.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(
                            eveningStore.hasSubmittedToday
                                ? Color(red: 0.35, green: 0.78, blue: 0.45)
                                : theme.onboardingAccent
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(eveningStore.hasSubmittedToday ? "Bilan du soir validé" : "Bilan du soir")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.primaryText)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                if !eveningStore.hasSubmittedToday, streakStore.displayStreak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.caption.weight(.bold))
                        Text("\(streakStore.displayStreak)")
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
        .accessibilityLabel(eveningStore.hasSubmittedToday ? "Bilan du soir validé" : "Ouvrir le bilan du soir")
    }

    private var subtitle: String {
        if eveningStore.hasSubmittedToday {
            return "Tu peux modifier tes réponses si besoin."
        }
        if isEveningWindow {
            return "Eau, repas debloat, circuit posture."
        }
        return "3 questions pour valider ta streak."
    }

    private var isEveningWindow: Bool {
        Calendar.current.component(.hour, from: Date()) >= 21
    }

    @ViewBuilder
    private var entryBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        shape
            .fill(.clear)
            .processGlassEffect(in: shape, interactive: true)
    }
}
