//
//  OnboardingSportCatalog.swift
//  useprocess
//

import Foundation

enum OnboardingSportCatalog {
    static let featuredChoices: [OnboardingProfileChatChoice] = [
        .init(id: "Course à pied", label: "Course à pied", emoji: "🏃‍♂️"),
        .init(id: "Cyclisme", label: "Cyclisme", emoji: "🚴‍♂️"),
        .init(id: "Football", label: "Football", emoji: "⚽"),
        .init(id: "Boxe", label: "Boxe", emoji: "🥊"),
        .init(id: "Natation", label: "Natation", emoji: "🏊‍♂️")
    ]

    static let allSports: [String] = {
        var sports: [String] = []
        sports.append(contentsOf: [
            "🏃‍♂️ Course à pied", "🏃‍♀️ Running", "🏃‍♂️ Trail", "🏃‍♂️ Marathon",
            "🏃‍♂️ Semi-marathon", "🏃‍♂️ 10 km", "🏃‍♂️ 5 km", "🥇 Athlétisme"
        ])
        sports.append(contentsOf: [
            "🚴‍♂️ Cyclisme", "🚴‍♀️ Cyclisme sur route", "🚴‍♂️ VTT", "🚴‍♂️ BMX"
        ])
        sports.append(contentsOf: [
            "🏊‍♂️ Natation", "🤽 Water-polo", "🏄‍♂️ Surf", "🚣‍♂️ Aviron",
            "🏊‍♂️ Triathlon", "🏊‍♂️ Aquagym"
        ])
        sports.append(contentsOf: [
            "🏋️‍♀️ CrossFit", "💪 Fitness", "🤸‍♂️ HIIT"
        ])
        sports.append(contentsOf: [
            "🥊 Boxe", "🥋 Karaté", "🥋 Judo", "🥋 Taekwondo", "🥋 MMA", "🤺 Escrime"
        ])
        sports.append(contentsOf: [
            "⚽ Football", "🏀 Basketball", "🏐 Volleyball", "🏒 Hockey",
            "⚾ Baseball", "🤾 Handball", "🏉 Rugby"
        ])
        sports.append(contentsOf: [
            "🎾 Tennis", "🏓 Ping-pong", "🏸 Badminton", "🎾 Padel"
        ])
        sports.append(contentsOf: [
            "🏹 Tir à l'arc", "⛳ Golf", "🎯 Pétanque", "🎯 Bowling"
        ])
        sports.append(contentsOf: [
            "⛷️ Ski", "🏂 Snowboard", "⛸️ Patinage", "🧗 Escalade", "🏔️ Randonnée"
        ])
        sports.append(contentsOf: [
            "🤸‍♂️ Gymnastique", "🧘‍♂️ Yoga", "🧘‍♂️ Pilates", "💃 Danse", "💃 Zumba"
        ])
        sports.append(contentsOf: [
            "🏇 Equitation"
        ])
        return sports
    }()

    static func storedValue(label: String, emoji: String?) -> String {
        guard let emoji, !emoji.isEmpty else { return label }
        return "\(emoji) \(label)"
    }

    static func nameWithoutEmoji(_ sport: String) -> String {
        if let spaceIndex = sport.firstIndex(of: " ") {
            return String(sport[sport.index(after: spaceIndex)...]).trimmingCharacters(in: .whitespaces)
        }
        return sport
    }

    static func emoji(from sport: String) -> String? {
        guard let spaceIndex = sport.firstIndex(of: " ") else { return nil }
        let emoji = String(sport[..<spaceIndex]).trimmingCharacters(in: .whitespaces)
        return emoji.isEmpty ? nil : emoji
    }

    static func search(_ query: String, limit: Int = 8) -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let queryLower = trimmed.lowercased().folding(options: .diacriticInsensitive, locale: .current)

        let matches = allSports.filter { sport in
            let sportLower = sport.lowercased().folding(options: .diacriticInsensitive, locale: .current)
            let nameLower = nameWithoutEmoji(sport).lowercased().folding(options: .diacriticInsensitive, locale: .current)
            return sportLower.contains(queryLower) || nameLower.contains(queryLower)
        }

        let sorted = matches.sorted { lhs, rhs in
            let left = nameWithoutEmoji(lhs).lowercased()
            let right = nameWithoutEmoji(rhs).lowercased()
            let leftStarts = left.hasPrefix(queryLower)
            let rightStarts = right.hasPrefix(queryLower)
            if leftStarts != rightStarts { return leftStarts }
            return left < right
        }

