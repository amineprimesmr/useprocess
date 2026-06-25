import SwiftUI

struct CoachProcessFileEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    let file: CoachProcessFile?
    var onSave: (String, String) -> Void

    @State private var title: String
    @State private var content: String

    init(file: CoachProcessFile?, onSave: @escaping (String, String) -> Void) {
        self.file = file
        self.onSave = onSave
        _title = State(initialValue: file?.title ?? "")
        _content = State(initialValue: file?.content ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Titre", text: $title)
                TextField("Contenu", text: $content, axis: .vertical)
                    .lineLimit(4...12)
            }
            .navigationTitle(file == nil ? "Nouveau fichier" : "Modifier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        onSave(title, content)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              || content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
