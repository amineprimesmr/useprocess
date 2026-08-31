import Foundation

struct ProfileSummaryItem: Identifiable, Hashable {
    let id: String
    let label: String
    let value: String?
    var isEditable: Bool = false

    @MainActor
    var displayValue: String {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return AppCopy.t("Non renseigné", en: "Not provided")
        }
        return value
    }

    var isPlaceholder: Bool {
        value == nil || value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true
    }
}

struct ProfileSummarySection: Identifiable, Hashable {
    let id: String
    let title: String
    let rows: [ProfileSummaryItem]
}

