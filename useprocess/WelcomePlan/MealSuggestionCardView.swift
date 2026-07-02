import SwiftUI
import UIKit

// MARK: - Carte repas structurée

struct MealSuggestionCardView: View {
    let content: MealSuggestionContent
    var mealScheduleTarget: String?
    var mealScheduleWindow: String?
    var isValidated: Bool = false
    var showsActions: Bool = true
    var showsScoreBreakdown: Bool = true
    var revealedActionIDs: Set<String> = []
    var onValidate: (() -> Void)?
    var onModify: (() -> Void)?
    var onAnother: (() -> Void)?
    var onAddToShoppingList: (() -> Void)?
    var onEditItem: ((MealSuggestionItem) -> Void)?

    @Environment(\.appTheme) private var theme
    @State private var showsIngredients = false

    private let answerShape = Capsule()
    private var debloatAssessment: MealDebloatAssessment {
        MealNutritionCatalog.debloatAssessment(for: content)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerRow
            mealImage
            scoreRow
            if showsScoreBreakdown {
                MealDebloatScoreBreakdownView(
                    assessment: debloatAssessment,
                    compact: true
                )
            }
            if !content.tags.isEmpty { tagsRow }
            itemsSection
            prepRow
            if !content.coachTip.isEmpty { coachTipRow }

            if showsActions {
                actionButtons
            }
        }
        .padding(14)
        .background(cardBackground)
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: showsIngredients)
    }

    // MARK: - Sections

    @ViewBuilder
    private var mealImage: some View {
        let imageAssetName = resolvedMealImageAssetName
        if ProcessAssetCatalog.contains(imageAssetName) {
            OptionalAssetImage(
                name: imageAssetName,
                contentMode: .fit,
                height: 180
            )
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(theme.cardBackground.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var resolvedMealImageAssetName: String {
        MealNutritionCatalog.resolvedImageAsset(for: content)
    }

    private var headerRow: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(content.mealType.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(theme.onboardingAccent)
                    .tracking(0.6)

                if let mealScheduleTarget {
                    HStack(spacing: 6) {
                        Text(mealScheduleTarget)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(theme.onboardingAccent)
                            .monospacedDigit()

                        if let mealScheduleWindow {
                            Text(mealScheduleWindow)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(theme.secondaryText)
                        }
                    }
                }

                Text(content.name)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if isValidated {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                    .accessibilityLabel("Repas validé")
            }
        }
    }

    private var scoreRow: some View {
        HStack(spacing: 12) {
            MealProtocolScoreRing(score: debloatAssessment.score, theme: theme)

            VStack(alignment: .leading, spacing: 4) {
                Text("Score Debloat")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
                Text(debloatAssessment.summary)
                    .font(.caption)
                    .foregroundStyle(theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardBackground.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var tagsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(content.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(theme.onboardingAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(theme.onboardingAccent.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
        }
    }

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Composition")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
                    .textCase(.uppercase)
                Spacer()
                Button {
                    HapticManager.shared.selection()
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        showsIngredients.toggle()
                    }
                } label: {
                    Label(
                        showsIngredients ? "Masquer" : "Voir ingrédients",
                        systemImage: showsIngredients ? "chevron.up" : "list.bullet"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.onboardingAccent)
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 8) {
                ForEach(content.items) { item in
                    MealSuggestionItemRow(
                        item: item,
                        theme: theme,
                        isExpanded: showsIngredients,
                        isEditable: onEditItem != nil
                    ) {
                        onEditItem?(item)
                    }
                }
            }
        }
    }

    private var prepRow: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "timer")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.onboardingAccent)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(content.prepMinutes) min")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.primaryText)
                if !content.prepSummary.isEmpty {
                    Text(content.prepSummary)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var coachTipRow: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.caption.weight(.bold))
                .foregroundStyle(.orange)
                .padding(.top, 2)
            Text(content.coachTip)
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(theme.isDark ? 0.12 : 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private var actionButtons: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let onAddToShoppingList {
                mealActionButton("Ajouter à la liste courses", id: "shopping", action: onAddToShoppingList)
            }
            if let onValidate {
                mealActionButton("Valider le repas", id: "validate", primary: true, action: onValidate)
            }
            if let onModify {
                mealActionButton("Ajuster le repas", id: "modify", action: onModify)
            }
            if let onAnother {
                mealActionButton("Autre idée", id: "another", action: onAnother)
            }
        }
        .padding(.top, 2)
    }

    private func mealActionButton(
        _ title: String,
        id: String,
        primary: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticManager.shared.selection()
            action()
        } label: {
            Text(title)
                .font(.system(
                    size: OnboardingProfileChatDepthStyle.answerFontSize,
                    weight: primary ? .bold : .semibold
                ))
                .foregroundStyle(primary ? OnboardingTheme.actionButtonText : OnboardingTheme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .contentShape(answerShape)
        }
        .processGlassButton(in: answerShape)
        .onboardingChatAnswerReveal(isRevealed: revealedActionIDs.isEmpty || revealedActionIDs.contains(id))
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(theme.coachAssistantBubble)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(theme.cardStroke.opacity(0.35), lineWidth: 0.5)
            }
    }

}

// MARK: - Score ring

struct MealProtocolScoreRing: View {
    let score: Int
    var theme: AppTheme

