import SwiftUI

// MARK: - ViewModel

@MainActor
@Observable
final class OriginMealSuggestionViewModel {
    enum Phase: Equatable {
        case idle
        case loading
        case suggestion(MealSuggestionContent)
        case validated(MealSuggestionContent)
        case quickPick([MealSuggestionContent])
    }

    private(set) var phase: Phase = .idle
    private(set) var revealedActionIDs: Set<String> = []
    private(set) var errorMessage: String?
    private(set) var itemAlternatives: [String] = []
    private(set) var isLoadingAlternatives = false
    private(set) var comparisonCandidate: MealSuggestionContent?

    private var revealTask: Task<Void, Never>?
    private var currentSuggestion: MealSuggestionContent?

    var isLoading: Bool {
        if case .loading = phase { return true }
        return false
    }

    func syncValidatedMeal(_ stored: String?, slot: MealTimeSlot) {
        if let stored, !stored.isEmpty, let meal = MealSuggestionContent.fromStored(stored) {
            phase = .validated(meal)
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
        slot: MealTimeSlot,
        mode: OriginMealSuggestionService.RequestMode = .fresh
    ) async {
        revealTask?.cancel()
        revealedActionIDs = []
        errorMessage = nil
        comparisonCandidate = nil
        phase = .loading

        guard ClaudeConfiguration.isConfigured else {
            errorMessage = "Coach IA indisponible — configure l'API Claude."
            phase = .idle
            return
        }

        guard ProcessPrivacyConsentStore.shared.canUseThirdPartyAI else {
            ProcessPrivacyConsentStore.shared.presentThirdPartyAIConsentIfNeeded {
                Task {
                    await self.requestMeal(
                        plan: plan,
                        day: day,
                        profile: profile,
                        slot: slot,
                        mode: mode
                    )
                }
            }
            phase = .idle
            return
        }

        do {
            let content = try await OriginMealSuggestionService.suggest(
                plan: plan,
                day: day,
                profile: profile,
                mode: mode,
                slot: slot
            )
            if case .another = mode, let previous = currentSuggestion {
                comparisonCandidate = content
                currentSuggestion = previous
                phase = .suggestion(previous)
            } else {
                currentSuggestion = content
                phase = .suggestion(content)
            }
            if comparisonCandidate == nil {
                await revealActions()
            }
        } catch {
            errorMessage = "Impossible de générer une idée. Réessaie."
            phase = .idle
        }
    }

    func requestQuickPick(
        plan: FaceOriginPlan,
        day: OriginProgramDay,
        profile: UnifiedUserProfile?,
        slot: MealTimeSlot
    ) async {
        guard ProcessPrivacyConsentStore.shared.canUseThirdPartyAI else {
            ProcessPrivacyConsentStore.shared.presentThirdPartyAIConsentIfNeeded {
                Task { await self.requestQuickPick(plan: plan, day: day, profile: profile, slot: slot) }
            }
            return
        }
        phase = .loading
        errorMessage = nil
        do {
            let meals = try await OriginMealSuggestionService.suggestBatch(
                plan: plan, day: day, profile: profile, count: 3, slot: slot
            )
            phase = .quickPick(meals)
        } catch {
            errorMessage = "Mode rapide indisponible."
            phase = .idle
        }
    }

    func requestFromPhoto(
        image: UIImage,
        plan: FaceOriginPlan,
        day: OriginProgramDay,
        profile: UnifiedUserProfile?,
        slot: MealTimeSlot
    ) async {
        guard ProcessPrivacyConsentStore.shared.canUseThirdPartyAI else {
            ProcessPrivacyConsentStore.shared.presentThirdPartyAIConsentIfNeeded {
                Task {
                    await self.requestFromPhoto(
                        image: image, plan: plan, day: day, profile: profile, slot: slot
                    )
                }
            }
            return
        }
        phase = .loading
        errorMessage = nil
        do {
            let content = try await OriginMealSuggestionService.suggestFromPhoto(
                image: image, plan: plan, day: day, profile: profile, slot: slot
            )
            currentSuggestion = content
            phase = .suggestion(content)
            await revealActions()
        } catch {
            errorMessage = "Analyse photo impossible."
            phase = .idle
        }
    }

    func loadAlternatives(
        plan: FaceOriginPlan,
        day: OriginProgramDay,
        profile: UnifiedUserProfile?,
        item: MealSuggestionItem
    ) async {
        guard let current = currentSuggestion else { return }
        isLoadingAlternatives = true
        itemAlternatives = []
        defer { isLoadingAlternatives = false }
        do {
            itemAlternatives = try await OriginMealSuggestionService.suggestItemAlternatives(
                plan: plan, day: day, profile: profile, current: current, item: item
            )
        } catch {
            itemAlternatives = []
        }
    }

    func applyAlternative(_ name: String, item: MealSuggestionItem) async {
        guard var current = currentSuggestion else { return }
        if let index = current.items.firstIndex(where: { $0.id == item.id }) {
            current.items[index].name = name
            currentSuggestion = current
            phase = .suggestion(current)
        }
    }

    func acceptComparisonCandidate() {
        guard let candidate = comparisonCandidate else { return }
        currentSuggestion = candidate
        comparisonCandidate = nil
        phase = .suggestion(candidate)
        Task { await revealActions() }
    }

    func rejectComparisonCandidate() {
        comparisonCandidate = nil
        Task { await revealActions() }
    }

    func validateCurrentMeal() -> MealSuggestionContent? {
        guard let content = currentSuggestion else { return nil }
        phase = .validated(content)
        revealedActionIDs = []
        revealTask?.cancel()
        comparisonCandidate = nil
        return content
    }

    func resetToIdle() {
        revealTask?.cancel()
        revealedActionIDs = []
        currentSuggestion = nil
        comparisonCandidate = nil
        itemAlternatives = []
        phase = .idle
    }

    func currentContent() -> MealSuggestionContent? { currentSuggestion }

    private func revealActions() async {
        let ids = ["shopping", "validate", "modify", "another"]
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
                _ = withAnimation(OnboardingProfileChatAnswerReveal.spring) {
                    revealedActionIDs.insert(id)
                }
            }
        }
        await revealTask?.value
    }
}

