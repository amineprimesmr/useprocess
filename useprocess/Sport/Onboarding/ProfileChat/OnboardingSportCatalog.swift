//
//  OnboardingSportCatalog.swift
//  useprocess
//

import Foundation

enum OnboardingSportCatalog {
    static let featuredChoices: [OnboardingProfileChatChoice] = [
        .init(id: "Course à pied", label: "Course à pied", emoji: "🏃‍♂️"),
        .init(id: "Musculation", label: "Musculation", emoji: "🏋️‍♂️"),
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
            "🏋️‍♂️ Musculation", "🏋️‍♀️ CrossFit", "🏋️‍♂️ Powerlifting", "💪 Fitness"
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
}
