import SwiftUI
import UIKit

private struct PlanMealBottomChromeHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 110

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}


/// Page détail repas — graphique, ingrédients et assistant IA intégré.
struct PlanMealDetailView: View {
    let entry: PlanDayMealEntry
    let plan: FaceOriginPlan
    let day: OriginProgramDay
    var isEditable: Bool
    var onMealUpdated: (MealSuggestionContent) -> Void
    var onValidate: ((MealSuggestionContent) -> Void)?
    var onDismiss: () -> Void

    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var profileService: UnifiedProfileService

    @State private var meal: MealSuggestionContent
    @State private var assistant = PlanMealAssistantViewModel()
    @FocusState private var isInputFocused: Bool
    @State private var isCompactCameraPresented = false
    @State private var showComparison = false
    @State private var thinkingBlobStart = Date.now
    @State private var bottomChromeHeight: CGFloat = 110

    private let messageFont = Font.system(size: 16, weight: .regular)
    private let messageLineSpacing: CGFloat = 3

    init(
        entry: PlanDayMealEntry,
        plan: FaceOriginPlan,
        day: OriginProgramDay,
        isEditable: Bool,
        onMealUpdated: @escaping (MealSuggestionContent) -> Void,
        onValidate: ((MealSuggestionContent) -> Void)? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.entry = entry
        self.plan = plan
        self.day = day
        self.isEditable = isEditable
        self.onMealUpdated = onMealUpdated
        self.onValidate = onValidate
        self.onDismiss = onDismiss
        _meal = State(initialValue: entry.meal)
    }

    private var profile: MealNutritionProfile { MealNutritionCatalog.profile(for: meal) }
    private var imageAsset: String {
        MealNutritionCatalog.resolvedImageAsset(
            for: meal,
            slot: entry.slot,
            dayIndex: day.globalDayIndex,
            planType: plan.nutritionPlanType
        )
    }

