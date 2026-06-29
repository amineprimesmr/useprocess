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

    /// Entrée catalogue — hors carousel des idées du jour.
    static func catalog(
        meal: MealSuggestionContent,
        slot: MealTimeSlot,
        plan: FaceOriginPlan,
        day: OriginProgramDay
    ) -> PlanDayMealEntry {
        let mealSlots = WelcomePlanStore.shared.plan?.progress.validatedMealsBySlot[day.id]
        let validated = mealSlots?[slot.rawValue] != nil
        return PlanDayMealEntry(
            slot: slot,
            meal: meal,
            isValidated: validated,
            planType: plan.nutritionPlanType,
            dayIndex: day.globalDayIndex
        )
    }
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
    var selectedDate: Date
    var isEditable: Bool = true
    var mealZoomNamespace: Namespace.ID

    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var profileService: UnifiedProfileService

    @State private var selectedEntry: PlanDayMealEntry?
    @State private var showMealIdeasCatalog = false
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
                onDismiss: { selectedEntry = nil }
            )
            .environmentObject(profileService)
            .processZoomTransition(id: .mealDetail(entry.slot), namespace: mealZoomNamespace)
        }
        .fullScreenCover(isPresented: $showMealIdeasCatalog) {
            PlanMealIdeasCatalogSheet(
                plan: livePlan,
                day: day,
                isEditable: isEditable,
                mealZoomNamespace: mealZoomNamespace
            )
            .environmentObject(profileService)
            .processZoomTransition(id: .mealCatalog, namespace: mealZoomNamespace)
        }
    }

    private var headerRow: some View {
        PlanHomeSectionHeader(title: "Repas debloat")
    }

    private var mealCarousel: some View {
        PlanMealCoverFlowCarousel(
            entries: entries,
            catalogCount: ProcessDebloatMealLibrary.catalogMealCount(for: livePlan.nutritionPlanType),
            previewImageAssets: ProcessDebloatMealLibrary.catalogPreviewImageAssets(
                for: livePlan.nutritionPlanType
            ),
            scrollPosition: $scrollPosition,
            mealZoomNamespace: mealZoomNamespace,
            onSelect: { selectedEntry = $0 },
            onBrowseCatalog: { showMealIdeasCatalog = true }
        )
        .padding(.horizontal, -PlanHomeSectionDesign.homeScrollPadding)
    }

    private func refreshedEntry(_ entry: PlanDayMealEntry) -> PlanDayMealEntry {
        entries.first(where: { $0.slot == entry.slot }) ?? entry
    }

    private func refreshSelectedEntryIfNeeded() {
        guard let current = selectedEntry else { return }
        selectedEntry = refreshedEntry(current)
    }
}

// MARK: - Carousel repas

private struct PlanMealCoverFlowCarousel: View {
    let entries: [PlanDayMealEntry]
    let catalogCount: Int
    let previewImageAssets: [String]
    @Binding var scrollPosition: MealTimeSlot?
    let mealZoomNamespace: Namespace.ID
    var onSelect: (PlanDayMealEntry) -> Void
    var onBrowseCatalog: () -> Void

    private let cardSpacing: CGFloat = 10

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            carouselContent
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $scrollPosition, anchor: .center)
        .frame(height: PlanMealCarouselLayout.cardHeight + 8)
    }

    private var carouselContent: some View {
        LazyHStack(spacing: cardSpacing) {
            ForEach(entries) { entry in
                PlanMealCarouselCard(
                    entry: entry,
                    zoomNamespace: mealZoomNamespace,
                    onTap: { onSelect(entry) }
                )
                .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                    content
                        .scaleEffect(phase.isIdentity ? 1 : 0.9)
                        .opacity(phase.isIdentity ? 1 : 0.78)
                }
                .id(entry.slot)
            }

            PlanMealCatalogBrowseCard(
                catalogCount: catalogCount,
                previewImageAssets: previewImageAssets,
                zoomNamespace: mealZoomNamespace,
                onTap: onBrowseCatalog
            )
            .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                content
                    .scaleEffect(phase.isIdentity ? 1 : 0.9)
                    .opacity(phase.isIdentity ? 1 : 0.78)
            }
        }
        .scrollTargetLayout()
        .padding(.horizontal, PlanHomeSectionDesign.homeScrollPadding)
        .padding(.vertical, 4)
    }
}

// MARK: - Carte catalogue (fin de carousel)

private struct PlanMealCatalogBrowseCard: View {
    let catalogCount: Int
    let previewImageAssets: [String]
    var zoomNamespace: Namespace.ID? = nil
    var onTap: () -> Void

