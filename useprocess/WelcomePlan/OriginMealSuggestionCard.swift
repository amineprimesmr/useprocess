import SwiftUI

// MARK: - ViewModel

@MainActor
@Observable
final class OriginMealSuggestionViewModel {
    enum Phase: Equatable {
        case idle
        case loading
        case suggestion(text: String)
        case validated(text: String)
    }

    private(set) var phase: Phase = .idle
    private(set) var typewriter = CoachTypewriterController()
    private(set) var revealedActionIDs: Set<String> = []
    private(set) var errorMessage: String?

    private var revealTask: Task<Void, Never>?
    private var currentSuggestion: String?

    var isLoading: Bool {
        if case .loading = phase { return true }
        return false
    }

    func syncValidatedMeal(_ meal: String?) {
        if let meal, !meal.isEmpty {
            phase = .validated(text: meal)
            currentSuggestion = meal
        } else if case .validated = phase {
            phase = .idle
            currentSuggestion = nil
        }
    }

    func requestMeal(
        plan: FaceOriginPlan,
        day: OriginProgramDay,
        profile: UnifiedUserProfile?,
        mode: OriginMealSuggestionService.RequestMode = .fresh
    ) async {
        revealTask?.cancel()
        revealedActionIDs = []
        errorMessage = nil
        phase = .loading
        typewriter.reset()

        guard ClaudeConfiguration.isConfigured else {
            errorMessage = "Coach IA indisponible — configure l'API Claude."
            phase = .idle
            return
        }

        do {
            let text = try await OriginMealSuggestionService.suggest(
                plan: plan,
                day: day,
                profile: profile,
                mode: mode
            )
            currentSuggestion = text
            phase = .suggestion(text: text)
            await typewriter.run(text: text)
            await revealActions()
        } catch {
            errorMessage = "Impossible de générer une idée. Réessaie."
            phase = .idle
        }
    }

    func validateCurrentMeal() -> String? {
        guard let text = currentSuggestion else { return nil }
        phase = .validated(text: text)
        revealedActionIDs = []
        revealTask?.cancel()
        return text
    }

    func resetToIdle() {
        revealTask?.cancel()
        revealedActionIDs = []
        currentSuggestion = nil
        typewriter.reset()
        phase = .idle
    }

    func suggestionForAnother() -> String? { currentSuggestion }

    private func revealActions() async {
        let ids = ["validate", "modify", "another"]
        revealTask?.cancel()
        revealTask = Task {
            try? await Task.sleep(nanoseconds: WelcomePlanChatAnswerReveal.initialDelay)
            guard !Task.isCancelled, case .suggestion = phase else { return }

            for (index, id) in ids.enumerated() {
                if Task.isCancelled { return }
                guard case .suggestion = phase else { return }
                if index > 0 {
                    try? await Task.sleep(nanoseconds: WelcomePlanChatAnswerReveal.staggerDelay)
                }
                if Task.isCancelled { return }
                _ = withAnimation(OnboardingProfileChatAnswerReveal.spring) {
                    revealedActionIDs.insert(id)
                }
            }
        }
        await revealTask?.value
    }
}

// MARK: - Carte nutrition IA

struct OriginMealSuggestionCard: View {
    let plan: FaceOriginPlan
    let day: OriginProgramDay
    var isEditable: Bool = true

    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var profileService: UnifiedProfileService
    @State private var viewModel = OriginMealSuggestionViewModel()
    @State private var store = WelcomePlanStore.shared

    private var livePlan: FaceOriginPlan { store.plan ?? plan }
    private let answerShape = Capsule()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow

            if isEditable {
                editableContent
            } else {
                readOnlyContent
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(14)
        .background(cardBackground)
        .onAppear { syncFromStore() }
        .onChange(of: store.plan?.progress.validatedMeals[day.id]) { _, _ in
            syncFromStore()
        }
    }

    @ViewBuilder
    private var editableContent: some View {
        switch viewModel.phase {
        case .idle:
            idleContent
        case .loading:
            loadingContent
        case .suggestion:
            suggestionContent
        case .validated(let text):
            validatedContent(text)
        }
    }

    @ViewBuilder
    private var readOnlyContent: some View {
        if let meal = store.validatedMeal(for: day.id), !meal.isEmpty {
            validatedContent(meal)
        } else {
            Text("Aucun repas enregistré pour ce jour.")
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
        }
    }

