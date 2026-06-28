import SwiftUI

/// Catalogue complet des repas debloat Process — parcourir toutes les recettes.
struct PlanMealIdeasCatalogSheet: View {
    let plan: FaceOriginPlan
    let day: OriginProgramDay
    var isEditable: Bool
    let mealZoomNamespace: Namespace.ID

    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var profileService: UnifiedProfileService

    @Bindable private var store = WelcomePlanStore.shared
    @State private var selectedEntry: PlanDayMealEntry?

    private var livePlan: FaceOriginPlan { store.plan ?? plan }
    private var sections: [ProcessDebloatMealLibrary.CatalogSection] {
        ProcessDebloatMealLibrary.catalogSections(for: livePlan.nutritionPlanType)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    catalogHeader

                    ForEach(sections) { section in
                        catalogSection(section)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .processTransparentScrollSurface()
            .navigationTitle("Repas debloat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .fullScreenCover(item: $selectedEntry) { entry in
                PlanMealDetailView(
                    entry: entry,
                    plan: livePlan,
                    day: day,
                    isEditable: isEditable,
                    onDismiss: { selectedEntry = nil }
                )
                .environmentObject(profileService)
                .processZoomTransition(id: .mealDetail(entry.slot), namespace: mealZoomNamespace)
            }
        }
        .processAppPageBackground()
        .processAppPresentationBackground()
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var catalogHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Catalogue debloat")
                .font(.title3.weight(.bold))
                .foregroundStyle(theme.primaryText)

            Text(
                "Tous nos repas debloat — ingrédients et préparation pour chaque recette. " +
                "Les suggestions du carousel changent chaque jour du protocole."
            )
            .font(.subheadline)
            .foregroundStyle(theme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func catalogSection(_ section: ProcessDebloatMealLibrary.CatalogSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(section.title)
                .font(.headline)
                .foregroundStyle(theme.primaryText)

            PlanMealCatalogCarousel(
                meals: section.meals,
                slot: section.slot,
                plan: livePlan,
                day: day,
                onOpen: { meal in
                    selectedEntry = PlanDayMealEntry.catalog(
                        meal: meal,
                        slot: section.slot,
                        plan: livePlan,
                        day: day
                    )
                }
            )
        }
    }
}
