//
//  ProcessMeasurementPreference.swift
//  Process
//
//  Unités par défaut selon le système de mesure du device (US → impérial).
//  Indépendant de la langue produit FR/EN (un US en FR doit quand même voir LBS/FT).
//

import Foundation

enum ProcessMeasurementPreference {
    /// `true` pour États-Unis (measurement system `.us`) → LBS / FT par défaut.
    static var prefersImperial: Bool {
        Locale.current.measurementSystem == .us
    }
}