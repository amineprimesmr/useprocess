import SwiftUI
import UIKit

struct PlanDayMealEntry: Identifiable, Equatable {
    let slot: MealTimeSlot
    let meal: MealSuggestionContent
    let isValidated: Bool

    var id: String { slot.rawValue }

    var carouselTitle: String { PlanMealSlotLabel.carouselTitle(for: slot) }
    var imageAssetName: String { MealNutritionCatalog.resolvedImageAsset(for: meal) }
}

enum PlanDayMealsProvider {
    static func entries(
        plan: FaceOriginPlan,
        day: OriginProgramDay,
        store: WelcomePlanStore
    ) -> [PlanDayMealEntry] {
        plan.configuredMealSlots.map { slot in
            let meal = resolvedMeal(plan: plan, day: day, slot: slot, store: store)
            let validated = store.plan?.progress.validatedMealsBySlot[day.id]?[slot.rawValue] != nil
            return PlanDayMealEntry(slot: slot, meal: meal, isValidated: validated)
        }
    }

    static func resolvedMeal(
        plan: FaceOriginPlan,
        day: OriginProgramDay,
        slot: MealTimeSlot,
        store: WelcomePlanStore
    ) -> MealSuggestionContent {
        if let validated = store.validatedMealContent(for: day.id, slot: slot) {
            return validated
        }
        if let draft = store.draftMealContent(for: day.id, slot: slot) {
            return draft
        }
        return ProcessDebloatMealLibrary.meal(
            for: slot,
            dayIndex: day.globalDayIndex,
            planType: plan.nutritionPlanType
        )
    }

    @MainActor
    static func ensureDefaultDrafts(
        plan: FaceOriginPlan,
        day: OriginProgramDay,
        store: WelcomePlanStore
    ) {
        guard OriginPlanPresenter.isEditableJournalDay(dayId: day.id, in: plan) else { return }

        for slot in plan.configuredMealSlots {
            let hasValidated = store.plan?.progress.validatedMealsBySlot[day.id]?[slot.rawValue] != nil
            let hasDraft = store.draftMealContent(for: day.id, slot: slot) != nil
            guard !hasValidated, !hasDraft else { continue }

            let meal = ProcessDebloatMealLibrary.meal(
                for: slot,
                dayIndex: day.globalDayIndex,
                planType: plan.nutritionPlanType
            )
            store.saveDraftMeal(dayId: day.id, meal: meal, slot: slot)
        }
    }
}

// MARK: - Section nutrition page Plan

struct PlanNutritionDaySection: View {
    let plan: FaceOriginPlan
    let day: OriginProgramDay
    var isEditable: Bool = true

    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var profileService: UnifiedProfileService

    @State private var store = WelcomePlanStore.shared
    @State private var viewModel = OriginMealSuggestionViewModel()
    @State private var selectedEntry: PlanDayMealEntry?
    @State private var showAllMeals = false
    @State private var showModifyFlow = false
    @State private var scrollPosition: MealTimeSlot?
    @State private var didEnsureDrafts = false

    private var livePlan: FaceOriginPlan { store.plan ?? plan }

