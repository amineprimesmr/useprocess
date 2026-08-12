import SwiftUI

struct ProcessToast: Identifiable, Hashable {
    var id: String = UUID().uuidString
    var symbol: String
    var title: String
    var description: String
    var tintColor: Color
    var autoDismissInterval: Double? = 3.5
}

@MainActor
@Observable
final class ProcessToastCenter {
    static let shared = ProcessToastCenter()

    var toasts: [ProcessToast] = []

    private init() {}

    func show(_ toast: ProcessToast) {
        withAnimation(.smooth(duration: 0.3)) {
            toasts.append(toast)
            if toasts.count > 3 {
                toasts.removeFirst(toasts.count - 3)
            }
        }
    }

    func show(
        _ title: String,
        en titleEN: String,
        description: String = "",
        en descriptionEN: String = "",
        symbol: String = "checkmark.circle.fill",
        tintColor: Color = Color(red: 0.22, green: 0.78, blue: 0.48),
        autoDismissInterval: Double? = 3.5
    ) {
        show(
            ProcessToast(
                symbol: symbol,
                title: AppCopy.t(title, en: titleEN),
                description: description.isEmpty ? "" : AppCopy.t(description, en: descriptionEN),
                tintColor: tintColor,
                autoDismissInterval: autoDismissInterval
            )
        )
    }

    func dismiss(id: String) {
        withAnimation(.smooth(duration: 0.28)) {
            toasts.removeAll { $0.id == id }
        }
    }
}
