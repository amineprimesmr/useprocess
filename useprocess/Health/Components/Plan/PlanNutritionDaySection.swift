import SwiftUI
import UIKit

struct PlanDayMealEntry: Identifiable, Equatable {
    let slot: MealTimeSlot
    let meal: MealSuggestionContent
    let isValidated: Bool
    let planType: NutritionPlanType

    var id: String { slot.rawValue }

    var carouselTitle: String { PlanMealSlotLabel.carouselTitle(for: slot, planType: planType) }
    var imageAssetName: String { MealNutritionCatalog.resolvedImageAsset(for: meal) }
    var scheduleTargetLabel: String? { PlanMealSchedule.targetLabel(for: slot, planType: planType) }
    var scheduleWindowLabel: String? { PlanMealSchedule.windowLabel(for: slot, planType: planType) }
    var scheduleNote: String? { PlanMealSchedule.timing(for: slot, planType: planType)?.debloatNote }
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
            return PlanDayMealEntry(
                slot: slot,
                meal: meal,
                isValidated: validated,
                planType: plan.nutritionPlanType
            )
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
    var mealZoomNamespace: Namespace.ID

    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var profileService: UnifiedProfileService

    @State private var selectedEntry: PlanDayMealEntry?
    @State private var showAllMeals = false
    @State private var scrollPosition: MealTimeSlot?

    private var store: WelcomePlanStore { WelcomePlanStore.shared }
    private var livePlan: FaceOriginPlan { store.plan ?? plan }

    private var entries: [PlanDayMealEntry] {
        PlanDayMealsProvider.entries(plan: livePlan, day: day, store: store)
    }

    private var focusedMealSlot: MealTimeSlot {
        PlanMealSlotLabel.preferredSlot(
            in: livePlan.configuredMealSlots,
            planType: livePlan.nutritionPlanType,
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
            refreshSelectedEntryIfNeeded()
        }
        .onChange(of: store.plan?.progress.validatedMealsBySlot[day.id]) { _, _ in
            refreshSelectedEntryIfNeeded()
        }
        .fullScreenCover(item: $selectedEntry) { entry in
            PlanMealDetailView(
                entry: refreshedEntry(entry),
                plan: livePlan,
                day: day,
                isEditable: isEditable,
                onMealUpdated: { updated in
                    store.saveDraftMeal(dayId: day.id, meal: updated, slot: entry.slot)
                },
                onValidate: isEditable ? { meal in validate(entry: entry, meal: meal) } : nil,
                onDismiss: { selectedEntry = nil }
            )
            .environmentObject(profileService)
            .processZoomTransition(id: .mealDetail(entry.slot), namespace: mealZoomNamespace)
        }
        .sheet(isPresented: $showAllMeals) {
            PlanMealAllMealsSheet(
                entries: entries,
                mealZoomNamespace: mealZoomNamespace,
                onSelect: { entry in
                    showAllMeals = false
                    selectedEntry = entry
                },
                onDismiss: { showAllMeals = false }
            )
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
            let cardWidth = PlanMealCarouselLayout.cardWidth
            let sideInset = max(0, (geo.size.width - cardWidth) / 2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(entries) { entry in
                        PlanMealCarouselCard(
                            entry: entry,
                            zoomNamespace: mealZoomNamespace,
                            onTap: { selectedEntry = entry }
                        )
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
        .frame(height: PlanMealCarouselLayout.cardHeight + 16)
    }

    private func refreshedEntry(_ entry: PlanDayMealEntry) -> PlanDayMealEntry {
        entries.first(where: { $0.slot == entry.slot }) ?? entry
    }

    private func validate(entry: PlanDayMealEntry, meal: MealSuggestionContent) {
        store.saveValidatedMeal(dayId: day.id, meal: meal, slot: entry.slot)
        store.clearDraftMeal(dayId: day.id, slot: entry.slot)
        selectedEntry = nil
    }

    private func refreshSelectedEntryIfNeeded() {
        guard let current = selectedEntry else { return }
        selectedEntry = refreshedEntry(current)
    }
}

// MARK: - Carte carousel

private enum PlanMealCarouselLayout {
    static let cardWidth: CGFloat = 268
    static let imageAreaHeight: CGFloat = 124
    static let textBlockHeight: CGFloat = 104
    static var cardHeight: CGFloat { imageAreaHeight + textBlockHeight }
    static let cornerRadius: CGFloat = 26
}

private struct PlanMealCarouselCard: View {
    let entry: PlanDayMealEntry
    let zoomNamespace: Namespace.ID
    var onTap: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                mealImageHeader
                textBlock
            }
            .frame(width: PlanMealCarouselLayout.cardWidth, height: PlanMealCarouselLayout.cardHeight)
            .background { cardBackground }
            .clipShape(RoundedRectangle(cornerRadius: PlanMealCarouselLayout.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PlanMealCarouselLayout.cornerRadius, style: .continuous)
                    .strokeBorder(theme.cardStroke, lineWidth: theme.isDark ? 0 : 0.5)
            }
            .overlay(alignment: .topTrailing) {
                if entry.isValidated {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                        .padding(.top, 8)
                        .padding(.trailing, 10)
                }
            }
            .shadow(color: theme.primaryText.opacity(theme.isDark ? 0.18 : 0.07), radius: 18, y: 8)
        }
        .buttonStyle(.plain)
        .processZoomSource(id: .mealDetail(entry.slot), namespace: zoomNamespace)
    }

    private var mealImageHeader: some View {
        ZStack {
            OptionalAssetImage(
                name: entry.imageAssetName,
                contentMode: .fit,
                height: PlanMealCarouselLayout.imageAreaHeight - 16,
                foregroundStyle: theme.secondaryText
            )
            .shadow(
                color: theme.primaryText.opacity(theme.isDark ? 0.18 : 0.10),
                radius: 10,
                y: 4
            )
        }
        .frame(height: PlanMealCarouselLayout.imageAreaHeight)
        .accessibilityHidden(true)
    }

    private var textBlock: some View {
        VStack(spacing: 3) {
            Text(entry.carouselTitle)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.secondaryText)

            if let scheduleTarget = entry.scheduleTargetLabel {
                Text(scheduleTarget)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(theme.onboardingAccent)
                    .monospacedDigit()
            }

            Text(entry.meal.name)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(theme.primaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity)
                .frame(height: 40, alignment: .center)
        }
        .padding(.horizontal, 14)
        .frame(height: PlanMealCarouselLayout.textBlockHeight)
    }

    private var cardBackground: some View {
        (theme.isDark ? theme.cardBackgroundStrong : theme.coachUserBubble)
            .opacity(theme.isDark ? 0.92 : 1)
    }
}

// MARK: - Tout voir

private struct PlanMealAllMealsSheet: View {
    let entries: [PlanDayMealEntry]
    let mealZoomNamespace: Namespace.ID
    var onSelect: (PlanDayMealEntry) -> Void
    var onDismiss: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(entries) { entry in
                        PlanMealCarouselCard(
                            entry: entry,
                            zoomNamespace: mealZoomNamespace,
                            onTap: { onSelect(entry) }
                        )
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
