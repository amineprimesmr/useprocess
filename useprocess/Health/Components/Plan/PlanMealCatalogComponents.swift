import SwiftUI

// MARK: - Layout (aligné sur les cartes repas Accueil)

enum PlanMealCatalogLayout {
    static let cardWidth: CGFloat = 212
    static let cardHeight: CGFloat = 268
    static let imageDiameter: CGFloat = 152
    static let cornerRadius: CGFloat = 30
    static let spacing: CGFloat = 10
}

// MARK: - Carousel

struct PlanMealCatalogCarousel: View {
    let meals: [MealSuggestionContent]
    let slot: MealTimeSlot
    let plan: FaceOriginPlan
    let day: OriginProgramDay
    var onOpen: (MealSuggestionContent) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PlanMealCatalogLayout.spacing) {
                ForEach(meals, id: \.name) { meal in
                    PlanMealCatalogCard(
                        meal: meal,
                        slot: slot,
                        plan: plan,
                        day: day,
                        onTap: { onOpen(meal) }
                    )
                    .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                        content
                            .scaleEffect(phase.isIdentity ? 1 : 0.9)
                            .opacity(phase.isIdentity ? 1 : 0.78)
                    }
                }
            }
            .scrollTargetLayout()
            .padding(.vertical, 4)
            .padding(.trailing, 20)
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollClipDisabled()
    }
}

// MARK: - Carte catalogue (liquid glass — même langage que Accueil)

struct PlanMealCatalogCard: View {
    let meal: MealSuggestionContent
    let slot: MealTimeSlot
    let plan: FaceOriginPlan
    let day: OriginProgramDay
    var onTap: () -> Void

    @Environment(\.appTheme) private var theme

    private var assessment: MealDebloatAssessment {
        MealNutritionCatalog.debloatAssessment(for: meal)
    }

    private var imageAsset: String {
        MealNutritionCatalog.resolvedImageAsset(
            for: meal,
            slot: slot,
            dayIndex: day.globalDayIndex,
            planType: plan.nutritionPlanType
        )
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: PlanMealCatalogLayout.cornerRadius, style: .continuous)
    }

    var body: some View {
        Button {
            HapticManager.shared.impact(.light)
            onTap()
        } label: {
            VStack(spacing: 12) {
                Text(meal.localizedDisplayName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.primaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)
                    .padding(.horizontal, 14)
                    .padding(.top, 18)

                ZStack(alignment: .bottom) {
                    mealImage

                    MealDebloatScorePill(assessment: assessment)
                        .padding(.bottom, 2)
                }
                .frame(height: PlanMealCatalogLayout.imageDiameter + 10)

                Spacer(minLength: 0)
            }
            .frame(
                width: PlanMealCatalogLayout.cardWidth,
                height: PlanMealCatalogLayout.cardHeight
            )
        }
        .buttonStyle(.processPlain)
        .frame(
            width: PlanMealCatalogLayout.cardWidth,
            height: PlanMealCatalogLayout.cardHeight
        )
        .background {
            cardShape
                .fill(.clear)
                .processGlassEffect(in: cardShape)
        }
        .clipShape(cardShape)
        .processHomeGlassCardShadow(isDark: theme.isDark)
        .accessibilityLabel(AppCopy.t("\(meal.localizedDisplayName), score Debloat \(assessment.score)", en: "\(meal.localizedDisplayName), Debloat score \(assessment.score)"))
    }

    @ViewBuilder
    private var mealImage: some View {
        if ProcessAssetCatalog.contains(imageAsset) {
            // PNG tels quels — pas de clip circulaire (évite le « rond noir » autour).
            Image(imageAsset)
                .resizable()
                .scaledToFit()
                .frame(
                    width: PlanMealCatalogLayout.imageDiameter,
                    height: PlanMealCatalogLayout.imageDiameter
                )
        } else {
            Image(systemName: slot.icon)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(theme.onboardingAccent.opacity(0.8))
                .frame(
                    width: PlanMealCatalogLayout.imageDiameter,
                    height: PlanMealCatalogLayout.imageDiameter
                )
        }
    }
}
