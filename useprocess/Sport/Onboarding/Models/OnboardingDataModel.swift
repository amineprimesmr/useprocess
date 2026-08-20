//
//  OnboardingDataModel.swift
//  Process
//
//  Persistance légère des sports sélectionnés pendant l'onboarding (chat Moss).
//

import Combine
import Foundation

@MainActor
final class OnboardingDataModel: ObservableObject {
    static let shared = OnboardingDataModel()

    @Published var selectedSports: Set<String> = []

    private let userDefaults = UserDefaults.standard
    private let selectedSportsKey = "onboarding_selected_sports"

    private init() {
        loadSelectedSports()
    }

    private func loadSelectedSports() {
        if let saved = userDefaults.array(forKey: selectedSportsKey) as? [String], !saved.isEmpty {
            selectedSports = Set(saved)
        }
    }

    func persistSelectedSports() {
        userDefaults.set(Array(selectedSports), forKey: selectedSportsKey)
    }
}
