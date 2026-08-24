//
//  OnboardingSportCatalog.swift
//  useprocess
//
//  Localisation des noms de sports (Coach / profil). Plus de picker onboarding.
//

import Foundation

enum OnboardingSportCatalog {
    static func nameWithoutEmoji(_ sport: String) -> String {
        if let spaceIndex = sport.firstIndex(of: " ") {
            return String(sport[sport.index(after: spaceIndex)...]).trimmingCharacters(in: .whitespaces)
        }
        return sport
    }

    @MainActor
    static func localizedName(_ stored: String) -> String {
        let name = nameWithoutEmoji(stored)
        return AppCopy.t(name, en: englishName(for: name))
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
