//
//  DeadlineModels.swift
//  Process
//
//  Modèles pour gérer les deadlines d'objectifs
//

import Foundation

/// Type de deadline/événement
enum DeadlineType: String, Codable, CaseIterable, Identifiable {
    case runningRace = "Course à pied"
    case cyclingRace = "Compétition de vélo"
    case swimmingCompetition = "Compétition de natation"
    case combat = "Combat/Match"
    case tournament = "Tournoi"
    case personalEvent = "Événement personnel"
    case specificDate = "Date spécifique"
    case noDeadline = "Pas de deadline"

    var id: String { rawValue }

    /// Détermine si ce type nécessite des détails supplémentaires
    var requiresDetails: Bool {
        switch self {
        case .runningRace, .cyclingRace, .swimmingCompetition, .combat, .tournament:
            return true
        default:
            return false
        }
    }

    var icon: String {
        switch self {
        case .runningRace:
            return "figure.run"
        case .cyclingRace:
            return "bicycle"
        case .swimmingCompetition:
            return "figure.pool.swim"
        case .combat:
            return "figure.boxing"
        case .tournament:
            return "trophy.fill"
        case .personalEvent:
            return "calendar"
        case .specificDate:
            return "calendar.badge.clock"
        case .noDeadline:
            return "infinity"
        }
    }

    @MainActor
    var localizedTitle: String {
        switch self {
        case .runningRace: return AppCopy.t("Course à pied", en: "Running race")
        case .cyclingRace: return AppCopy.t("Compétition de vélo", en: "Cycling race")
        case .swimmingCompetition: return AppCopy.t("Compétition de natation", en: "Swimming competition")
        case .combat: return AppCopy.t("Combat/Match", en: "Fight / Match")
        case .tournament: return AppCopy.t("Tournoi", en: "Tournament")
        case .personalEvent: return AppCopy.t("Événement personnel", en: "Personal event")
        case .specificDate: return AppCopy.t("Date spécifique", en: "Specific date")
        case .noDeadline: return AppCopy.t("Pas de deadline", en: "No deadline")
        }
    }

    @MainActor
    var description: String {
        switch self {
        case .runningRace:
            return AppCopy.t("Marathon, semi-marathon, 10km...", en: "Marathon, half marathon, 10k…")
        case .cyclingRace:
            return AppCopy.t(
                "Course cycliste, critérium, randonnée...",
                en: "Cycling race, criterium, ride…"
            )
        case .swimmingCompetition:
            return AppCopy.t(
                "Compétition de natation, triathlon...",
                en: "Swim meet, triathlon…"
            )
        case .combat:
            return AppCopy.t(
                "Combat de boxe, MMA, arts martiaux...",
                en: "Boxing, MMA, martial arts…"
            )
        case .tournament:
            return AppCopy.t("Tournoi, championnat...", en: "Tournament, championship…")
        case .personalEvent:
            return AppCopy.t(
                "Mariage, vacances, événement spécial",
                en: "Wedding, vacation, special event"
            )
        case .specificDate:
            return AppCopy.t("Une date précise en tête", en: "A specific date in mind")
        case .noDeadline:
            return AppCopy.t(
                "Je veux juste progresser à mon rythme",
                en: "I just want to progress at my own pace"
            )
        }
    }
}

/// Catégorie de détail de deadline
enum DeadlineDetailCategory: String, Codable {
    case running = "Course"
    case cycling = "Cyclisme"
    case swimming = "Natation"
    case combat = "Combat"
    case general = "Général"
}

/// Détails supplémentaires pour les deadlines sportives
enum DeadlineDetail: String, Codable, CaseIterable, Identifiable {
    // Course à pied
    case marathon = "Marathon (42,195 km)"
    case halfMarathon = "Semi-marathon (21,1 km)"
    case tenKm = "10 km"
    case fiveKm = "5 km"
    case trail = "Trail"
    case ultraMarathon = "Ultra-marathon"

    // Cyclisme
    case cyclingRace = "Course cycliste"
    case criterium = "Critérium"
    case granFondo = "Gran Fondo"
    case timeTrial = "Contre-la-montre"

    // Natation
    case swimmingCompetition = "Compétition de natation"
    case triathlon = "Triathlon"
    case openWater = "Natation en eau libre"

