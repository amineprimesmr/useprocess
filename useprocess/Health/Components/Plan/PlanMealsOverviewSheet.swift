import SwiftUI

/// Vue « Tout voir » — repas à venir, historique, liste de courses.
struct PlanMealsOverviewSheet: View {
    let plan: FaceOriginPlan
    var anchorDate: Date
    let mealZoomNamespace: Namespace.ID

    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var profileService: UnifiedProfileService

    @Bindable private var store = WelcomePlanStore.shared

    @State private var visibleDayCount = 5
    @State private var dayBundles: [PlanMealsDayBundle] = []
    @State private var selectedDetail: MealDetailSelection?
    @State private var showShoppingSheet = false

    private var livePlan: FaceOriginPlan { store.plan ?? plan }
    private var shoppingItems: [MealShoppingItem] {
        livePlan.progress.shoppingList
    }
    private var activeShoppingCount: Int {
        shoppingItems.filter { !$0.isChecked }.count
    }
    private var mealHistory: [MealHistoryEntry] {
        store.mealHistoryThisWeek()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    overviewHeader

                    if dayBundles.isEmpty {
                        emptyDaysCard
                    } else {
                        upcomingDaysSection
                    }

                    if !mealHistory.isEmpty {
                        MealHistoryCarouselView(entries: mealHistory, theme: theme)
                    }

                    shoppingPreviewSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
            .processTransparentScrollSurface()
            .navigationTitle("Repas & protocole")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                shoppingStickyBar
            }
            .task(id: anchorDate) {
                reloadBundles()
            }
            .onChange(of: store.plan?.lastUpdated) { _, _ in
                reloadBundles()
            }
            .fullScreenCover(item: $selectedDetail) { selection in
                PlanMealDetailView(
                    entry: refreshedEntry(selection.entry, day: selection.day),
                    plan: livePlan,
                    day: selection.day,
                    onDismiss: { selectedDetail = nil }
                )
                .environmentObject(profileService)
                .processZoomTransition(
                    id: .mealDetail(selection.entry.slot),
                    namespace: mealZoomNamespace
                )
            }
            .sheet(isPresented: $showShoppingSheet) {
                PlanMealsShoppingSheet(
                    items: shoppingItems,
                    onToggle: { id in
                        store.toggleShoppingItem(id)
                    },
                    onClearChecked: {
                        store.clearCheckedShoppingItems()
                    }
                )
            }
        }
        .processAppPageBackground()
        .processAppPresentationBackground()
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Sections

    private var overviewHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Planification repas")
                .font(.title3.weight(.bold))
                .foregroundStyle(theme.primaryText)

            Text("Les \(min(visibleDayCount, dayBundles.count)) prochains jours de ton protocole — valide, ajuste avec l’IA, puis gère ta liste de courses.")
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var upcomingDaysSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HealthHubDesign.sectionHeader(
                "À venir",
                subtitle: "\(dayBundles.count) jours dans le protocole",
                theme: theme
            )

            ForEach(Array(dayBundles.prefix(visibleDayCount))) { bundle in
                PlanMealsOverviewDayBlock(
                    bundle: bundle,
                    mealZoomNamespace: mealZoomNamespace,
                    onSelect: { entry in
                        selectedDetail = MealDetailSelection(
                            entry: entry,
                            day: bundle.day,
                            date: bundle.date
                        )
                    }
                )
            }

            if visibleDayCount < dayBundles.count {
                Button {
                    HapticManager.shared.impact(.light)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
                        visibleDayCount = min(visibleDayCount + 5, dayBundles.count)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.down.circle.fill")
                        Text("Afficher plus")
                            .font(.subheadline.weight(.semibold))
                        Text("(\(dayBundles.count - visibleDayCount) jours restants)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(theme.secondaryText)
                    }
                    .foregroundStyle(theme.onboardingAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(theme.onboardingAccent.opacity(theme.isDark ? 0.12 : 0.08))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var emptyDaysCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Aucun jour planifié")
                .font(.subheadline.weight(.semibold))
            Text("Cette date est hors calendrier Origine. Choisis un jour dans ton protocole sur l’accueil.")
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HealthHubDesign.softCard(theme: theme))
    }

    private var shoppingPreviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if shoppingItems.isEmpty {
                Text("Ta liste de courses se remplit quand tu ajoutes des ingrédients depuis un repas.")
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                MealShoppingListSection(
                    items: shoppingItems,
                    theme: theme,
                    maxVisibleItems: 8,
                    onToggle: { store.toggleShoppingItem($0) },
                    onClearChecked: { store.clearCheckedShoppingItems() }
                )
            }
        }
    }

    private var shoppingStickyBar: some View {
        Button {
            HapticManager.shared.impact(.medium)
            showShoppingSheet = true
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
                    Text(activeShoppingCount == 0
                         ? "Aucun article en attente"
                         : "\(activeShoppingCount) article\(activeShoppingCount > 1 ? "s" : "") à acheter")
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.up")
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
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
        .padding(.top, 6)
        .accessibilityLabel("Ouvrir la liste de courses")
    }

    // MARK: - Actions

    @MainActor
    private func reloadBundles() {
        dayBundles = PlanMealsOverviewProvider.loadDayBundles(
            plan: livePlan,
            from: anchorDate,
            store: store
        )
        visibleDayCount = min(max(visibleDayCount, 5), dayBundles.count)
    }

    private func isEditableDay(_ day: OriginProgramDay, date: Date) -> Bool {
        OriginPlanPresenter.journalDayAvailability(for: date, in: livePlan).isEditable
    }

    private func refreshedEntry(_ entry: PlanDayMealEntry, day: OriginProgramDay) -> PlanDayMealEntry {
        PlanDayMealsProvider.entries(plan: livePlan, day: day, store: store)
            .first(where: { $0.slot == entry.slot }) ?? entry
    }
}

