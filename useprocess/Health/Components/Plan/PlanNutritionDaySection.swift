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

    @State private var viewModel = OriginMealSuggestionViewModel()
    @State private var selectedEntry: PlanDayMealEntry?
    @State private var showAllMeals = false
    @State private var showModifyFlow = false
    @State private var scrollPosition: MealTimeSlot?

    private var store: WelcomePlanStore { WelcomePlanStore.shared }
    private var livePlan: FaceOriginPlan { store.plan ?? plan }

    private var entries: [PlanDayMealEntry] {
        PlanDayMealsProvider.entries(plan: livePlan, day: day, store: store)
    }

    private var focusedMealSlot: MealTimeSlot {
        PlanMealSlotLabel.preferredSlot(
            in: livePlan.configuredMealSlots,
            validated: Set(entries.filter(\.isValidated).map(\.slot))
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            headerRow
            mealCarousel
        }
        .task(id: day.id) {
            PlanDayMealsProvider.ensureDefaultDrafts(plan: livePlan, day: day, store: store)
            let target = focusedMealSlot
            if scrollPosition != target {
                scrollPosition = target
            }
        }
        .onChange(of: entries.map(\.isValidated)) { _, _ in
            let target = focusedMealSlot
            guard scrollPosition != target else { return }
            scrollPosition = target
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
        GeometryReader { geo in
            let cardWidth: CGFloat = 268
            let sideInset = max(0, (geo.size.width - cardWidth) / 2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(entries) { entry in
                        PlanMealCarouselCard(entry: entry) {
                            selectedEntry = entry
                        }
                        .frame(width: cardWidth)
                        .id(entry.slot)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, sideInset)
                .padding(.top, 4)
                .padding(.bottom, 8)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $scrollPosition, anchor: .center)
            .scrollClipDisabled()
        }
        .frame(height: 252)
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

private enum PlanMealCarouselLayout {
    static let imageHeight: CGFloat = 148
    static let imageOverhang: CGFloat = 38
    static let cardBodyTopInset: CGFloat = imageHeight - imageOverhang
    static let cornerRadius: CGFloat = 26
}

private struct PlanMealCarouselCard: View {
    let entry: PlanDayMealEntry
    var onTap: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: PlanMealCarouselLayout.cardBodyTopInset)

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
                .background { cardBackground }

                OptionalAssetImage(
                    name: entry.imageAssetName,
                    contentMode: .fit,
                    height: PlanMealCarouselLayout.imageHeight,
                    foregroundStyle: theme.secondaryText
                )
                .shadow(
                    color: theme.primaryText.opacity(theme.isDark ? 0.22 : 0.12),
                    radius: 12,
                    y: 6
                )
                .offset(y: -PlanMealCarouselLayout.imageOverhang)
                .accessibilityHidden(true)
            }
            .padding(.top, PlanMealCarouselLayout.imageOverhang)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .topTrailing) {
                if entry.isValidated {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                        .padding(.top, PlanMealCarouselLayout.imageOverhang + 6)
                        .padding(.trailing, 14)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: PlanMealCarouselLayout.cornerRadius, style: .continuous)
            .fill(theme.isDark ? theme.cardBackgroundStrong : theme.coachUserBubble)
            .overlay {
                RoundedRectangle(cornerRadius: PlanMealCarouselLayout.cornerRadius, style: .continuous)
                    .strokeBorder(theme.cardStroke, lineWidth: theme.isDark ? 0 : 0.5)
            }
            .shadow(color: theme.primaryText.opacity(theme.isDark ? 0.18 : 0.07), radius: 18, y: 8)
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
