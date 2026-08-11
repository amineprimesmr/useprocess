import Foundation

/// Deep links hydratation (Live Activity bouton +500 / ouverture outil).
enum ProcessHydrationDeepLink {
    static let scheme = "process"
    static let host = "hydration"

    static var openURL: URL {
        URL(string: "\(scheme)://\(host)/open")!
    }

    static func sipURL(milliliters: Int) -> URL {
        URL(string: "\(scheme)://\(host)/sip?ml=\(milliliters)")!
    }

    static func parse(_ url: URL) -> ProcessHydrationDeepLinkAction? {
        guard url.scheme == scheme, url.host == host else { return nil }
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        switch path {
        case "sip":
            let ml = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "ml" })?
                .value
                .flatMap(Int.init) ?? 500
            return .sip(milliliters: max(50, ml))
        case "open", "":
            return .open
        default:
            return .open
        }
    }
}

enum ProcessHydrationDeepLinkAction: Equatable {
    case open
    case sip(milliliters: Int)
}
