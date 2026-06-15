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

    var description: String {
        switch self {
        case .runningRace:
            return "Marathon, semi-marathon, 10km..."
        case .cyclingRace:
            return "Course cycliste, critérium, randonnée..."
        case .swimmingCompetition:
            return "Compétition de natation, triathlon..."
        case .combat:
            return "Combat de boxe, MMA, arts martiaux..."
        case .tournament:
            return "Tournoi, championnat..."
        case .personalEvent:
            return "Mariage, vacances, événement spécial"
        case .specificDate:
            return "Une date précise en tête"
        case .noDeadline:
            return "Je veux juste progresser à mon rythme"
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

    var displayText: String {
        switch type {
        case .noDeadline:
            return "Pas de deadline"
        case .runningRace, .cyclingRace, .swimmingCompetition, .combat, .tournament, .personalEvent:
            if let detail = detail {
                return detail.rawValue
            }
            if let eventName = eventName, !eventName.isEmpty {
                return eventName
            }
            return type.rawValue
        case .specificDate:
            if let date = date {
                let formatter = DateFormatter()
                formatter.dateStyle = .long
                formatter.locale = Locale(identifier: "fr_FR")
                return formatter.string(from: date)
            }
            return "Date spécifique"
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
