import Foundation

struct ProcessPublicUserTag: Equatable, Sendable {
    let tag: String
    let userId: String
    let displayName: String

    var formattedTag: String { "@\(tag)" }
}

enum ProcessUsernameTag {
    static let minLength = 3
    static let maxLength = 24

    private static let reserved: Set<String> = [
        "process", "admin", "support", "help", "api", "www", "null", "user",
        "profil", "profile", "coach", "sante", "health", "system", "official",
        "moderator", "mod", "team", "staff", "root", "anonymous", "guest"
    ]

    static func normalize(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "." }
            .trimmingCharacters(in: CharacterSet(charactersIn: "._"))
    }

    static func validate(_ tag: String) throws {
        guard tag.count >= minLength else {
            throw ProcessUsernameError.invalid("Minimum \(minLength) caractères.")
        }
        guard tag.count <= maxLength else {
            throw ProcessUsernameError.invalid("Maximum \(maxLength) caractères.")
        }
        guard let first = tag.first, first.isLetter || first.isNumber else {
            throw ProcessUsernameError.invalid("Doit commencer par une lettre ou un chiffre.")
        }
        guard tag.contains(where: \.isLetter) else {
            throw ProcessUsernameError.invalid("Doit contenir au moins une lettre.")
        }
        guard !reserved.contains(tag) else {
            throw ProcessUsernameError.invalid("Ce tag est réservé.")
        }
    }

    static func display(_ raw: String?) -> String {
        let normalized = normalize(raw ?? "")
        return normalized.isEmpty ? "" : "@\(normalized)"
    }
}

enum ProcessUsernameError: LocalizedError, Equatable {
    case invalid(String)
    case taken
    case notFound
    case notAuthenticated
    case cloudUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .invalid(let message):
            return message
        case .taken:
            return "Ce tag est déjà pris."
        case .notFound:
            return "Aucun utilisateur avec ce tag."
        case .notAuthenticated:
            return "Connecte-toi pour enregistrer ton tag."
        case .cloudUnavailable(let message):
            return message
        }
    }
}
