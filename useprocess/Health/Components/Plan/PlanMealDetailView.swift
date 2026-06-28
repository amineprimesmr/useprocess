import SwiftUI

/// Page détail repas — ingrédients et préparation.
struct PlanMealDetailView: View {
    let entry: PlanDayMealEntry
    let plan: FaceOriginPlan
    let day: OriginProgramDay
    var isEditable: Bool
    var onDismiss: () -> Void

    @Environment(\.appTheme) private var theme

    private var meal: MealSuggestionContent { entry.meal }

    private var profile: MealNutritionProfile { MealNutritionCatalog.profile(for: meal) }
    private var imageAsset: String {
        MealNutritionCatalog.resolvedImageAsset(
            for: meal,
            slot: entry.slot,
            dayIndex: day.globalDayIndex,
            planType: plan.nutritionPlanType
        )
    }

    private var preparationSteps: [String] {
        MealPreparationStepsParser.steps(from: meal.prepSummary)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    mealHeroHeader

                    Text(meal.name)
                        .font(.system(size: 26, weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(theme.primaryText)
                        .padding(.horizontal, 24)

                    if let scheduleTarget = entry.scheduleTargetLabel,
                       let scheduleWindow = entry.scheduleWindowLabel {
                        scheduleCard(target: scheduleTarget, window: scheduleWindow)
                    }

                    ingredientsSection

                    if !preparationSteps.isEmpty {
                        preparationSection
                    }

                    if isEditable {
                        shoppingListBar
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .processTransparentScrollSurface()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer", action: onDismiss)
                }
            }
            .onAppear {
                CoachPresentationTracker.shared.beginMealDetailPresentation()
            }
            .onDisappear {
                CoachPresentationTracker.shared.endMealDetailPresentation()
            }
        }
        .processAppPageBackground()
        .processAppPresentationBackground()
    }

    private var mealHeroHeader: some View {
        ZStack(alignment: .bottom) {
            Group {
                if ProcessAssetCatalog.contains(imageAsset) {
                    Image(imageAsset)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Circle()
                            .fill(theme.cardBackgroundStrong.opacity(theme.isDark ? 0.55 : 0.35))
                        Image(systemName: entry.slot.icon)
                            .font(.system(size: 40, weight: .semibold))
                            .foregroundStyle(theme.onboardingAccent.opacity(0.8))
                    }
                }
            }
            .frame(width: 152, height: 152)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .strokeBorder(Color.primary.opacity(theme.isDark ? 0.12 : 0.06), lineWidth: 0.5)
            }

            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.orange)
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
            .offset(y: 10)
        }
        .padding(.top, 8)
    }

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Ingrédients", systemImage: "leaf.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.secondaryText)

            VStack(spacing: 8) {
                ForEach(meal.items) { item in
                    MealSuggestionItemRow(
                        item: item,
                        theme: theme,
                        isExpanded: true,
                        isEditable: false,
                        onTap: {}
                    )
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(mealSurfaceCard)
    }

    private var preparationSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Préparation", systemImage: "list.number")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.secondaryText)

            VStack(spacing: 12) {
                ForEach(Array(preparationSteps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(theme.inverseText)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(theme.onboardingAccent))

                        Text(step)
                            .font(.subheadline)
                            .foregroundStyle(theme.primaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(mealSurfaceCard)
    }

    private var shoppingListBar: some View {
        Button {
            HapticManager.shared.impact(.medium)
            WelcomePlanStore.shared.addMealToShoppingList(meal, dayId: day.id)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "cart.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(theme.isDark ? Color.white.opacity(0.1) : Color.black.opacity(0.06))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Liste de courses")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Ajouter les ingrédients de ce repas")
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                }

                Spacer(minLength: 4)

                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.secondaryText)
            }
            .foregroundStyle(theme.primaryText.opacity(0.92))
            .padding(.leading, 14)
            .padding(.trailing, 16)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .processGlassEffect(in: Capsule(), interactive: true)
            .shadow(color: Color.black.opacity(theme.isDark ? 0.42 : 0.14), radius: 18, y: 10)
        }
        .buttonStyle(ProcessGlassPressStyle())
        .accessibilityLabel("Ajouter à la liste de courses")
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

    private var mealSurfaceCard: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(theme.isDark ? theme.cardBackgroundStrong : theme.coachUserBubble)
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(theme.cardStroke, lineWidth: theme.isDark ? 0 : 0.5)
            }
            .shadow(color: theme.primaryText.opacity(theme.isDark ? 0.12 : 0.04), radius: 10, y: 3)
    }
}