    // Combat
    case boxingMatch = "Combat de boxe"
    case mmaMatch = "Match de MMA"
    case judoTournament = "Tournoi de judo"
    case karateMatch = "Combat de karaté"
    case muayThai = "Combat de Muay Thai"
    case bjjCompetition = "Compétition de BJJ"

    // Tournoi général
    case championship = "Championnat"
    case tournament = "Tournoi"
    case league = "Championnat en ligue"

    var id: String { rawValue }

    /// Libellé UI — rawValue FR conservé pour la persistance.
    @MainActor
    var localizedTitle: String {
        switch self {
        case .marathon: return AppCopy.t("Marathon (42,195 km)", en: "Marathon (26.2 mi)")
        case .halfMarathon: return AppCopy.t("Semi-marathon (21,1 km)", en: "Half marathon (13.1 mi)")
        case .tenKm: return AppCopy.t("10 km", en: "10K")
        case .fiveKm: return AppCopy.t("5 km", en: "5K")
        case .trail: return AppCopy.t("Trail", en: "Trail")
        case .ultraMarathon: return AppCopy.t("Ultra-marathon", en: "Ultramarathon")
        case .cyclingRace: return AppCopy.t("Course cycliste", en: "Cycling race")
        case .criterium: return AppCopy.t("Critérium", en: "Criterium")
        case .granFondo: return AppCopy.t("Gran Fondo", en: "Gran Fondo")
        case .timeTrial: return AppCopy.t("Contre-la-montre", en: "Time trial")
        case .swimmingCompetition: return AppCopy.t("Compétition de natation", en: "Swim meet")
        case .triathlon: return AppCopy.t("Triathlon", en: "Triathlon")
        case .openWater: return AppCopy.t("Natation en eau libre", en: "Open-water swimming")
        case .boxingMatch: return AppCopy.t("Combat de boxe", en: "Boxing match")
        case .mmaMatch: return AppCopy.t("Match de MMA", en: "MMA fight")
        case .judoTournament: return AppCopy.t("Tournoi de judo", en: "Judo tournament")
        case .karateMatch: return AppCopy.t("Combat de karaté", en: "Karate match")
        case .muayThai: return AppCopy.t("Combat de Muay Thai", en: "Muay Thai fight")
        case .bjjCompetition: return AppCopy.t("Compétition de BJJ", en: "BJJ competition")
        case .championship: return AppCopy.t("Championnat", en: "Championship")
        case .tournament: return AppCopy.t("Tournoi", en: "Tournament")
        case .league: return AppCopy.t("Championnat en ligue", en: "League championship")
        }
    }

    var category: DeadlineDetailCategory {
        switch self {
        case .marathon, .halfMarathon, .tenKm, .fiveKm, .trail, .ultraMarathon:
            return .running
        case .cyclingRace, .criterium, .granFondo, .timeTrial:
            return .cycling
        case .swimmingCompetition, .triathlon, .openWater:
            return .swimming
        case .boxingMatch, .mmaMatch, .judoTournament, .karateMatch, .muayThai, .bjjCompetition:
            return .combat
        case .championship, .tournament, .league:
            return .general
        }
    }
}

/// Modèle de deadline complète
struct GoalDeadline: Codable, Equatable {
    var type: DeadlineType
    var date: Date?
    var eventName: String?
    var notes: String?
    var detail: DeadlineDetail?  // ✨ Détail spécifique (ex: marathon, combat MMA, etc.)

    var hasDeadline: Bool {
        return type != .noDeadline
    }

    @MainActor
    var displayText: String {
        switch type {
        case .noDeadline:
            return type.localizedTitle
        case .runningRace, .cyclingRace, .swimmingCompetition, .combat, .tournament, .personalEvent:
            if let detail = detail {
                return detail.localizedTitle
            }
            if let eventName = eventName, !eventName.isEmpty {
                return eventName
            }
            return type.localizedTitle
        case .specificDate:
            if let date = date {
                let formatter = DateFormatter()
                formatter.dateStyle = .long
                formatter.locale = ProcessAppLanguage.currentLocale
                return formatter.string(from: date)
            }
            return type.localizedTitle
        }
    }

    var daysRemaining: Int? {
        guard let date = date else { return nil }
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.day], from: now, to: date)
        return components.day
    }

    init(type: DeadlineType = .noDeadline, date: Date? = nil, eventName: String? = nil, notes: String? = nil, detail: DeadlineDetail? = nil) {
        self.type = type
        self.date = date
        self.eventName = eventName
        self.notes = notes
        self.detail = detail
    }
}