    var body: some View {
        NavigationStack {
            scrollContent
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if isEditable {
                        if isCompactCameraPresented,
                           !assistant.isVoiceRecording,
                           !assistant.isVoiceExiting {
                            CoachInlineBottomCameraPanel(
                                panelHeight: max(320, UIScreen.main.bounds.height * 0.55),
                                onCapture: { image in
                                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                                        isCompactCameraPresented = false
                                    }
                                    assistant.stageImageAttachment(image)
                                    isInputFocused = true
                                },
                                onCancel: {
                                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                                        isCompactCameraPresented = false
                                    }
                                }
                            )
                        } else {
                            bottomAccessory
                                .background {
                                    GeometryReader { proxy in
                                        Color.clear
                                            .preference(
                                                key: PlanMealBottomChromeHeightKey.self,
                                                value: proxy.size.height
                                            )
                                    }
                                }
                                .ignoresSafeArea(.keyboard, edges: .bottom)
                        }
                    }
                }
                .background(theme.background.ignoresSafeArea())
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Fermer", action: onDismiss)
                    }
                    if entry.isValidated {
                        ToolbarItem(placement: .primaryAction) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
                .onAppear {
                    assistant.bootstrapIfNeeded()
                }
                .onChange(of: assistant.comparisonCandidate?.name) { _, name in
                    showComparison = name != nil
                }
                .onPreferenceChange(PlanMealBottomChromeHeightKey.self) { height in
                    if height > 0 {
                        bottomChromeHeight = height
                    }
                }
                .sheet(isPresented: $showComparison) {
                    if let candidate = assistant.comparisonCandidate {
                        MealComparisonSheet(
                            previous: meal,
                            candidate: candidate,
                            onKeepPrevious: {
                                assistant.rejectComparisonCandidate()
                                showComparison = false
                            },
                            onChooseCandidate: {
                                if let updated = assistant.acceptComparisonCandidate() {
                                    applyMealUpdate(updated)
                                }
                                showComparison = false
                            },
                            onDismiss: {
                                assistant.rejectComparisonCandidate()
                                showComparison = false
                            }
                        )
                    }
                }
        }
    }

    private var scrollContent: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    MealIngredientRadialChart(
                        segments: MealNutritionCatalog.debloatChartSegments(for: profile),
                        imageAssetName: imageAsset
                    )
                    .padding(.top, 8)

                    Text(meal.name)
                        .font(.system(size: 26, weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(theme.primaryText)
                        .padding(.horizontal, 24)

                    if let scheduleTarget = entry.scheduleTargetLabel,
                       let scheduleWindow = entry.scheduleWindowLabel {
                        scheduleCard(target: scheduleTarget, window: scheduleWindow)
                    }

                    caloriesCard
                    ingredientsSection

                    if isEditable, !assistant.messages.isEmpty {
                        assistantSection
                    }

                    if !meal.prepSummary.isEmpty,
                       !MealSuggestionParser.looksLikeJSON(meal.prepSummary) {
                        infoBlock(title: "Préparation", body: meal.prepSummary, icon: "timer")
                    }

                    if isEditable {
                        actionButtons
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, isEditable ? 24 : 32)
            }
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture().onEnded {
                    isInputFocused = false
                }
            )
            .onChange(of: assistant.messages.count) { _, _ in
                scrollToLatestMessage(proxy)
            }
            .onChange(of: assistant.isLoading) { _, loading in
                if loading {
                    thinkingBlobStart = .now
                    scrollToLatestMessage(proxy)
                }
            }
        }
    }

    private var bottomAccessory: some View {
        VStack(spacing: 10) {
            if let error = assistant.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 20)
            }

            suggestionChipBar

            mealChatInputBar
        }
        .padding(.top, 6)
    }

    private var suggestionChipBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if assistant.isLoadingAlternatives {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.horizontal, 8)
                }

                ForEach(assistant.quickSuggestions(for: meal)) { suggestion in
                    Button {
                        HapticManager.shared.selection()
                        isInputFocused = false
                        Task {
                            if let updated = await assistant.sendQuickSuggestion(
                                suggestion,
                                meal: meal,
                                plan: plan,
                                day: day,
                                profile: profileService.currentProfile,
                                slot: entry.slot
                            ) {
                                applyMealUpdate(updated)
                            }
                        }
                    } label: {
                        Text(suggestion.label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.primaryText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(theme.cardBackgroundStrong.opacity(0.92))
                                    .overlay {
                                        Capsule(style: .continuous)
                                            .strokeBorder(theme.cardStroke, lineWidth: theme.isDark ? 0 : 0.5)
                                    }
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(assistant.isSending)
                    .opacity(assistant.isSending ? 0.55 : 1)
                }

                if isEditable {
                    Button {
                        HapticManager.shared.selection()
                        WelcomePlanStore.shared.addMealToShoppingList(meal, dayId: day.id)
                    } label: {
                        Label("Liste de courses", systemImage: "cart.badge.plus")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.primaryText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(theme.cardBackgroundStrong.opacity(0.92))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var mealChatInputBar: some View {
        CoachLiquidGlassInputBar(
            text: $assistant.inputText,
            isFocused: $isInputFocused,
            pendingImages: assistant.pendingAttachmentImage.map { [$0] } ?? [],
            isDisabled: assistant.isSending,
            isRecording: assistant.isVoiceRecording,
            isVoiceExiting: assistant.isVoiceExiting,
            voiceAudioLevel: assistant.voiceAudioLevel,
            voiceAudioLevels: assistant.voiceAudioLevels,
            onSend: {
                isInputFocused = false
                Task { await sendCurrentMessage() }
            },
            onStartVoice: {
                isCompactCameraPresented = false
                Task { await assistant.startVoiceRecording() }
            },
            onCancelVoice: {
                assistant.cancelVoiceRecording()
            },
            onConfirmVoice: {
                Task {
                    let inserted = await assistant.confirmVoiceRecording()
                    if inserted {
                        isInputFocused = true
                    }
                }
            },
            onOpenCamera: {
                isInputFocused = false
                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                    isCompactCameraPresented = true
                }
            },
            onRemovePendingImageAt: { _ in
                assistant.clearPendingAttachment()
            }
        )
        .padding(.horizontal, 14)
    }


    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Ingrédients", systemImage: "leaf.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)

                Spacer(minLength: 8)

                if isEditable, assistant.selectedItem != nil {
                    Button("Tout le repas") {
                        assistant.selectItem(
                            nil,
                            meal: meal,
                            plan: plan,
                            day: day,
                            profile: profileService.currentProfile
                        )
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.onboardingAccent)
                }
            }

            VStack(spacing: 8) {
                ForEach(meal.items) { item in
                    ingredientRow(item)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(mealSurfaceCard)
    }

    private func ingredientRow(_ item: MealSuggestionItem) -> some View {
        let isSelected = assistant.selectedItem?.id == item.id

        return MealSuggestionItemRow(
            item: item,
            theme: theme,
            isExpanded: true,
            isEditable: isEditable,
            onTap: {
                if assistant.selectedItem?.id == item.id {
                    assistant.selectItem(
                        nil,
                        meal: meal,
                        plan: plan,
                        day: day,
                        profile: profileService.currentProfile
                    )
                } else {
                    assistant.selectItem(
                        item,
                        meal: meal,
                        plan: plan,
                        day: day,
                        profile: profileService.currentProfile
                    )
                }
            }
        )
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(theme.onboardingAccent.opacity(0.85), lineWidth: 1.5)
            }
        }
    }

    private var assistantSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Assistant repas", systemImage: "sparkles")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.secondaryText)

            ForEach(assistant.messages) { message in
                messageRow(message)
                    .id(message.id)
            }

            if assistant.isLoading {
                CoachChatThinkingBlobRow(start: thinkingBlobStart)
                    .padding(.top, 4)
                    .id("meal-assistant-loading")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(mealSurfaceCard)
    }

    @ViewBuilder
    private func messageRow(_ message: PlanMealChatMessage) -> some View {
        switch message.role {
        case .user:
            HStack {
                Spacer(minLength: 36)
                Text(message.text)
                    .font(messageFont)
                    .foregroundStyle(theme.primaryText)
                    .lineSpacing(messageLineSpacing)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(theme.coachUserBubble, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        case .assistant:
            VStack(alignment: .leading, spacing: 10) {
                Text(message.text)
                    .font(messageFont)
                    .foregroundStyle(theme.primaryText)
                    .lineSpacing(messageLineSpacing)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let preview = message.mealPreview {
                    CoachMealSuggestionMessageView(content: preview)
                }
            }
        }
    }

    private var caloriesCard: some View {
        HStack(spacing: 14) {
            Text("🔥")
                .font(.system(size: 28))
            VStack(alignment: .leading, spacing: 2) {
                Text("Calories")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.secondaryText)
                Text("\(profile.calories)")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(theme.primaryText)
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(mealSurfaceCard)
    }

    private func scheduleCard(target: String, window: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Horaire debloat", systemImage: "clock.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.secondaryText)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(target)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(theme.onboardingAccent)
                    .monospacedDigit()

                Text(window)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.secondaryText)
            }

            if let note = entry.scheduleNote {
                Text(note)
                    .font(.subheadline)
                    .foregroundStyle(theme.primaryText.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(mealSurfaceCard)
    }

    private func infoBlock(title: String, body: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.secondaryText)
            Text(body)
                .font(.subheadline)
                .foregroundStyle(theme.primaryText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(mealSurfaceCard)
    }

    @ViewBuilder
    private var actionButtons: some View {
        if let onValidate, !entry.isValidated {
            Button {
                onValidate(meal)
            } label: {
                Text("Valider ce repas")
                    .font(.headline)
                    .foregroundStyle(theme.inverseText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(theme.inverseBackground, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var mealSurfaceCard: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(theme.isDark ? theme.cardBackgroundStrong : theme.coachUserBubble)
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(theme.cardStroke, lineWidth: theme.isDark ? 0 : 0.5)
            }
            .shadow(color: theme.primaryText.opacity(theme.isDark ? 0.12 : 0.04), radius: 10, y: 3)
    }

    private func sendCurrentMessage() async {
        if let updated = await assistant.sendCurrentMessage(
            meal: meal,
            plan: plan,
            day: day,
            profile: profileService.currentProfile,
            slot: entry.slot
        ) {
            applyMealUpdate(updated)
        }
    }

    private func applyMealUpdate(_ updated: MealSuggestionContent) {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            meal = updated
        }
        onMealUpdated(updated)
    }

    private func scrollToLatestMessage(_ proxy: ScrollViewProxy) {
        guard isEditable else { return }
        withAnimation(.easeOut(duration: 0.22)) {
            if assistant.isLoading {
                proxy.scrollTo("meal-assistant-loading", anchor: .bottom)
            } else if let last = assistant.messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
}