        return Array(sorted.prefix(limit))
    }

    @MainActor
    static func localizedName(_ stored: String) -> String {
        let name = nameWithoutEmoji(stored)
        let en = englishName(for: name)
        return AppCopy.t(name, en: en)
    }

    static func englishName(for frenchName: String) -> String {
        sportNamesFRToEN[frenchName] ?? frenchName
    }

    private static let sportNamesFRToEN: [String: String] = [
        "Course à pied": "Running",
        "Running": "Running",
        "Trail": "Trail",
        "Marathon": "Marathon",
        "Semi-marathon": "Half marathon",
        "10 km": "10K",
        "5 km": "5K",
        "Course d'orientation": "Orienteering",
        "Athlétisme": "Track and field",
        "Sprint": "Sprint",
        "Lancer": "Throws",
        "Saut en hauteur": "High jump",
        "Saut en longueur": "Long jump",
        "Saut à la perche": "Pole vault",
        "Triple saut": "Triple jump",
        "Lancer de poids": "Shot put",
        "Lancer de disque": "Discus",
        "Lancer de javelot": "Javelin",
        "Lancer de marteau": "Hammer throw",
        "Cyclisme": "Cycling",
        "Cyclisme sur route": "Road cycling",
        "VTT": "Mountain biking",
        "BMX": "BMX",
        "Vélo de route": "Road bike",
        "Cyclocross": "Cyclocross",
        "Vélo tout terrain": "Mountain bike",
        "Natation": "Swimming",
        "Natation synchronisée": "Artistic swimming",
        "Water-polo": "Water polo",
        "Surf": "Surfing",
        "Bodyboard": "Bodyboarding",
        "Stand up paddle": "Stand-up paddle",
        "Kitesurf": "Kitesurfing",
        "Windsurf": "Windsurfing",
        "Aviron": "Rowing",
        "Canoë-kayak": "Canoe-kayak",
        "Plongée": "Diving",
        "Aquagym": "Water aerobics",
        "Aquabike": "Aqua cycling",
        "Triathlon": "Triathlon",
        "Duathlon": "Duathlon",
        "Aquathlon": "Aquathlon",
        "CrossFit": "CrossFit",
        "Fitness": "Fitness",
        "HIIT": "HIIT",
        "Boxe": "Boxing",
        "Boxe anglaise": "Boxing",
        "Boxe française": "Savate",
        "Arts martiaux": "Martial arts",
        "Karaté": "Karate",
        "Judo": "Judo",
        "Taekwondo": "Taekwondo",
        "Jiu-jitsu": "Jiu-jitsu",
        "Aïkido": "Aikido",
        "Kung-fu": "Kung fu",
        "Muay-thaï": "Muay Thai",
        "MMA": "MMA",
        "Escrime": "Fencing",
        "Football": "Soccer",
        "Futsal": "Futsal",
        "Basketball": "Basketball",
        "Streetball": "Streetball",
        "Volleyball": "Volleyball",
        "Beach-volley": "Beach volleyball",
        "Hockey": "Hockey",
        "Hockey sur glace": "Ice hockey",
        "Hockey sur gazon": "Field hockey",
        "Baseball": "Baseball",
        "Softball": "Softball",
        "Handball": "Handball",
        "Rugby": "Rugby",
        "Rugby à XV": "Rugby union",
        "Rugby à XIII": "Rugby league",
        "Tennis": "Tennis",
        "Tennis de table": "Table tennis",
        "Ping-pong": "Table tennis",
        "Badminton": "Badminton",
        "Squash": "Squash",
        "Padel": "Padel",
        "Beach-tennis": "Beach tennis",
        "Tir à l'arc": "Archery",
        "Tir sportif": "Target shooting",
        "Golf": "Golf",
        "Billard": "Billiards",
        "Pétanque": "Pétanque",
        "Bowling": "Bowling",
        "Ski": "Skiing",
        "Ski alpin": "Alpine skiing",
        "Ski de fond": "Cross-country skiing",
        "Snowboard": "Snowboarding",
        "Patinage": "Ice skating",
        "Patinage artistique": "Figure skating",
        "Patinage de vitesse": "Speed skating",
        "Escalade": "Climbing",
        "Escalade en bloc": "Bouldering",
        "Escalade en salle": "Indoor climbing",
        "Randonnée": "Hiking",
        "Alpinisme": "Mountaineering",
        "Gymnastique": "Gymnastics",
        "Gymnastique artistique": "Artistic gymnastics",
        "Gymnastique rythmique": "Rhythmic gymnastics",
        "Gymnastique acrobatique": "Acrobatic gymnastics",
        "Yoga": "Yoga",
        "Pilates": "Pilates",
        "Danse": "Dance",
        "Zumba": "Zumba",
        "Equitation": "Horseback riding",
    ]
}