    @Environment(\.appTheme) private var theme

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: PlanMealCarouselLayout.cornerRadius, style: .continuous)
    }

    var body: some View {
        Button {
            HapticManager.shared.impact(.light)
            onTap()
        } label: {
            VStack(spacing: 12) {
                Text("Toutes les idées")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.primaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)
                    .padding(.horizontal, 14)
                    .padding(.top, 18)

                ZStack {
                    previewCollage

                    catalogCountPill
                        .padding(.bottom, 2)
                }
                .frame(height: PlanMealCarouselLayout.imageDiameter + 10)

                Spacer(minLength: 0)
            }
            .frame(
                width: PlanMealCarouselLayout.cardWidth,
                height: PlanMealCarouselLayout.cardHeight
            )
            .overlay(alignment: .topTrailing) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(theme.onboardingAccent)
                    .padding(12)
            }
        }
        .buttonStyle(.plain)
        .frame(
            width: PlanMealCarouselLayout.cardWidth,
            height: PlanMealCarouselLayout.cardHeight
        )
        .processGlassButton(in: cardShape)
        .clipShape(cardShape)
        .processHomeGlassCardShadow(isDark: theme.isDark)
        .processZoomSource(id: .mealCatalog, namespace: zoomNamespace)
        .accessibilityLabel("Voir tous les repas debloat du catalogue")
    }

    @ViewBuilder
    private var previewCollage: some View {
        let assets = Array(previewImageAssets.prefix(3))
        if assets.isEmpty {
            Circle()
                .fill(theme.cardBackgroundStrong.opacity(theme.isDark ? 0.55 : 0.35))
                .frame(
                    width: PlanMealCarouselLayout.imageDiameter,
                    height: PlanMealCarouselLayout.imageDiameter
                )
                .overlay {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(theme.onboardingAccent.opacity(0.8))
                }
        } else if assets.count == 1 {
            singlePreviewImage(assets[0])
        } else {
            ZStack {
                if assets.count >= 2 {
                    singlePreviewImage(assets[1])
                        .frame(width: 88, height: 88)
                        .offset(x: -36, y: 12)
                        .opacity(0.82)
                }
                if assets.count >= 3 {
                    singlePreviewImage(assets[2])
                        .frame(width: 88, height: 88)
                        .offset(x: 36, y: 12)
                        .opacity(0.82)
                }
                singlePreviewImage(assets[0])
            }
            .frame(
                width: PlanMealCarouselLayout.imageDiameter,
                height: PlanMealCarouselLayout.imageDiameter
            )
        }
    }

    private func singlePreviewImage(_ asset: String) -> some View {
        Group {
            if ProcessAssetCatalog.contains(asset) {
                Image(asset)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle()
                    .fill(theme.cardBackgroundStrong.opacity(0.5))
            }
        }
        .frame(width: PlanMealCarouselLayout.imageDiameter, height: PlanMealCarouselLayout.imageDiameter)
        .clipShape(Circle())
        .overlay {
            Circle()
                .strokeBorder(Color.primary.opacity(theme.isDark ? 0.12 : 0.06), lineWidth: 0.5)
        }
    }

    private var catalogCountPill: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.caption2.weight(.bold))
                .foregroundStyle(theme.onboardingAccent)

            Text("\(catalogCount) recettes")
                .font(.caption.weight(.bold))
                .foregroundStyle(theme.primaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                }
        }
    }
}

// MARK: - Carte carousel (liquid glass)

private enum PlanMealCarouselLayout {
    static let cardWidth: CGFloat = 212
    static let cardHeight: CGFloat = 268
    static let imageDiameter: CGFloat = 152
    static let cornerRadius: CGFloat = 30
}

private struct PlanMealCarouselCard: View {
    let entry: PlanDayMealEntry
    let zoomNamespace: Namespace.ID
    var onTap: () -> Void

    @Environment(\.appTheme) private var theme

    private var profile: MealNutritionProfile {
        MealNutritionCatalog.profile(for: entry.meal)
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: PlanMealCarouselLayout.cornerRadius, style: .continuous)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Text(entry.meal.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.primaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)
                    .padding(.horizontal, 14)
                    .padding(.top, 18)

                ZStack(alignment: .bottom) {
                    mealImageCircle

                    caloriesPill
                        .padding(.bottom, 2)
                }
                .frame(height: PlanMealCarouselLayout.imageDiameter + 10)

                Spacer(minLength: 0)
            }
            .frame(
                width: PlanMealCarouselLayout.cardWidth,
                height: PlanMealCarouselLayout.cardHeight
            )
        }
        .buttonStyle(.plain)
        .frame(
            width: PlanMealCarouselLayout.cardWidth,
            height: PlanMealCarouselLayout.cardHeight
        )
        .processGlassButton(in: cardShape)
        .clipShape(cardShape)
        .processHomeGlassCardShadow(isDark: theme.isDark)
        .processZoomSource(id: .mealDetail(entry.slot), namespace: zoomNamespace)
    }

    @ViewBuilder
    private var mealImageCircle: some View {
        if ProcessAssetCatalog.contains(entry.imageAssetName) {
            Image(entry.imageAssetName)
                .resizable()
                .scaledToFill()
                .frame(
                    width: PlanMealCarouselLayout.imageDiameter,
                    height: PlanMealCarouselLayout.imageDiameter
                )
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .strokeBorder(Color.primary.opacity(theme.isDark ? 0.12 : 0.06), lineWidth: 0.5)
                }
        } else {
            Circle()
                .fill(theme.cardBackgroundStrong.opacity(theme.isDark ? 0.55 : 0.35))
                .frame(
                    width: PlanMealCarouselLayout.imageDiameter,
                    height: PlanMealCarouselLayout.imageDiameter
                )
                .overlay {
                    Image(systemName: entry.slot.icon)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(theme.onboardingAccent.opacity(0.8))
                }
        }
    }

    private var caloriesPill: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.orange)

            Text("\(profile.calories) Kcal")
                .font(.caption.weight(.bold))
                .foregroundStyle(theme.primaryText)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                }
        }
    }
}
