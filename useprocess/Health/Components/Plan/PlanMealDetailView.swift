import SwiftUI

/// Page détail repas — graphique radial + macros.
struct PlanMealDetailView: View {
    let entry: PlanDayMealEntry
    var isEditable: Bool
    var onValidate: (() -> Void)?
    var onModify: (() -> Void)?
    var onDismiss: () -> Void

    @Environment(\.appTheme) private var theme

    private var meal: MealSuggestionContent { entry.meal }
    private var profile: MealNutritionProfile { MealNutritionCatalog.profile(for: meal) }
    private var imageAsset: String { MealNutritionCatalog.resolvedImageAsset(for: meal) }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    MealIngredientRadialChart(
                        segments: MealNutritionCatalog.debloatChartSegments(for: profile),
                        imageAssetName: imageAsset
                    )
                    .padding(.top, 8)

                    Text(meal.name)
                        .font(.system(size: 26, weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(theme.primaryText)
                        .padding(.horizontal, 24)

                    caloriesCard

                    nutrientGrid

                    if !meal.prepSummary.isEmpty {
                        infoBlock(title: "Préparation", body: meal.prepSummary, icon: "timer")
                    }

                    if isEditable {
                        actionButtons
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .background(theme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer", action: onDismiss)
                }
                if entry.isValidated {
                    ToolbarItem(placement: .primaryAction) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
        }
    }

    private var caloriesCard: some View {
        HStack(spacing: 14) {
            Text("🔥")
                .font(.system(size: 28))
            VStack(alignment: .leading, spacing: 2) {
                Text("Calories")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.secondaryText)
                Text("\(profile.calories)")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(theme.primaryText)
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(mealSurfaceCard)
    }

    private var nutrientGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ],
            spacing: 12
        ) {
            nutrientTile(emoji: "🥚", label: "Protéines", value: profile.proteinG, unit: "g")
            nutrientTile(emoji: "🍞", label: "Glucides", value: profile.carbsG, unit: "g")
            nutrientTile(emoji: "🥑", label: "Lipides", value: profile.fatsG, unit: "g")
            nutrientTile(emoji: "🍎", label: "Fibres", value: profile.fiberG, unit: "g")
            nutrientTile(emoji: "🥝", label: "Potassium", value: profile.potassiumMg, unit: "mg")
            debloatRatioTile
        }
    }

    private var debloatRatioTile: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("⚖️").font(.system(size: 18))
                Text("K / Na")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(1)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(formatted(profile.potassiumSodiumRatio))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(theme.primaryText)
                    .monospacedDigit()
                Text(": 1")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .background(mealSurfaceCard)
    }

    private func nutrientTile(emoji: String, label: String, value: Double, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(emoji).font(.system(size: 18))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(formatted(value))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(theme.primaryText)
                    .monospacedDigit()
                Text(unit)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .background(mealSurfaceCard)
    }

    private func infoBlock(title: String, body: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.secondaryText)
            Text(body)
                .font(.subheadline)
                .foregroundStyle(theme.primaryText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(mealSurfaceCard)
    }

    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: 10) {
            if let onValidate, !entry.isValidated {
                Button(action: onValidate) {
                    Text("Valider ce repas")
                        .font(.headline)
                        .foregroundStyle(theme.inverseText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(theme.inverseBackground, in: Capsule())
                }
                .buttonStyle(.plain)
            }

            if let onModify {
                Button(action: onModify) {
                    Text("Ajuster le repas")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(theme.cardBackgroundStrong)
                                .overlay {
                                    Capsule()
                                        .strokeBorder(theme.cardStroke, lineWidth: theme.isDark ? 0 : 0.5)
                                }
                        )
                }
                .buttonStyle(.plain)
            }
        }
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

    private func formatted(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}
