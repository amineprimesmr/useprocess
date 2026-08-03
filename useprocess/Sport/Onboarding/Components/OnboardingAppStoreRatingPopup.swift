//
//  OnboardingAppStoreRatingPopup.swift
//  Process
//
//  Déclenche le popup natif Apple (StoreKit requestReview) — une seule fois.
//

import Foundation

enum OnboardingAppStoreRatingPrompt {
    private static let key = "onboarding.faceScan.appStoreRating.shown"

    static var hasBeenShown: Bool {
        UserDefaults.standard.bool(forKey: key)
    }

    static func markShown() {
        UserDefaults.standard.set(true, forKey: key)
    }
}
