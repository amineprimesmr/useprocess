import SwiftUI

// MARK: - Scores décomposés

struct MealScoreBreakdownView: View {
    let scores: MealSubScores
    var theme: AppTheme

    var body: some View {
        VStack(spacing: 10) {
            scoreBar(title: "Protocole Origine", value: scores.protocolFit, color: theme.onboardingAccent)
            scoreBar(title: "Satiété", value: scores.satiety, color: .green)
            scoreBar(title: "Anti-gonflement", value: scores.antiBloat, color: .orange)
        }
    }

    private func scoreBar(title: String, value: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
                Spacer()
                Text("\(value)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.primaryText)
                    .monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.cardStroke.opacity(0.25))
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(value) / 100)
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Timeline créneaux

struct MealTimelineTabs: View {
    @Binding var selected: MealTimeSlot
    var slots: [MealTimeSlot] = MealTimeSlot.allCases
    var validatedSlots: Set<MealTimeSlot>
    var theme: AppTheme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(slots) { slot in
                    Button {
                        HapticManager.shared.selection()
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                            selected = slot
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: slot.icon)
                                .font(.caption.weight(.bold))
                            Text(slot.rawValue)
                                .font(.caption.weight(.semibold))
                            if validatedSlots.contains(slot) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            }
                        }
                        .foregroundStyle(selected == slot ? theme.primaryText : theme.secondaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background {
                            Capsule()
                                .fill(selected == slot ? theme.onboardingAccent.opacity(0.18) : theme.cardBackground.opacity(0.4))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Historique carousel

struct MealHistoryCarouselView: View {
    let entries: [MealHistoryEntry]
    var theme: AppTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HealthHubDesign.sectionHeader("Repas récents", subtitle: "7 derniers jours", theme: theme)

            if entries.isEmpty {
                Text("Valide un repas pour alimenter ton historique.")
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(entries) { entry in
                            if let content = entry.content {
                                MealHistoryChip(entry: entry, content: content, theme: theme)
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HealthHubDesign.surfaceCard(theme: theme))
    }
}

private struct MealHistoryChip: View {
    let entry: MealHistoryEntry
    let content: MealSuggestionContent
    var theme: AppTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.mealSlot.rawValue)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(theme.onboardingAccent)
                Spacer()
                if content.showsScore {
                    Text("\(entry.protocolScore)")
                        .font(.caption.weight(.black))
                        .foregroundStyle(theme.primaryText)
                }
            }
            Text(content.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.primaryText)
                .lineLimit(2)
            Text(entry.validatedAt, style: .date)
                .font(.caption2)
                .foregroundStyle(theme.secondaryText)
        }
        .frame(width: 160, alignment: .leading)
        .padding(12)
        .background(theme.cardBackground.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Liste courses

struct MealShoppingListSection: View {
    let items: [MealShoppingItem]
    var theme: AppTheme
    var onToggle: (String) -> Void
    var onClearChecked: () -> Void

    private var activeCount: Int {
        items.filter { !$0.isChecked }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HealthHubDesign.sectionHeader("Liste courses", subtitle: "\(activeCount) articles", theme: theme)
                Spacer()
                if items.contains(where: \.isChecked) {
                    Button("Effacer cochés", action: onClearChecked)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.onboardingAccent)
                }
            }

            if items.isEmpty {
                Text("Ajoute un repas à ta liste depuis une carte repas.")
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
            } else {
                LazyVStack(spacing: 6) {
                    ForEach(items.prefix(20)) { item in
                        HStack(spacing: 10) {
                            Button {
                                onToggle(item.id)
                            } label: {
                                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(item.isChecked ? .green : theme.secondaryText)
                            }
                            .buttonStyle(.plain)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(item.isChecked ? theme.secondaryText : theme.primaryText)
                                    .strikethrough(item.isChecked)
                                Text(item.quantity)
                                    .font(.caption2)
                                    .foregroundStyle(theme.secondaryText)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HealthHubDesign.surfaceCard(theme: theme))
    }
}

// MARK: - Comparaison A vs B

struct MealComparisonSheet: View {
    let previous: MealSuggestionContent
    let candidate: MealSuggestionContent
    var onKeepPrevious: () -> Void
    var onChooseCandidate: () -> Void
    var onDismiss: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("Compare avant de valider")
                        .font(.headline)
                        .foregroundStyle(theme.primaryText)

                    HStack(alignment: .top, spacing: 10) {
                        compareColumn(title: "Actuel", meal: previous, accent: theme.secondaryText)
                        compareColumn(title: "Nouveau", meal: candidate, accent: theme.onboardingAccent)
                    }

                    VStack(spacing: 10) {
                        Button {
                            HapticManager.shared.impact(.medium)
                            onChooseCandidate()
                        } label: {
                            Text("Choisir le nouveau")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(theme.onboardingAccent, in: Capsule())
                                .foregroundStyle(OnboardingTheme.actionButtonText)
                        }
                        .buttonStyle(.plain)

                        Button {
                            HapticManager.shared.selection()
                            onKeepPrevious()
                        } label: {
                            Text("Garder l'actuel")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Comparaison")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { onDismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    private func compareColumn(title: String, meal: MealSuggestionContent, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(accent)
            Text(meal.name)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(theme.primaryText)
            if meal.showsScore {
                Text("\(meal.protocolScore)/100")
                    .font(.title3.weight(.black))
                    .foregroundStyle(theme.primaryText)
            }
            ForEach(meal.items.prefix(4)) { item in
                Text("• \(item.name)")
                    .font(.caption2)
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardBackground.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Mode rapide (stack swipe)

struct MealQuickPickStackView: View {
    let meals: [MealSuggestionContent]
    var onValidate: (MealSuggestionContent) -> Void
    var onDismiss: () -> Void

    @Environment(\.appTheme) private var theme
    @State private var index = 0
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Mode rapide")
                    .font(.headline)
                Spacer()
                Button("Fermer", action: onDismiss)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(theme.primaryText)

            if index >= meals.count {
                Text("Plus d'idées — relance une génération.")
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)
            } else {
                ZStack {
                    ForEach(Array(meals.enumerated().reversed()), id: \.offset) { i, meal in
                        if i >= index {
                            MealSuggestionCardView(content: meal, showsActions: false)
                                .scaleEffect(i == index ? 1 : 0.96)
                                .offset(y: CGFloat(i - index) * 8)
                                .offset(i == index ? dragOffset : .zero)
                                .rotationEffect(.degrees(i == index ? Double(dragOffset.width / 24) : 0))
                                .gesture(i == index ? dragGesture(for: meal) : nil)
                        }
                    }
                }

                HStack(spacing: 24) {
                    Label("Passer", systemImage: "xmark")
                        .foregroundStyle(.red.opacity(0.85))
                    Label("Valider", systemImage: "heart.fill")
                        .foregroundStyle(.green)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.secondaryText)
            }
        }
        .padding(14)
        .background(HealthHubDesign.softCard(theme: theme))
    }

    private func dragGesture(for meal: MealSuggestionContent) -> some Gesture {
        DragGesture()
            .onChanged { dragOffset = $0.translation }
            .onEnded { value in
                if value.translation.width > 100 {
                    HapticManager.shared.notification(.success)
                    onValidate(meal)
                    advance()
                } else if value.translation.width < -100 {
                    HapticManager.shared.selection()
                    advance()
                }
                dragOffset = .zero
            }
    }

    private func advance() {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            index += 1
        }
    }
}

// MARK: - Feedback post-repas

struct MealFeedbackSheet: View {
    let dayId: String
    let historyId: String?
    let mealName: String
    var onSubmit: () -> Void
    var onDismiss: () -> Void

    @Environment(\.appTheme) private var theme
    @State private var store = WelcomePlanStore.shared
    @State private var rating = 4
    @State private var feeling: MealFeeling = .ok
    @State private var note = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Comment tu te sens après « \(mealName) » ?")
                        .font(.headline)
                        .foregroundStyle(theme.primaryText)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Note")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.secondaryText)
                        HStack(spacing: 8) {
                            ForEach(1...5, id: \.self) { star in
                                Button {
                                    rating = star
                                } label: {
                                    Image(systemName: star <= rating ? "star.fill" : "star")
                                        .foregroundStyle(.orange)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ressenti")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.secondaryText)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(MealFeeling.allCases) { option in
                                Button {
                                    feeling = option
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: option.icon)
                                        Text(option.rawValue)
                                    }
                                    .font(.caption.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(feeling == option ? theme.onboardingAccent.opacity(0.2) : theme.cardBackground.opacity(0.5))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    TextField("Note optionnelle…", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                        .padding(12)
                        .background(theme.cardBackground.opacity(0.55))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Button {
                        store.saveMealFeedback(
                            dayId: dayId,
                            historyId: historyId,
                            rating: rating,
                            feeling: feeling,
                            note: note
                        )
                        HapticManager.shared.notification(.success)
                        onSubmit()
                    } label: {
                        Text("Enregistrer")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(theme.onboardingAccent, in: Capsule())
                            .foregroundStyle(OnboardingTheme.actionButtonText)
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Feedback repas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Plus tard") { onDismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Alternatives ingrédient (chips)

struct MealItemAlternativesBar: View {
    let alternatives: [String]
    var isLoading: Bool
    var onSelect: (String) -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Alternatives IA")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.secondaryText)

            if isLoading {
                ProgressView().controlSize(.small)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(alternatives, id: \.self) { alt in
                            Button {
                                HapticManager.shared.selection()
                                onSelect(alt)
                            } label: {
                                Text(alt)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(theme.onboardingAccent.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Photo frigo

struct MealPhotoScanSheet: View {
    var onCapture: (UIImage) -> Void
    var onCancel: () -> Void

    var body: some View {
        CoachChatCameraSheet(onCapture: onCapture, onCancel: onCancel)
    }
}
