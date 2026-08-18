import Foundation

/// Langues produit (app + widgets + site). Persistance : `process.app.language`.
enum ProcessLanguageCode: String, CaseIterable, Identifiable, Sendable {
    case french = "fr"
    case english = "en"
    case japanese = "ja"
    case german = "de"
    case korean = "ko"
    case spanish = "es"
    case portugueseBrazil = "pt-BR"

    var id: String { rawValue }

    /// Nom natif — ne pas traduire via AppCopy.
    var displayName: String {
        switch self {
        case .french: return "Français"
        case .english: return "English"
        case .japanese: return "日本語"
        case .german: return "Deutsch"
        case .korean: return "한국어"
        case .spanish: return "Español"
        case .portugueseBrazil: return "Português (Brasil)"
        }
    }

    var flag: String {
        switch self {
        case .french: return "🇫🇷"
        case .english: return "🇺🇸"
        case .japanese: return "🇯🇵"
        case .german: return "🇩🇪"
        case .korean: return "🇰🇷"
        case .spanish: return "🇪🇸"
        case .portugueseBrazil: return "🇧🇷"
        }
    }

    var localeIdentifier: String {
        switch self {
        case .french: return "fr_FR"
        case .english: return "en_US"
        case .japanese: return "ja_JP"
        case .german: return "de_DE"
        case .korean: return "ko_KR"
        case .spanish: return "es_ES"
        case .portugueseBrazil: return "pt_BR"
        }
    }

    /// Storefront App Store / iTunes lookup.
    var appStoreCountry: String {
        switch self {
        case .french: return "fr"
        case .english: return "us"
        case .japanese: return "jp"
        case .german: return "de"
        case .korean: return "kr"
        case .spanish: return "es"
        case .portugueseBrazil: return "br"
        }
    }

    var htmlLang: String {
        switch self {
        case .french: return "fr"
        case .english: return "en-US"
        case .japanese: return "ja"
        case .german: return "de"
        case .korean: return "ko"
        case .spanish: return "es"
        case .portugueseBrazil: return "pt-BR"
        }
    }

    /// Consigne LLM : le coach / scan / repas doit répondre dans cette langue.
    var llmLanguageDirective: String {
        switch self {
        case .french:
            return "Français uniquement. Tutoiement. Pas d'anglais. Pas de markdown (** #)."
        case .english:
            return "American English only. Singular “you”. No French. No markdown (** #)."
        case .japanese:
            return "Reply entirely in Japanese (日本語). Polite です/ます. Never English or French. No markdown (** #)."
        case .german:
            return "Antworte ausschließlich auf Deutsch. Duzen. Kein Englisch, kein Französisch. Kein Markdown (** #)."
        case .korean:
            return "반드시 한국어로만 답하세요. 해요체. 영어/프랑스어 금지. 마크다운 금지 (** #)."
        case .spanish:
            return "Responde solo en español (tuteo, latinoamericano neutro, no vosotros). Nada de inglés ni francés. Sin markdown (** #)."
        case .portugueseBrazil:
            return "Responda somente em português brasileiro (você). Sem inglês nem francês. Sem markdown (** #)."
        }
    }

    static func resolveFromDevice(
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> ProcessLanguageCode {
        for tag in preferredLanguages {
            let lower = tag.lowercased().replacingOccurrences(of: "_", with: "-")
            if lower.hasPrefix("fr") { return .french }
            if lower.hasPrefix("ja") { return .japanese }
            if lower.hasPrefix("de") { return .german }
            if lower.hasPrefix("ko") { return .korean }
            if lower.hasPrefix("pt") { return .portugueseBrazil }
            if lower.hasPrefix("es") { return .spanish }
            if lower.hasPrefix("en") { return .english }
        }
        return .english
    }

    static func normalize(_ raw: String) -> ProcessLanguageCode {
        let lower = raw.lowercased().replacingOccurrences(of: "_", with: "-")
        if lower.hasPrefix("fr") { return .french }
        if lower.hasPrefix("ja") { return .japanese }
        if lower.hasPrefix("de") { return .german }
        if lower.hasPrefix("ko") { return .korean }
        if lower.hasPrefix("pt") { return .portugueseBrazil }
        if lower.hasPrefix("es") { return .spanish }
        if lower.hasPrefix("en") { return .english }
        return .english
    }
}
