import SwiftUI

struct CoachMyMemoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @Bindable private var store = CoachMyMemoryStore.shared

    @State private var selectedCategory: CoachMyMemoryCategory = .goals
    @State private var draftText = ""

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    toggleCard

                    addEntryCard

                    if store.entries.isEmpty {
                        Text("Ajoute ce que le coach doit retenir : objectifs, contraintes, préférences, événements.")
                            .font(.subheadline)
                            .foregroundStyle(theme.secondaryText)
                            .padding(.horizontal, 4)
                    } else {
                        entriesList
                    }
                }
                .padding(16)
            }
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Ma mémoire")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(theme.primaryText)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(theme.cardBackgroundStrong.opacity(0.95)))
                    }
                }
            }
        }
    }

    private var toggleCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Utiliser Ma mémoire")
                    .font(.body.weight(.medium))
                    .foregroundStyle(theme.primaryText)
                Text("Le coach s'appuie sur ces notes pour personnaliser ses réponses.")
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
            }
            Spacer()
            Toggle("", isOn: $store.isMemoryEnabled)
                .labelsHidden()
                .tint(.green)
        }
        .padding(16)
        .background(cardBackground)
    }

    private var addEntryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Catégorie", selection: $selectedCategory) {
                ForEach(CoachMyMemoryCategory.allCases) { category in
                    Text(category.label).tag(category)
                }
            }
            .pickerStyle(.menu)

            TextField(selectedCategory.placeholder, text: $draftText, axis: .vertical)
                .lineLimit(2...5)
                .textFieldStyle(.plain)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(theme.cardBackgroundStrong.opacity(0.65))
                )

            Button("Ajouter") {
                store.add(category: selectedCategory, text: draftText)
                draftText = ""
            }
            .font(.body.weight(.semibold))
            .foregroundStyle(theme.primaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(theme.cardBackgroundStrong.opacity(0.95))
            )
            .disabled(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(16)
        .background(cardBackground)
    }

    private var entriesList: some View {
        VStack(spacing: 10) {
            ForEach(store.entries) { entry in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(entry.category.label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.secondaryText)
                            .textCase(.uppercase)
                        Spacer()
                        Button(role: .destructive) {
                            store.delete(id: entry.id)
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 13))
                        }
                    }
                    Text(entry.text)
                        .font(.body)
                        .foregroundStyle(theme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .background(cardBackground)
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(theme.cardBackgroundStrong.opacity(theme.isDark ? 0.92 : 0.98))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(theme.secondaryText.opacity(0.12), lineWidth: 0.5)
            )
    }
}
