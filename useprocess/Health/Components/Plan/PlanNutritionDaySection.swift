import SwiftUI
import UIKit

struct PlanDayMealEntry: Identifiable, Equatable {
    let slot: MealTimeSlot
    let meal: MealSuggestionContent
    let isValidated: Bool
    let planType: NutritionPlanType
    let dayIndex: Int

    var id: String { slot.rawValue }

    var carouselTitle: String { PlanMealSlotLabel.carouselTitle(for: slot, planType: planType) }
    var imageAssetName: String {
        MealNutritionCatalog.resolvedImageAsset(
            for: meal,
            slot: slot,
            dayIndex: dayIndex,
            planType: planType
        )
    }
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
                planType: plan.nutritionPlanType,
                dayIndex: day.globalDayIndex
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
            withAnimation(.smooth(duration: 0.42)) {
                scrollPosition = target
            }
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
        PlanMealCoverFlowCarousel(
            entries: entries,
            scrollPosition: $scrollPosition,
            mealZoomNamespace: mealZoomNamespace,
            onSelect: { selectedEntry = $0 }
        )
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

// MARK: - Cover flow carousel

private struct PlanMealCoverFlowCarousel: View {
    let entries: [PlanDayMealEntry]
    @Binding var scrollPosition: MealTimeSlot?
    let mealZoomNamespace: Namespace.ID
    var onSelect: (PlanDayMealEntry) -> Void

    private let cardSpacing: CGFloat = -42
    private var carouselHeight: CGFloat {
        PlanMealCarouselLayout.cardHeight + PlanMealCarouselLayout.imageTopBleed + 16
    }

    var body: some View {
        GeometryReader { viewport in
            let viewportWidth = max(viewport.size.width, 1)
            let cardWidth = PlanMealCarouselLayout.cardWidth
            let sideInset = max(0, (viewportWidth - cardWidth) / 2)
            let viewportCenterX = viewportWidth / 2

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: cardSpacing) {
                    ForEach(entries) { entry in
                        PlanMealCoverFlowCardCell(
                            entry: entry,
                            viewportCenterX: viewportCenterX,
                            cardWidth: cardWidth,
                            zoomNamespace: mealZoomNamespace,
                            onTap: { onSelect(entry) }
                        )
                        .id(entry.slot)
                    }
                }
                .scrollTargetLayout()
                .padding(.top, PlanMealCarouselLayout.imageTopBleed + 4)
                .padding(.bottom, 8)
            }
            .contentMargins(.horizontal, sideInset, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $scrollPosition, anchor: .center)
            .scrollClipDisabled()
            .coordinateSpace(name: "mealCoverFlow")
        }
        .frame(height: carouselHeight)
    }
}

private struct PlanMealCoverFlowCardCell: View {
    let entry: PlanDayMealEntry
    let viewportCenterX: CGFloat
    let cardWidth: CGFloat
    let zoomNamespace: Namespace.ID
    var onTap: () -> Void

    private var cardHeight: CGFloat {
        PlanMealCarouselLayout.cardHeight + PlanMealCarouselLayout.imageTopBleed
    }

    var body: some View {
        GeometryReader { cardGeo in
            let cardMidX = cardGeo.frame(in: .named("mealCoverFlow")).midX
            let distance = cardMidX - viewportCenterX
            let span = max(cardWidth * 0.68, 1)
            let normalized = distance / span
            let clamped = min(1.25, max(-1.25, normalized))
            let angle = Double(-clamped) * 54
            let scale = max(0.82, 1.0 - abs(clamped) * 0.11)
            let yOffset = abs(clamped) * 10
            let opacity = max(0.75, 1.0 - abs(clamped) * 0.10)

            PlanMealCarouselCard(
                entry: entry,
                zoomNamespace: zoomNamespace,
                onTap: onTap
            )
            .scaleEffect(scale, anchor: .center)
            .rotation3DEffect(
                .degrees(angle),
                axis: (x: 0, y: 1, z: 0),
                anchor: .center,
                perspective: 0.42
            )
            .offset(y: yOffset)
            .opacity(opacity)
            .zIndex(1_000 - abs(distance))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(width: cardWidth, height: cardHeight)
    }
}

// MARK: - Carte carousel

private enum PlanMealCarouselLayout {
    static let cardWidth: CGFloat = 268
    static let imageAreaHeight: CGFloat = 124
    static let imageTopBleed: CGFloat = 14
    static let imageOverlapIntoGray: CGFloat = 20
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
            ZStack(alignment: .top) {
                grayCardBody
                mealImageHeader
            }
            .frame(
                width: PlanMealCarouselLayout.cardWidth,
                height: PlanMealCarouselLayout.cardHeight + PlanMealCarouselLayout.imageTopBleed
            )
            .overlay(alignment: .topTrailing) {
                if entry.isValidated {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                        .padding(.top, PlanMealCarouselLayout.imageTopBleed + 4)
                        .padding(.trailing, 10)
                }
            }
            .shadow(color: theme.primaryText.opacity(theme.isDark ? 0.18 : 0.07), radius: 18, y: 8)
        }
        .buttonStyle(.plain)
        .processZoomSource(id: .mealDetail(entry.slot), namespace: zoomNamespace)
    }

    private var grayCardBody: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: PlanMealCarouselLayout.imageAreaHeight - PlanMealCarouselLayout.imageOverlapIntoGray)
            textBlock
                .frame(height: PlanMealCarouselLayout.textBlockHeight + PlanMealCarouselLayout.imageOverlapIntoGray)
                .padding(.top, PlanMealCarouselLayout.imageOverlapIntoGray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .background {
            RoundedRectangle(cornerRadius: PlanMealCarouselLayout.cornerRadius, style: .continuous)
                .fill(cardBackgroundColor)
        }
        .overlay {
            RoundedRectangle(cornerRadius: PlanMealCarouselLayout.cornerRadius, style: .continuous)
                .strokeBorder(theme.cardStroke, lineWidth: theme.isDark ? 0 : 0.5)
        }
        .padding(.top, PlanMealCarouselLayout.imageTopBleed)
    }

    private var mealImageHeader: some View {
        OptionalAssetImage(
            name: entry.imageAssetName,
            contentMode: .fit,
            height: PlanMealCarouselLayout.imageAreaHeight + PlanMealCarouselLayout.imageTopBleed,
            foregroundStyle: theme.secondaryText
        )
        .shadow(
            color: theme.primaryText.opacity(theme.isDark ? 0.18 : 0.10),
            radius: 10,
            y: 4
        )
        .offset(y: -PlanMealCarouselLayout.imageTopBleed)
        .frame(height: PlanMealCarouselLayout.imageAreaHeight)
        .frame(maxWidth: .infinity)
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
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var cardBackgroundColor: Color {
        let base = theme.isDark ? theme.cardBackgroundStrong : theme.coachUserBubble
        return base.opacity(theme.isDark ? 0.92 : 1)
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
