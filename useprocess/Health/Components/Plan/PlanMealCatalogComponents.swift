import SwiftUI

// MARK: - Layout (catalogue — tuiles photo, sans chrome glass)

enum PlanMealCatalogLayout {
    static let tileSize: CGFloat = 168
    static let cornerRadius: CGFloat = 22
    static let spacing: CGFloat = 12

    /// Compat anciens call sites
    static var cardWidth: CGFloat { tileSize }
    static var cardHeight: CGFloat { tileSize }
    static var imageDiameter: CGFloat { tileSize - 8 }
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
                            .scaleEffect(phase.isIdentity ? 1 : 0.94)
                            .opacity(phase.isIdentity ? 1 : 0.82)
                    }
                }
            }
            .scrollTargetLayout()
            .padding(.vertical, 2)
            .padding(.trailing, 20)
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollClipDisabled()
    }
}

// MARK: - Tuile catalogue (photo + score — pas de glass, pas de titre)

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

    private var tileShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: PlanMealCatalogLayout.cornerRadius, style: .continuous)
    }

    var body: some View {
        Button {
            HapticManager.shared.impact(.light)
            onTap()
        } label: {
            ZStack(alignment: .bottomLeading) {
                mealImage
                    .frame(
                        width: PlanMealCatalogLayout.tileSize,
                        height: PlanMealCatalogLayout.tileSize
                    )
                    .clipShape(tileShape)

                MealDebloatScorePill(assessment: assessment)
                    .padding(10)
            }
            .frame(
                width: PlanMealCatalogLayout.tileSize,
                height: PlanMealCatalogLayout.tileSize
            )
            .contentShape(tileShape)
        }
        .buttonStyle(PlanMealCatalogTileButtonStyle())
        .accessibilityLabel(
            AppCopy.t(
                "\(meal.localizedDisplayName), score Debloat \(assessment.score)",
                en: "\(meal.localizedDisplayName), Debloat score \(assessment.score)"
            )
        )
        .accessibilityHint(
            AppCopy.t("Ouvre la fiche recette", en: "Opens the recipe detail")
        )
    }

    @ViewBuilder
    private var mealImage: some View {
        if ProcessAssetCatalog.contains(imageAsset) {
            Image(imageAsset)
                .resizable()
                .scaledToFill()
                .frame(
                    width: PlanMealCatalogLayout.tileSize,
                    height: PlanMealCatalogLayout.tileSize
                )
        } else {
            ZStack {
                theme.primaryText.opacity(theme.isDark ? 0.08 : 0.05)
                Image(systemName: slot.icon)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(theme.onboardingAccent.opacity(0.75))
            }
        }
    }
}

private struct PlanMealCatalogTileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: configuration.isPressed)
    }
}