    private var entries: [PlanDayMealEntry] {
        PlanDayMealsProvider.entries(plan: livePlan, day: day, store: store)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerRow
            mealCarousel
        }
        .task(id: day.id) {
            guard !didEnsureDrafts else { return }
            PlanDayMealsProvider.ensureDefaultDrafts(plan: livePlan, day: day, store: store)
            didEnsureDrafts = true
            scrollPosition = PlanMealSlotLabel.preferredSlot(in: livePlan.configuredMealSlots)
        }
        .onChange(of: store.plan?.progress.draftMealsBySlot[day.id]) { _, _ in
            syncViewModelWithSelectedEntry()
        }
        .onChange(of: store.plan?.progress.validatedMealsBySlot[day.id]) { _, _ in
            syncViewModelWithSelectedEntry()
        }
        .sheet(item: $selectedEntry) { entry in
            PlanMealDetailView(
                entry: refreshedEntry(entry),
                isEditable: isEditable,
                onValidate: isEditable ? { validate(entry) } : nil,
                onModify: isEditable ? { modify(entry) } : nil,
                onDismiss: { selectedEntry = nil }
            )
        }
        .sheet(isPresented: $showAllMeals) {
            PlanMealAllMealsSheet(
                entries: entries,
                onSelect: { entry in
                    showAllMeals = false
                    selectedEntry = entry
                },
                onDismiss: { showAllMeals = false }
            )
        }
        .sheet(isPresented: $showModifyFlow) {
            if let content = viewModel.currentContent() {
                MealSuggestionCardView(
                    content: content,
                    showsActions: true,
                    showsScoreBreakdown: content.showsScore,
                    revealedActionIDs: viewModel.revealedActionIDs,
                    onValidate: {
                        store.saveValidatedMeal(dayId: day.id, meal: content, slot: content.timeSlot)
                        store.clearDraftMeal(dayId: day.id, slot: content.timeSlot)
                        _ = viewModel.validateCurrentMeal()
                        showModifyFlow = false
                        selectedEntry = nil
                    },
                    onModify: {
                        Task {
                            await viewModel.requestMeal(
                                plan: livePlan,
                                day: day,
                                profile: profileService.currentProfile,
                                slot: content.timeSlot,
                                mode: .modify(current: content)
                            )
                        }
                    },
                    onAnother: {
                        Task {
                            await viewModel.requestMeal(
                                plan: livePlan,
                                day: day,
                                profile: profileService.currentProfile,
                                slot: content.timeSlot,
                                mode: .another(previous: content)
                            )
                        }
                    },
                    onAddToShoppingList: {
                        store.addMealToShoppingList(content, dayId: day.id)
                    }
                )
                .padding()
                .presentationDetents([.large])
            }
        }
    }

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Repas du jour")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(theme.primaryText)

            Spacer(minLength: 8)

            Button("Tout voir") {
                showAllMeals = true
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(theme.secondaryText)
        }
    }

    private var mealCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(entries) { entry in
                    PlanMealCarouselCard(entry: entry) {
                        selectedEntry = entry
                    }
                    .frame(width: 268)
                    .id(entry.slot)
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, 2)
            .padding(.top, 36)
            .padding(.bottom, 8)
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $scrollPosition, anchor: .center)
        .frame(height: 300)
    }

    private func refreshedEntry(_ entry: PlanDayMealEntry) -> PlanDayMealEntry {
        entries.first(where: { $0.slot == entry.slot }) ?? entry
    }

    private func validate(_ entry: PlanDayMealEntry) {
        store.saveValidatedMeal(dayId: day.id, meal: entry.meal, slot: entry.slot)
        store.clearDraftMeal(dayId: day.id, slot: entry.slot)
        selectedEntry = nil
    }

    private func modify(_ entry: PlanDayMealEntry) {
        selectedEntry = nil
        viewModel.restoreSuggestion(entry.meal)
        showModifyFlow = true
    }

    private func syncViewModelWithSelectedEntry() {
        guard showModifyFlow, let content = viewModel.currentContent() else { return }
        store.saveDraftMeal(dayId: day.id, meal: content, slot: content.timeSlot)
    }
}

// MARK: - Carte carousel

private struct PlanMealCarouselCard: View {
    let entry: PlanDayMealEntry
    var onTap: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                OptionalAssetImage(
                    name: entry.imageAssetName,
                    contentMode: .fit,
                    height: 148,
                    foregroundStyle: theme.secondaryText
                )
                .shadow(color: theme.primaryText.opacity(theme.isDark ? 0.22 : 0.12), radius: 12, y: 6)
                .padding(.top, 10)
                .accessibilityHidden(true)

                VStack(spacing: 4) {
                    Text(entry.carouselTitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.secondaryText)
                    Text(entry.meal.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(theme.primaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 18)
            }
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(theme.isDark ? theme.cardBackgroundStrong : theme.coachUserBubble)
                    .overlay {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .strokeBorder(theme.cardStroke, lineWidth: theme.isDark ? 0 : 0.5)
                    }
                    .shadow(color: theme.primaryText.opacity(theme.isDark ? 0.18 : 0.07), radius: 18, y: 8)
            }
            .overlay(alignment: .topTrailing) {
                if entry.isValidated {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                        .padding(14)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tout voir

private struct PlanMealAllMealsSheet: View {
    let entries: [PlanDayMealEntry]
    var onSelect: (PlanDayMealEntry) -> Void
    var onDismiss: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    ForEach(entries) { entry in
                        PlanMealCarouselCard(entry: entry) {
                            onSelect(entry)
                        }
                        .frame(maxWidth: 320)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(20)
            }
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Repas du jour")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer", action: onDismiss)
                }
            }
        }
    }
}
