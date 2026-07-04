import SwiftUI

/// Hero détail repas — propositions adjacentes en cover-flow 3D, swipe horizontal fluide.
struct PlanMealDetailAlternativesHero: View {
    let alternatives: [MealSuggestionContent]
    let slot: MealTimeSlot
    let plan: FaceOriginPlan
    let day: OriginProgramDay
    @Binding var selectedMeal: MealSuggestionContent
    private let heroItems: [PlanMealDetailHeroItem]

    @Environment(\.appTheme) private var theme

    init(
        alternatives: [MealSuggestionContent],
        slot: MealTimeSlot,
        plan: FaceOriginPlan,
        day: OriginProgramDay,
        selectedMeal: Binding<MealSuggestionContent>
    ) {
        self.alternatives = alternatives
        self.slot = slot
        self.plan = plan
        self.day = day
        _selectedMeal = selectedMeal
        heroItems = alternatives.map { meal in
            PlanMealDetailHeroItem(
                meal: meal,
                imageAsset: MealNutritionCatalog.resolvedImageAsset(
                    for: meal,
                    slot: slot,
                    dayIndex: day.globalDayIndex,
                    planType: plan.nutritionPlanType
                ),
                assessment: MealNutritionCatalog.debloatAssessment(for: meal)
            )
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            PlanMealDetailAlternativesCarousel(
                items: heroItems,
                slot: slot,
                selectedMeal: $selectedMeal
            )

            if alternatives.count > 1 {
                PlanMealDetailHeroPageIndicator(
                    currentIndex: selectedIndex,
                    totalCount: alternatives.count
                )
            }
        }
    }

    private var selectedIndex: Int {
        alternatives.firstIndex(where: { $0.name == selectedMeal.name }) ?? 0
    }
}

// MARK: - Carousel

private struct PlanMealDetailHeroItem: Identifiable {
    let meal: MealSuggestionContent
    let imageAsset: String
    let assessment: MealDebloatAssessment

    var id: String { meal.name }
}

private struct PlanMealDetailAlternativesCarousel: View {
    let items: [PlanMealDetailHeroItem]
    let slot: MealTimeSlot
    @Binding var selectedMeal: MealSuggestionContent

    @State private var scrollPosition: String?
    @State private var scrollPhase: ScrollPhase = .idle

    private let cardSize: CGFloat = 152
    private let cardSpacing: CGFloat = 52
    private let carouselHeight: CGFloat = 228

    init(
        items: [PlanMealDetailHeroItem],
        slot: MealTimeSlot,
        selectedMeal: Binding<MealSuggestionContent>
    ) {
        self.items = items
        self.slot = slot
        _selectedMeal = selectedMeal
        _scrollPosition = State(initialValue: selectedMeal.wrappedValue.name)
    }

    var body: some View {
        GeometryReader { geo in
            let inset = horizontalInset(containerWidth: geo.size.width)

            ScrollView(.horizontal, showsIndicators: false) {
                carouselItems
            }
            .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne))
            .scrollPosition(id: $scrollPosition, anchor: .center)
            .scrollClipDisabled()
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .contentMargins(.horizontal, inset, for: .scrollContent)
        }
        .frame(height: carouselHeight)
        .clipped()
        .onScrollPhaseChange { _, newPhase in
            let wasScrolling = scrollPhase != .idle
            scrollPhase = newPhase
            if wasScrolling && newPhase == .idle {
                HapticManager.shared.selection()
            }
        }
        .onChange(of: scrollPosition) { _, newValue in
            applyScrollSelection(from: newValue)
        }
        .onChange(of: selectedMeal.name) { _, newName in
            guard scrollPosition != newName else { return }
            scrollPosition = newName
        }
    }

    private var activeMealName: String {
        scrollPosition ?? selectedMeal.name
    }

    private var carouselItems: some View {
        LazyHStack(spacing: cardSpacing) {
            ForEach(items) { item in
                PlanMealDetailHeroCard(
                    meal: item.meal,
                    imageAsset: item.imageAsset,
                    assessment: item.assessment,
                    slot: slot,
                    cardSize: cardSize,
                    isFocused: item.meal.name == activeMealName
                )
                .processCoverFlowScrollTransition(config: coverFlowConfig)
                .id(item.meal.name)
            }
        }
        .scrollTargetLayout()
        .padding(.vertical, 10)
    }

    private var coverFlowConfig: ProcessScrollCoverFlowEffect.Configuration {
        var config = ProcessScrollCoverFlowEffect.Configuration()
        config.yRotationDegrees = 18
        config.scaleReduction = 0.12
        config.opacityReduction = 0.38
        config.horizontalOffset = 10
        config.verticalOffset = 10
        return config
    }

    private func horizontalInset(containerWidth: CGFloat) -> CGFloat {
        max(16, (containerWidth - cardSize) / 2)
    }

    private func applyScrollSelection(from scrollID: String?) {
        guard let scrollID,
              let meal = items.first(where: { $0.meal.name == scrollID })?.meal,
              meal.name != selectedMeal.name else { return }

        selectedMeal = meal
    }
}

// MARK: - Carte

private struct PlanMealDetailHeroCard: View {
    let meal: MealSuggestionContent
    let imageAsset: String
    let assessment: MealDebloatAssessment
    let slot: MealTimeSlot
    let cardSize: CGFloat
    let isFocused: Bool

    @Environment(\.appTheme) private var theme

    var body: some View {
        ZStack(alignment: .bottom) {
            mealPhoto
            if isFocused {
                MealDebloatScoreGlassPill(assessment: assessment)
                    .offset(y: 10)
            }
        }
        .frame(width: cardSize, height: cardSize + 18)
        .accessibilityLabel(meal.name)
        .accessibilityAddTraits(isFocused ? .isSelected : [])
    }

    private var mealPhoto: some View {
        Group {
            if ProcessAssetCatalog.contains(imageAsset) {
                Image(imageAsset)
                    .resizable()
                    .scaledToFill()
            } else {
                mealPlaceholder
            }
        }
        .frame(width: cardSize, height: cardSize)
        .clipShape(Circle())
        .overlay { mealPhotoBorder }
        .shadow(
            color: .black.opacity(isFocused ? (theme.isDark ? 0.38 : 0.14) : 0.10),
            radius: isFocused ? 18 : 10,
            y: isFocused ? 12 : 5
        )
    }

    private var mealPlaceholder: some View {
        ZStack {
            Circle()
                .fill(theme.cardBackgroundStrong.opacity(theme.isDark ? 0.55 : 0.35))
            Image(systemName: slot.icon)
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(theme.onboardingAccent.opacity(0.8))
        }
    }

    private var mealPhotoBorder: some View {
        Circle()
            .strokeBorder(
                Color.primary.opacity(isFocused ? (theme.isDark ? 0.18 : 0.10) : 0.06),
                lineWidth: isFocused ? 1 : 0.5
            )
    }
}

// MARK: - Indicateur

private struct PlanMealDetailHeroPageIndicator: View {
    let currentIndex: Int
    let totalCount: Int

    @Environment(\.appTheme) private var theme

    var body: some View {
        Text("\(currentIndex + 1) / \(totalCount)")
            .font(.caption.weight(.semibold))
            .foregroundStyle(theme.secondaryText)
            .monospacedDigit()
            .contentTransition(.numericText())
            .animation(.easeOut(duration: 0.15), value: currentIndex)
    }
}
