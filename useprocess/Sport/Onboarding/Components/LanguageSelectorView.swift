//
//  LanguageSelectorView.swift
//  Process
//
//  Sélecteur de langue — FR / EN / JA / DE / KO / ES / PT-BR.
//  Bouton glass + sheet (pas un Menu) : le Menu + buttonStyle(.glass) n’affichait
//  que FR/EN sur iOS 26.
//

import SwiftUI

struct LanguageSelectorView: View {
    @EnvironmentObject var profileService: UnifiedProfileService
    @Bindable private var appLanguage = ProcessAppLanguage.shared
    @State private var showsPicker = false

    var body: some View {
        Button {
            HapticManager.shared.selection()
            showsPicker = true
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
        .accessibilityLabel(AppCopy.t("Choisir la langue", en: "Choose language"))
        .sheet(isPresented: $showsPicker) {
            languagePickerSheet
        }
        .onAppear {
            syncLanguageFromProfileIfNeeded()
        }
    }

    private var languagePickerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(ProcessLanguageCode.allCases) { language in
                        languageButton(language)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .navigationTitle(AppCopy.t("Langue", en: "Language"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppCopy.close) {
                        showsPicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
    }

    private func languageButton(_ language: ProcessLanguageCode) -> some View {
        let isActive = appLanguage.code == language
        return Button {
            HapticManager.shared.selection()
            Task {
                await applyLanguage(language)
                showsPicker = false
            }
        } label: {
            HStack(spacing: 14) {
                Text(language.flag)
                    .font(.system(size: 28))
                Text(language.displayName)
                    .font(.system(size: 18, weight: .semibold))
                Spacer(minLength: 0)
                if isActive {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .controlSize(.large)
        .processGlassButton(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private func syncLanguageFromProfileIfNeeded() {
        guard let profileLang = profileService.currentProfile?.preferences.language else { return }
        let normalized = ProcessAppLanguage.normalize(profileLang)
        if normalized != appLanguage.code {
            appLanguage.setLanguage(normalized)
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
