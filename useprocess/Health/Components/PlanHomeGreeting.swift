import Foundation

struct PlanHomeGreeting: Equatable {
    let line: String
}

/// Salutation accueil — « Salut {prénom} ».
enum PlanHomeGreetingBuilder {
    static func make(firstName: String) -> PlanHomeGreeting {
        .init(line: salut(firstName))
    }

    private static func salut(_ firstName: String) -> String {
        let name = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return "Salut" }
        return "Salut \(name)"
    }
}
