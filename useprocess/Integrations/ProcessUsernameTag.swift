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
            throw ProcessUsernameError.invalid(
                AppCopy.tSync("Minimum \(minLength) caractères.", en: "Minimum \(minLength) characters.")
            )
        }
        guard tag.count <= maxLength else {
            throw ProcessUsernameError.invalid(
                AppCopy.tSync("Maximum \(maxLength) caractères.", en: "Maximum \(maxLength) characters.")
            )
        }
        guard let first = tag.first, first.isLetter || first.isNumber else {
            throw ProcessUsernameError.invalid(
                AppCopy.tSync(
                    "Doit commencer par une lettre ou un chiffre.",
                    en: "Must start with a letter or number."
                )
            )
        }
        guard tag.contains(where: \.isLetter) else {
            throw ProcessUsernameError.invalid(
                AppCopy.tSync(
                    "Doit contenir au moins une lettre.",
                    en: "Must contain at least one letter."
                )
            )
        }
        guard !reserved.contains(tag) else {
            throw ProcessUsernameError.invalid(
                AppCopy.tSync("Ce tag est réservé.", en: "This tag is reserved.")
            )
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
            return AppCopy.tSync("Ce tag est déjà pris.", en: "This tag is already taken.")
        case .notFound:
            return AppCopy.tSync("Aucun utilisateur avec ce tag.", en: "No user found with this tag.")
        case .notAuthenticated:
            return AppCopy.tSync(
                "Connecte-toi pour enregistrer ton tag.",
                en: "Sign in to save your tag."
            )
        case .cloudUnavailable(let message):
            return message
        }
    }
}
