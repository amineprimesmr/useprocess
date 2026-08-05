import Foundation

struct PlanHomeGreeting: Equatable {
    let line: String
}

/// Salutation accueil — « Salut {prénom} » / « Hi {name} ».
enum PlanHomeGreetingBuilder {
    @MainActor
    static func make(firstName: String) -> PlanHomeGreeting {
        .init(line: salut(firstName))
    }

    @MainActor
    private static func salut(_ firstName: String) -> String {
        let name = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return AppCopy.t("Salut", en: "Hi") }
        return AppCopy.t("Salut \(name)", en: "Hi \(name)")
    }
}
