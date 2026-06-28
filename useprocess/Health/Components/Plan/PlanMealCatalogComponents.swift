import SwiftUI

// MARK: - Layout

enum PlanMealCatalogLayout {
    static let cardWidth: CGFloat = 172
    static let cardHeight: CGFloat = 260
    static let cornerRadius: CGFloat = 28
    static let spacing: CGFloat = 14
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
            .padding(.vertical, 4)
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollClipDisabled()
    }
}

// MARK: - Carte catalogue (style produit)

struct PlanMealCatalogCard: View {
    let meal: MealSuggestionContent
    let slot: MealTimeSlot
    let plan: FaceOriginPlan
    let day: OriginProgramDay
    var onTap: () -> Void

    @Environment(\.appTheme) private var theme

    private var profile: MealNutritionProfile { MealNutritionCatalog.profile(for: meal) }
    private var imageAsset: String {
        MealNutritionCatalog.resolvedImageAsset(
            for: meal,
            slot: slot,
            dayIndex: day.globalDayIndex,
            planType: plan.nutritionPlanType
        )
    }

    var body: some View {
        Button {
            HapticManager.shared.impact(.light)
            onTap()
        } label: {
            ZStack {
                mealImage

                LinearGradient(
                    colors: [
                        .black.opacity(0.08),
                        .clear,
                        .black.opacity(0.22),
                        .black.opacity(0.82)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)

                VStack(spacing: 0) {
                    caloriesPill
                        .padding(.top, 14)

                    Spacer(minLength: 0)

                    titleBlock
                        .padding(.horizontal, 14)
                        .padding(.bottom, 10)

                    caloriesFooter
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                }
            }
            .frame(width: PlanMealCatalogLayout.cardWidth, height: PlanMealCatalogLayout.cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: PlanMealCatalogLayout.cornerRadius, style: .continuous))
            .overlay {
                PlanTrainingCardReliefOverlay(
                    cornerRadius: PlanMealCatalogLayout.cornerRadius,
                    isDark: theme.isDark
                )
            }
        }
        .buttonStyle(PlanTrainingCard3DPressStyle(restTilt: 3))
        .shadow(color: .black.opacity(theme.isDark ? 0.45 : 0.12), radius: 2, y: 2)
        .shadow(color: .black.opacity(theme.isDark ? 0.38 : 0.14), radius: 14, y: 8)
    }

    private var mealImage: some View {
        Group {
            if ProcessAssetCatalog.contains(imageAsset) {
                Image(imageAsset)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(red: 0.88, green: 0.94, blue: 0.90),
                            Color(red: 0.72, green: 0.86, blue: 0.78)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    Image(systemName: slot.icon)
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(theme.onboardingAccent.opacity(0.75))
                }
            }
        }
        .frame(width: PlanMealCatalogLayout.cardWidth, height: PlanMealCatalogLayout.cardHeight)
        .clipped()
    }

    private var caloriesPill: some View {
        Text("\(profile.calories) kcal")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white.opacity(0.96))
            .monospacedDigit()
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                Capsule()
                    .fill(.black.opacity(0.38))
                    .overlay {
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5)
                    }
            }
    }

    private var titleBlock: some View {
        Text(meal.name)
            .font(.system(size: 24, weight: .bold, design: .rounded))
            .italic()
            .foregroundStyle(.white)
            .multilineTextAlignment(.leading)
            .lineLimit(3)
            .minimumScaleFactor(0.82)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var caloriesFooter: some View {
        Text("\(profile.calories) kcal")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white.opacity(0.95))
            .monospacedDigit()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .frame(height: 48)
            .background {
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.38, green: 0.58, blue: 0.98),
                                Color(red: 0.52, green: 0.44, blue: 0.96)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.5)
                    }
            }
    }
}
