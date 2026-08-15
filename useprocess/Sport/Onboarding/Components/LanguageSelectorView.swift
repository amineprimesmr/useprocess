//
//  LanguageSelectorView.swift
//  Process
//
//  Sélecteur de langue — FR / EN (piloté par ProcessAppLanguage).
//

import SwiftUI

// MARK: - Vue de sélection de langue
struct LanguageSelectorView: View {
    @EnvironmentObject var profileService: UnifiedProfileService
    @Bindable private var appLanguage = ProcessAppLanguage.shared

    var body: some View {
        Menu {
            ForEach(ProcessAppLanguage.Code.allCases) { language in
                Button(action: {
                    HapticManager.shared.selection()
                    Task {
                        await applyLanguage(language)
                    }
                }) {
                    Label {
                        Text(language.displayName)
                    } icon: {
                        Text(language.flag)
                    }
                }
            }
        } label: {
            Text(appLanguage.code.flag)
                .font(.system(size: 18))
                .frame(
                    width: OnboardingConstants.backButtonSize,
                    height: OnboardingConstants.backButtonSize
                )
                .contentShape(Circle())
        }
        .glassCircleStyle()
        .onAppear {
            if let profileLang = profileService.currentProfile?.preferences.language {
                let normalized = ProcessAppLanguage.normalize(profileLang)
                if normalized != appLanguage.code {
                    appLanguage.setLanguage(normalized)
                }
            }
        }
    }

    private func applyLanguage(_ language: ProcessAppLanguage.Code) async {
        appLanguage.setLanguage(language)

        guard let profile = profileService.currentProfile else { return }

        var preferences = profile.preferences
        preferences.language = language.rawValue

        do {
            try await profileService.updatePreferences(preferences)
        } catch {
            DebugLogger.error("\(error.localizedDescription)")
        }
    }
}