// MARK: - Jour

private struct PlanMealsOverviewDayBlock: View {
    let bundle: PlanMealsDayBundle
    let mealZoomNamespace: Namespace.ID
    var onSelect: (PlanDayMealEntry) -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(PlanMealsOverviewProvider.dayTitle(for: bundle.date))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(theme.primaryText)
                    Text(PlanMealsOverviewProvider.daySubtitle(for: bundle.date, day: bundle.day))
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                }

                Spacer(minLength: 8)

                if bundle.validatedCount > 0 {
                    Text("\(bundle.validatedCount)/\(bundle.entries.count)")
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(theme.onboardingAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(theme.onboardingAccent.opacity(0.12), in: Capsule())
                }
            }

            VStack(spacing: 8) {
                ForEach(bundle.entries) { entry in
                    PlanMealsOverviewMealRow(
                        entry: entry,
                        mealZoomNamespace: mealZoomNamespace,
                        onTap: { onSelect(entry) }
                    )
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HealthHubDesign.softCard(theme: theme))
    }
}

private struct PlanMealsOverviewMealRow: View {
    let entry: PlanDayMealEntry
    let mealZoomNamespace: Namespace.ID
    var onTap: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                OptionalAssetImage(
                    name: entry.imageAssetName,
                    contentMode: .fill,
                    width: 52,
                    height: 52,
                    foregroundStyle: theme.secondaryText
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 5) {
                        Image(systemName: entry.slot.icon)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(theme.onboardingAccent)
                    }

                    Text(entry.meal.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.primaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 4)

                if entry.isValidated {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.secondaryText)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(theme.cardBackground.opacity(theme.isDark ? 0.35 : 0.55))
            )
        }
        .buttonStyle(.plain)
        .processZoomSource(id: .mealDetail(entry.slot), namespace: mealZoomNamespace)
    }
}

// MARK: - Liste courses plein écran

struct PlanMealsShoppingSheet: View {
    let items: [MealShoppingItem]
    var onToggle: (String) -> Void
    var onClearChecked: () -> Void

    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                MealShoppingListSection(
                    items: items,
                    theme: theme,
                    maxVisibleItems: nil,
                    onToggle: onToggle,
                    onClearChecked: onClearChecked
                )
                .padding(20)
            }
            .processTransparentScrollSurface()
            .navigationTitle("Liste de courses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
        .processAppPageBackground()
        .processAppPresentationBackground()
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Sélection détail

private struct MealDetailSelection: Identifiable {
    let entry: PlanDayMealEntry
    let day: OriginProgramDay
    let date: Date

    var id: String { "\(day.id)-\(entry.slot.rawValue)" }
}
