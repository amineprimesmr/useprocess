import Foundation

struct ProfileInterest: Hashable, Identifiable {
    let id: String
    let emoji: String
    let title: String

    var label: String { "\(emoji) \(title)" }
}

struct ProfileInterestCategory: Identifiable {
    let id: String
    let title: String
    let interests: [ProfileInterest]
}

enum ProfileInterestsCatalog {
    static let maxSelection = 10

    static let categories: [ProfileInterestCategory] = [
        category("animaux", "Animaux", [
            ("🐱", "Chats"), ("🐶", "Chiens"), ("🐴", "Chevaux"), ("🐠", "Poissons"),
            ("🐰", "Lapins"), ("🐹", "Rongeurs"), ("🦎", "Reptiles"), ("🐦", "Oiseaux")
        ]),
        category("arts", "Arts et Loisirs", [
            ("🎨", "Art"), ("📚", "Collection De Livres"), ("💃", "Danse"), ("🎸", "Guitare"),
            ("🎹", "Piano"), ("🎻", "Instrument De Musique"), ("🎤", "K-Pop"), ("🧱", "Légos"),
            ("🎭", "Musique Et Arts"), ("🎬", "Théâtre")
        ]),
        category("autre", "Autre", [
            ("🎯", "Chasse"), ("📈", "Investissement")
        ]),
        category("media", "Divertissement et Médias", [
            ("🎌", "Anime"), ("🍿", "Cinéma"), ("🎞️", "Critiques De Films"), ("🎥", "Films"),
            ("☕️", "Gilmore Girls"), ("🌸", "Ginny Et Georgia"), ("👠", "Gossip Girl"),
            ("🏥", "Grey's Anatomy"), ("🏝️", "Love Island"), ("🦸", "Marvel"), ("😂", "Mèmes"),
            ("📺", "Netflix"), ("🌊", "Outer Banks"), ("🦑", "Squid Game"), ("🔦", "Stranger Things"),
            ("👻", "Supernatural"), ("📀", "Séries"), ("🏢", "The Office"), ("🚔", "The Rookie"),
            ("☀️", "The Summer I Turned Pretty")
        ]),
        category("food", "Nourriture et Boissons", [
            ("🍺", "Brassage De Bière"), ("☕️", "Café"), ("🧀", "Fabrication De Fromage"),
            ("🍽️", "Manger"), ("🍔", "Nourriture"), ("🥐", "Pâtisserie")
        ]),
        category("spiritual", "Spiritualité et Croyances", [
            ("🤔", "Agnosticisme"), ("⚛️", "Athéisme"), ("☸️", "Bouddhisme"), ("✝️", "Christianisme"),
            ("☪️", "Islam"), ("✡️", "Judaïsme"), ("🕉️", "Hindouisme"), ("🔮", "Spiritualité")
        ]),
        category("sports", "Sports et Remise en forme", [
            ("⚾️", "Baseball"), ("🏀", "Basketball"), ("💪", "Entraînement"), ("🧗", "Escalade"),
            ("⚽️", "Football"), ("🤸", "Gymnastique"), ("🏋️", "Haltérophilie"), ("🤼", "Lutte"),
            ("📣", "Pom-Pom Girls"), ("⛷️", "Ski"), ("🥎", "Softball"), ("🎾", "Tennis"), ("🏇", "Équitation")
        ]),
        category("vehicles", "Sports mécaniques et Véhicules", [
            ("🛣️", "Cours De Conduite"), ("🏎️", "F1 / Formule 1"), ("🏍️", "Motos"),
            ("📸", "Photographie Automobile"), ("🏁", "Sports Mécaniques"), ("🚗", "Voitures")
        ]),
        category("lifestyle", "Style de vie et Bien-être", [
            ("👯", "Amis"), ("🧴", "Bronzage"), ("🌅", "Couchers De Soleil"), ("👨‍👩‍👧‍👦", "Famille"),
            ("💄", "Maquillage"), ("🧘", "Méditation"), ("💅", "Ongles"), ("🏖️", "Plage"),
            ("🛍️", "Shopping"), ("✈️", "Voyages Et Tourisme"), ("🧘‍♀️", "Yoga"), ("☀️", "Été")
        ]),
        category("tech", "Technologie", [
            ("🎮", "Roblox"), ("💻", "Technologie"), ("🤳", "Tiktok")
        ])
    ]

    static var allInterests: [ProfileInterest] {
        categories.flatMap(\.interests)
    }

    static func interest(id: String) -> ProfileInterest? {
        allInterests.first { $0.id == id }
    }

    static func summary(for ids: [String]) -> String? {
        let titles = ids.compactMap { interest(id: $0)?.title }
        guard !titles.isEmpty else { return nil }
        return titles.joined(separator: ", ")
    }

    private static func category(_ id: String, _ title: String, _ items: [(String, String)]) -> ProfileInterestCategory {
        ProfileInterestCategory(
            id: id,
            title: title,
            interests: items.map { emoji, name in
                ProfileInterest(id: slug(name), emoji: emoji, title: name)
            }
        )
    }

    private static func slug(_ title: String) -> String {
        title.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
    }
}
