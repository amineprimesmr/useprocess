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

    @MainActor static var categories: [ProfileInterestCategory] {
        [
            category("animaux", "Animaux", "Animals", [("🐱", "Chats", "Cats"), ("🐶", "Chiens", "Dogs"), ("🐴", "Chevaux", "Horses"), ("🐠", "Poissons", "Fish"), ("🐰", "Lapins", "Rabbits"), ("🐹", "Rongeurs", "Rodents"), ("🦎", "Reptiles", "Reptiles"), ("🐦", "Oiseaux", "Birds")]),
            category("arts", "Arts et Loisirs", "Arts & Hobbies", [("🎨", "Art", "Art"), ("📚", "Collection De Livres", "Book Collecting"), ("💃", "Danse", "Dance"), ("🎸", "Guitare", "Guitar"), ("🎹", "Piano", "Piano"), ("🎻", "Instrument De Musique", "Musical Instruments"), ("🎤", "K-Pop", "K-Pop"), ("🧱", "Légos", "Legos"), ("🎭", "Musique Et Arts", "Music & Arts"), ("🎬", "Théâtre", "Theater")]),
            category("autre", "Autre", "Other", [("🎯", "Chasse", "Hunting"), ("📈", "Investissement", "Investing")]),
            category("media", "Divertissement et Médias", "Entertainment & Media", [("🎌", "Anime", "Anime"), ("🍿", "Cinéma", "Movies"), ("🎞️", "Critiques De Films", "Movie Reviews"), ("🎥", "Films", "Films"), ("☕️", "Gilmore Girls", "Gilmore Girls"), ("🌸", "Ginny Et Georgia", "Ginny & Georgia"), ("👠", "Gossip Girl", "Gossip Girl"), ("🏥", "Grey's Anatomy", "Grey's Anatomy"), ("🏝️", "Love Island", "Love Island"), ("🦸", "Marvel", "Marvel"), ("😂", "Mèmes", "Memes"), ("📺", "Netflix", "Netflix"), ("🌊", "Outer Banks", "Outer Banks"), ("🦑", "Squid Game", "Squid Game"), ("🔦", "Stranger Things", "Stranger Things"), ("👻", "Supernatural", "Supernatural"), ("📀", "Séries", "TV Shows"), ("🏢", "The Office", "The Office"), ("🚔", "The Rookie", "The Rookie"), ("☀️", "The Summer I Turned Pretty", "The Summer I Turned Pretty")]),
            category("food", "Nourriture et Boissons", "Food & Drinks", [("🍺", "Brassage De Bière", "Brewing"), ("☕️", "Café", "Coffee"), ("🧀", "Fabrication De Fromage", "Cheesemaking"), ("🍽️", "Manger", "Eating"), ("🍔", "Nourriture", "Food"), ("🥐", "Pâtisserie", "Baking")]),
            category("spiritual", "Spiritualité et Croyances", "Spirituality & Beliefs", [("🤔", "Agnosticisme", "Agnosticism"), ("⚛️", "Athéisme", "Atheism"), ("☸️", "Bouddhisme", "Buddhism"), ("✝️", "Christianisme", "Christianity"), ("☪️", "Islam", "Islam"), ("✡️", "Judaïsme", "Judaism"), ("🕉️", "Hindouisme", "Hinduism"), ("🔮", "Spiritualité", "Spirituality")]),
            category("sports", "Sports et Remise en forme", "Sports & Fitness", [("⚾️", "Baseball", "Baseball"), ("🏀", "Basketball", "Basketball"), ("💪", "Entraînement", "Working Out"), ("🧗", "Escalade", "Climbing"), ("⚽️", "Football", "Soccer"), ("🤸", "Gymnastique", "Gymnastics"), ("🏋️", "Haltérophilie", "Weightlifting"), ("🤼", "Lutte", "Wrestling"), ("📣", "Pom-Pom Girls", "Cheerleading"), ("⛷️", "Ski", "Skiing"), ("🥎", "Softball", "Softball"), ("🎾", "Tennis", "Tennis"), ("🏇", "Équitation", "Horseback Riding")]),
            category("vehicles", "Sports mécaniques et Véhicules", "Motorsports & Vehicles", [("🛣️", "Cours De Conduite", "Driving Lessons"), ("🏎️", "F1 / Formule 1", "F1 / Formula 1"), ("🏍️", "Motos", "Motorcycles"), ("📸", "Photographie Automobile", "Automotive Photography"), ("🏁", "Sports Mécaniques", "Motorsports"), ("🚗", "Voitures", "Cars")]),
            category("lifestyle", "Style de vie et Bien-être", "Lifestyle & Wellness", [("👯", "Amis", "Friends"), ("🧴", "Bronzage", "Tanning"), ("🌅", "Couchers De Soleil", "Sunsets"), ("👨‍👩‍👧‍👦", "Famille", "Family"), ("💄", "Maquillage", "Makeup"), ("🧘", "Méditation", "Meditation"), ("💅", "Ongles", "Nails"), ("🏖️", "Plage", "Beach"), ("🛍️", "Shopping", "Shopping"), ("✈️", "Voyages Et Tourisme", "Travel & Tourism"), ("🧘‍♀️", "Yoga", "Yoga"), ("☀️", "Été", "Summer")]),
            category("tech", "Technologie", "Technology", [("🎮", "Roblox", "Roblox"), ("💻", "Technologie", "Technology"), ("🤳", "Tiktok", "TikTok")])
        ]
    }

    @MainActor static var allInterests: [ProfileInterest] {
        categories.flatMap(\.interests)
    }

    @MainActor static func interest(id: String) -> ProfileInterest? {
        allInterests.first { $0.id == id }
    }

    @MainActor static func summary(for ids: [String]) -> String? {
        let titles = ids.compactMap { interest(id: $0)?.title }
        guard !titles.isEmpty else { return nil }
        return titles.joined(separator: ", ")
    }

    @MainActor
    private static func category(
        _ id: String,
        _ title: String,
        _ englishTitle: String,
        _ items: [(String, String, String)]
    ) -> ProfileInterestCategory {
        ProfileInterestCategory(
            id: id,
            title: AppCopy.t(title, en: englishTitle),
            interests: items.map { emoji, name, englishName in
                ProfileInterest(id: slug(name), emoji: emoji, title: AppCopy.t(name, en: englishName))
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