    private var scoreColor: Color {
        switch score {
        case 85...: return .green
        case 70..<85: return theme.onboardingAccent
        case 50..<70: return .orange
        default: return .red.opacity(0.85)
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(theme.cardStroke.opacity(0.35), lineWidth: 5)
            Circle()
                .trim(from: 0, to: CGFloat(score) / 100)
                .stroke(scoreColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))

            VStack(spacing: 0) {
                Text("\(score)")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(theme.primaryText)
                    .monospacedDigit()
                Text("/100")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .frame(width: 54, height: 54)
        .accessibilityLabel("Score Debloat \(score) sur 100")
    }
}

// MARK: - Ligne ingrédient

struct MealSuggestionItemRow: View {
    let item: MealSuggestionItem
    var theme: AppTheme
    var isExpanded: Bool
    var isEditable: Bool
    var onTap: () -> Void

    var body: some View {
        Button {
            guard isEditable else { return }
            HapticManager.shared.selection()
            onTap()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: item.roleIcon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.onboardingAccent)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.primaryText)
                    if isExpanded {
                        Text(item.ingredientDisplayLine)
                            .font(.caption)
                            .foregroundStyle(theme.secondaryText)
                    }
                }

                Spacer(minLength: 0)

                if isEditable {
                    Image(systemName: "pencil.circle.fill")
                        .font(.body)
                        .foregroundStyle(theme.secondaryText.opacity(0.7))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(theme.cardBackground.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEditable)
    }
}

// MARK: - Sheet modification ingrédient

struct MealItemEditSheet: View {
    let item: MealSuggestionItem
    let mealName: String
    var alternatives: [String] = []
    var isLoadingAlternatives: Bool = false
    var onApply: (String) -> Void
    var onSelectAlternative: ((String) -> Void)?
    var onDismiss: () -> Void

    @Environment(\.appTheme) private var theme
    @State private var instruction = ""
    @FocusState private var isFocused: Bool

    private let quickSwaps = [
        "Remplacer par une autre protéine",
        "Portion plus légère",
        "Portion plus généreuse",
        "Version végétarienne",
        "Sans gluten"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.name)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(theme.primaryText)
                        Text("\(item.quantity) · \(item.role)")
                            .font(.subheadline)
                            .foregroundStyle(theme.secondaryText)
                    }

                    if !alternatives.isEmpty || isLoadingAlternatives {
                        MealItemAlternativesBar(
                            alternatives: alternatives,
                            isLoading: isLoadingAlternatives,
                            onSelect: { alt in
                                if let onSelectAlternative {
                                    onSelectAlternative(alt)
                                } else {
                                    instruction = "Remplacer par \(alt)"
                                }
                            }
                        )
                    }

                    Text("Que veux-tu changer dans « \(item.name) » ?")
                        .font(.subheadline)
                        .foregroundStyle(theme.secondaryText)

                    VStack(spacing: 8) {
                        ForEach(quickSwaps, id: \.self) { swap in
                            Button {
                                HapticManager.shared.selection()
                                instruction = swap
                            } label: {
                                Text(swap)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(theme.primaryText)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(theme.cardBackground.opacity(0.6))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    TextField("Ou décris ta modification…", text: $instruction, axis: .vertical)
                        .lineLimit(2...4)
                        .focused($isFocused)
                        .padding(14)
                        .background(theme.cardBackground.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Button {
                        HapticManager.shared.impact(.medium)
                        let text = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !text.isEmpty else { return }
                        onApply(text)
                    } label: {
                        Text("Appliquer la modification")
                            .font(.headline)
                            .foregroundStyle(OnboardingTheme.actionButtonText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(theme.onboardingAccent, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                }
                .padding(20)
            }
            .processTransparentScrollSurface()
            .navigationTitle("Modifier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { onDismiss() }
                }
            }
            .onAppear { isFocused = true }
        }
        .processAppPageBackground()
        .processAppPresentationBackground()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Rendu coach (message assistant)

struct CoachMealSuggestionMessageView: View {
    let content: MealSuggestionContent
    var contextualActions: [CoachContextualAction] = []
    var onAction: ((CoachContextualAction) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            MealSuggestionCardView(
                content: content,
                showsActions: onAction != nil,
                showsScoreBreakdown: content.showsScore,
                onValidate: onAction.map { handler in
                    { handler(CoachContextualAction(kind: .validateMeal, payload: content.timeSlot.rawValue)) }
                },
                onModify: onAction.map { handler in
                    { handler(CoachContextualAction(kind: .modifyMeal, payload: content.timeSlot.rawValue)) }
                },
                onAnother: onAction.map { handler in
                    { handler(CoachContextualAction(kind: .anotherMeal, payload: content.timeSlot.rawValue)) }
                },
                onAddToShoppingList: onAction.map { handler in
                    { handler(CoachContextualAction(kind: .addToShoppingList, payload: content.timeSlot.rawValue)) }
                }
            )

            if let onAction, !contextualActions.isEmpty {
                CoachContextualActionButtons(actions: contextualActions, onAction: onAction)
            }
        }
    }
}

enum CoachMealMessageDetector {
    private static let mealKeywords = [
        "repas", "manger", "nutrition", "déjeuner", "dejeuner", "dîner", "diner",
        "petit-déjeuner", "petit dejeuner", "collation", "recette", "ingrédient",
        "propose", "idée de repas", "quoi manger", "menu"
    ]

    static func isMealRelated(userText: String) -> Bool {
        let lower = userText.lowercased()
        return mealKeywords.contains { lower.contains($0) }
    }

    static func mealContent(from assistantText: String) -> MealSuggestionContent? {
        MealSuggestionParser.parse(assistantText)
    }
}