    private var headerRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "fork.knife")
                .font(.body.weight(.semibold))
                .foregroundStyle(theme.onboardingAccent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Nutrition")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
                Text("Idée de repas par l'IA")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.primaryText)
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var idleContent: some View {
        if !day.nutrition.principles.isEmpty {
            Text(day.nutrition.principles.prefix(2).joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
        }

        askMealButton("Demander une idée de repas")
    }

    private var loadingContent: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("Le coach réfléchit…")
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
        }
    }

    @ViewBuilder
    private var suggestionContent: some View {
        if case .suggestion = viewModel.phase {
            coachBubble(viewModel.typewriter.displayedText)
                .animation(.easeOut(duration: 0.12), value: viewModel.typewriter.displayedText)

            if viewModel.typewriter.isComplete {
                actionButtons
            }
        }
    }

    private func validatedContent(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Repas validé")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
            }

            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            if isEditable {
                askMealButton("Autre idée de repas", style: .secondary, onSecondaryClear: true)
            }
        }
    }

    private var actionButtons: some View {
        VStack(alignment: .leading, spacing: 10) {
            choiceButton("Valider le repas", id: "validate", primary: true) {
                if let text = viewModel.validateCurrentMeal() {
                    store.saveValidatedMeal(dayId: day.id, meal: text)
                }
            }

            choiceButton("Modifier", id: "modify") {
                guard let current = viewModel.suggestionForAnother() else { return }
                Task {
                    await viewModel.requestMeal(
                        plan: livePlan,
                        day: day,
                        profile: profileService.currentProfile,
                        mode: .modify(current: current)
                    )
                }
            }

            choiceButton("Autre repas", id: "another") {
                let previous = viewModel.suggestionForAnother() ?? ""
                Task {
                    await viewModel.requestMeal(
                        plan: livePlan,
                        day: day,
                        profile: profileService.currentProfile,
                        mode: .another(previous: previous)
                    )
                }
            }
        }
        .padding(.top, 4)
    }

    private func coachBubble(_ text: String) -> some View {
        Text(text.isEmpty ? " " : text)
            .font(.subheadline)
            .foregroundStyle(theme.primaryText)
            .lineSpacing(4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(theme.coachAssistantBubble)
            )
    }

    private enum AskButtonStyle { case primary, secondary }

    private func askMealButton(
        _ title: String,
        style: AskButtonStyle = .primary,
        onSecondaryClear: Bool = false
    ) -> some View {
        Button {
            HapticManager.shared.impact(.medium)
            if onSecondaryClear {
                store.clearValidatedMeal(dayId: day.id)
                viewModel.resetToIdle()
            }
            Task {
                await viewModel.requestMeal(
                    plan: livePlan,
                    day: day,
                    profile: profileService.currentProfile
                )
            }
        } label: {
            HStack(spacing: 8) {
                if style == .primary {
                    Image(systemName: "sparkles")
                }
                Text(title)
                    .font(.system(size: 15, weight: style == .primary ? .bold : .semibold))
            }
            .foregroundStyle(style == .primary ? OnboardingTheme.actionButtonText : theme.primaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .contentShape(answerShape)
        }
        .buttonStyle(.plain)
        .processGlassEffect(in: answerShape)
        .buttonStyle(ProcessGlassPressStyle())
        .disabled(viewModel.isLoading)
        .opacity(viewModel.isLoading ? 0.55 : 1)
    }

    private func choiceButton(
        _ title: String,
        id: String,
        primary: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticManager.shared.selection()
            action()
        } label: {
            Text(title)
                .font(.system(
                    size: OnboardingProfileChatDepthStyle.answerFontSize,
                    weight: primary ? .bold : .semibold
                ))
                .foregroundStyle(primary ? OnboardingTheme.actionButtonText : OnboardingTheme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .contentShape(answerShape)
        }
        .buttonStyle(.plain)
        .processGlassEffect(in: answerShape)
        .buttonStyle(ProcessGlassPressStyle())
        .onboardingChatAnswerReveal(isRevealed: viewModel.revealedActionIDs.contains(id))
    }

    private var cardBackground: some View {
        HealthHubDesign.softCard(theme: theme)
    }

    private func syncFromStore() {
        guard !viewModel.isLoading else { return }
        viewModel.syncValidatedMeal(store.validatedMeal(for: day.id))
    }
}
