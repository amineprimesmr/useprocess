import SwiftUI

/// Sheet simple pour corriger / ajouter un aliment du scan repas.
struct MealScanCompositionEditSheet: View {
    enum Mode: Equatable {
        case edit(foodIndex: Int)
        case add
    }

    let mode: Mode
    let initialName: String
    let initialQuantity: String
    let initialRole: String
    let onSave: (_ name: String, _ quantity: String, _ role: String) -> Void
    let onDelete: (() -> Void)?
    let onDismiss: () -> Void

    @State private var name: String = ""
    @State private var quantity: String = ""
    @State private var role: String = "Autre"
    @FocusState private var focusedField: Field?

    private enum Field { case name, quantity }

    private static let roles = ["Protéine", "Glucide", "Légume", "Gras", "Autre"]

    private var title: String {
        switch mode {
        case .edit:
            return AppCopy.t("Modifier l’aliment", en: "Edit food")
        case .add:
            return AppCopy.t("Ajouter un aliment", en: "Add a food")
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(AppCopy.t("Aliment", en: "Food"), text: $name)
                        .focused($focusedField, equals: .name)
                        .textInputAutocapitalization(.sentences)

                    TextField(AppCopy.t("Quantité (optionnel)", en: "Quantity (optional)"), text: $quantity)
                        .focused($focusedField, equals: .quantity)
                        .textInputAutocapitalization(.never)

                    Picker(AppCopy.t("Type", en: "Type"), selection: $role) {
                        ForEach(Self.roles, id: \.self) { option in
                            Text(localizedRole(option)).tag(option)
                        }
                    }
                }

                if case .edit = mode, let onDelete {
                    Section {
                        Button(role: .destructive) {
                            HapticManager.shared.notification(.warning)
                            onDelete()
                        } label: {
                            Text(AppCopy.t("Supprimer cet aliment", en: "Remove this food"))
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppCopy.cancel, action: onDismiss)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppCopy.t("OK", en: "OK")) {
                        guard canSave else { return }
                        HapticManager.shared.impact(.light)
                        onSave(name, quantity, role)
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
            .onAppear {
                name = initialName
                quantity = initialQuantity == "—" ? "" : initialQuantity
                role = Self.roles.contains(initialRole) ? initialRole : "Autre"
                focusedField = .name
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func localizedRole(_ role: String) -> String {
        switch role {
        case "Protéine": return AppCopy.t("Protéine", en: "Protein")
        case "Glucide": return AppCopy.t("Glucide", en: "Carb")
        case "Légume": return AppCopy.t("Légume", en: "Vegetable")
        case "Gras": return AppCopy.t("Gras", en: "Fat")
        default: return AppCopy.t("Autre", en: "Other")
        }
    }
}