// MARK: - Carte nutrition IA (hub complet)

struct OriginMealSuggestionCard: View {
    let plan: FaceOriginPlan
    let day: OriginProgramDay
    var isEditable: Bool = true

    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var profileService: UnifiedProfileService
    @State private var viewModel = OriginMealSuggestionViewModel()
    @State private var store = WelcomePlanStore.shared
    @State private var selectedSlot: MealTimeSlot = .lunch
    @State private var editingItem: MealSuggestionItem?
    @State private var showPhotoScan = false
    @State private var showFeedback = false
    @State private var showComparison = false
    @State private var lastHistoryId: String?

    private var livePlan: FaceOriginPlan { store.plan ?? plan }
    private let answerShape = Capsule()

    private var validatedSlots: Set<MealTimeSlot> {
        guard let slots = store.plan?.progress.validatedMealsBySlot[day.id] else { return [] }
        return Set(slots.keys.compactMap { key in MealTimeSlot.allCases.first { $0.rawValue == key } })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow

            if isEditable {
                MealTimelineTabs(
                    selected: $selectedSlot,
                    validatedSlots: validatedSlots,
                    theme: theme
                )
                .onChange(of: selectedSlot) { _, slot in
                    syncFromStore(slot: slot)
                }

                modeToolbar
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
        .onAppear { syncFromStore(slot: selectedSlot) }
        .onChange(of: store.plan?.progress.validatedMealsBySlot[day.id]) { _, _ in
            syncFromStore(slot: selectedSlot)
        }
        .sheet(item: $editingItem) { item in
            editSheet(for: item)
        }
        .sheet(isPresented: $showPhotoScan) {
            MealPhotoScanSheet(
                onCapture: { image in
                    showPhotoScan = false
                    Task {
                        await viewModel.requestFromPhoto(
                            image: image,
                            plan: livePlan,
                            day: day,
                            profile: profileService.currentProfile,
                            slot: selectedSlot
                        )
                    }
                },
                onCancel: { showPhotoScan = false }
            )
        }
        .sheet(isPresented: $showFeedback) {
            if let content = viewModel.currentContent() {
                MealFeedbackSheet(
                    dayId: day.id,
                    historyId: lastHistoryId,
                    mealName: content.name,
                    onSubmit: { showFeedback = false },
                    onDismiss: { showFeedback = false }
                )
            }
        }
        .sheet(isPresented: $showComparison) {
            if let previous = viewModel.currentContent(),
               let candidate = viewModel.comparisonCandidate {
                MealComparisonSheet(
                    previous: previous,
                    candidate: candidate,
                    onKeepPrevious: {
                        viewModel.rejectComparisonCandidate()
                        showComparison = false
                    },
                    onChooseCandidate: {
                        viewModel.acceptComparisonCandidate()
                        showComparison = false
                    },
                    onDismiss: {
                        viewModel.rejectComparisonCandidate()
                        showComparison = false
                    }
                )
            }
        }
        .onChange(of: viewModel.comparisonCandidate?.name) { _, name in
            showComparison = name != nil
        }
    }

    // MARK: - Toolbar modes

    private var modeToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                toolButton("Photo frigo", icon: "camera.fill") {
                    showPhotoScan = true
                }
                toolButton("Mode rapide", icon: "square.stack.3d.up.fill") {
                    Task {
                        await viewModel.requestQuickPick(
                            plan: livePlan, day: day,
                            profile: profileService.currentProfile,
                            slot: selectedSlot
                        )
                    }
                }
            }
        }
    }

    private func toolButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.shared.selection()
            action()
        } label: {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(theme.cardBackground.opacity(0.5))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isLoading)
    }

    @ViewBuilder
    private var editableContent: some View {
        switch viewModel.phase {
        case .idle:
            idleContent
        case .loading:
            loadingContent
        case .suggestion(let content):
            suggestionContent(content)
        case .validated(let content):
            validatedContent(content)
        case .quickPick(let meals):
            MealQuickPickStackView(
                meals: meals,
                onValidate: { meal in
                    store.saveValidatedMeal(dayId: day.id, meal: meal, slot: selectedSlot)
                    viewModel.resetToIdle()
                    syncFromStore(slot: selectedSlot)
                    promptFeedback()
                },
                onDismiss: { viewModel.resetToIdle() }
            )
        }
    }

    @ViewBuilder
    private var readOnlyContent: some View {
        if let meal = store.validatedMealContent(for: day.id) {
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
                Text("Hub repas IA")
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
            ProgressView().controlSize(.small)
            Text("Le coach prépare ton repas…")
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
        }
    }

    private func suggestionContent(_ content: MealSuggestionContent) -> some View {
        MealSuggestionCardView(
            content: content,
            showsActions: true,
            revealedActionIDs: viewModel.revealedActionIDs,
            onValidate: { validate(content) },
            onModify: {
                guard let current = viewModel.currentContent() else { return }
                Task {
                    await viewModel.requestMeal(
                        plan: livePlan, day: day,
                        profile: profileService.currentProfile,
                        slot: selectedSlot,
                        mode: .modify(current: current)
                    )
                }
            },
            onAnother: {
                guard let previous = viewModel.currentContent() else { return }
                Task {
                    await viewModel.requestMeal(
                        plan: livePlan, day: day,
                        profile: profileService.currentProfile,
                        slot: selectedSlot,
                        mode: .another(previous: previous)
                    )
                }
            },
            onAddToShoppingList: {
                store.addMealToShoppingList(content, dayId: day.id)
                HapticManager.shared.notification(.success)
            },
            onEditItem: { item in
                editingItem = item
                Task {
                    await viewModel.loadAlternatives(
                        plan: livePlan, day: day,
                        profile: profileService.currentProfile,
                        item: item
                    )
                }
            }
        )
    }

    private func validatedContent(_ content: MealSuggestionContent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MealSuggestionCardView(
                content: content,
                isValidated: true,
                showsActions: false,
                onEditItem: isEditable ? { item in editingItem = item } : nil
            )

            if isEditable {
                HStack(spacing: 10) {
                    Button("Feedback") {
                        showFeedback = true
                    }
                    .font(.caption.weight(.semibold))

                    Spacer()

                    askMealButton("Autre idée", style: .secondary, onSecondaryClear: true)
                }
            }
        }
    }

    private func validate(_ content: MealSuggestionContent) {
        store.saveValidatedMeal(dayId: day.id, meal: content, slot: selectedSlot)
        _ = viewModel.validateCurrentMeal()
        lastHistoryId = store.recentMealHistory(limit: 1).first?.id
        promptFeedback()
    }

    private func promptFeedback() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            showFeedback = true
        }
    }

    private func editSheet(for item: MealSuggestionItem) -> some View {
        Group {
            if let content = viewModel.currentContent() {
                MealItemEditSheet(
                    item: item,
                    mealName: content.name,
                    alternatives: viewModel.itemAlternatives,
                    isLoadingAlternatives: viewModel.isLoadingAlternatives,
                    onApply: { instruction in
                        editingItem = nil
                        Task {
                            await viewModel.requestMeal(
                                plan: livePlan, day: day,
                                profile: profileService.currentProfile,
                                slot: selectedSlot,
                                mode: .modifyItem(current: content, item: item, instruction: instruction)
                            )
                        }
                    },
                    onSelectAlternative: { alt in
                        editingItem = nil
                        Task {
                            await viewModel.applyAlternative(alt, item: item)
                        }
                    },
                    onDismiss: { editingItem = nil }
                )
            }
        }
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
                store.clearValidatedMeal(dayId: day.id, slot: selectedSlot)
                viewModel.resetToIdle()
            }
            Task {
                await viewModel.requestMeal(
                    plan: livePlan, day: day,
                    profile: profileService.currentProfile,
                    slot: selectedSlot
                )
            }
        } label: {
            HStack(spacing: 8) {
                if style == .primary { Image(systemName: "sparkles") }
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

    private var cardBackground: some View {
        HealthHubDesign.softCard(theme: theme)
    }

    private func syncFromStore(slot: MealTimeSlot) {
        guard !viewModel.isLoading else { return }
        if let payload = store.plan?.progress.validatedMealsBySlot[day.id]?[slot.rawValue] {
            viewModel.syncValidatedMeal(payload, slot: slot)
        } else if slot == .lunch, let fallback = store.validatedMeal(for: day.id) {
            viewModel.syncValidatedMeal(fallback, slot: slot)
        } else if case .validated = viewModel.phase {
            viewModel.resetToIdle()
        }
    }
}
