//
//  LanguageSelectorView.swift
//  Process
//
//  Sélecteur de langue — FR / EN / JA / DE / KO / ES / PT-BR.
//  Bouton glass + popover (pas un Menu, pas un sheet) : Menu + buttonStyle(.glass)
//  n’affichait que FR/EN sur iOS 26.
//

import SwiftUI

struct LanguageSelectorView: View {
    @EnvironmentObject var profileService: UnifiedProfileService
    @Bindable private var appLanguage = ProcessAppLanguage.shared
    @State private var showsMenu = false

    var body: some View {
        Button {
            HapticManager.shared.selection()
            showsMenu = true
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
        .popover(isPresented: $showsMenu, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
            languageMenu
                .presentationCompactAdaptation(.popover)
        }
        .onAppear {
            syncLanguageFromProfileIfNeeded()
        }
    }

    private var languageMenu: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(ProcessLanguageCode.allCases) { language in
                languageMenuRow(language)
            }
        }
        .padding(.vertical, 6)
        .frame(minWidth: 248, alignment: .leading)
        .modifier(LanguageMenuGlassModifier())
    }

    private func languageMenuRow(_ language: ProcessLanguageCode) -> some View {
        let isActive = appLanguage.code == language
        return Button {
            HapticManager.shared.selection()
            Task {
                await applyLanguage(language)
                showsMenu = false
            }
        } label: {
            HStack(spacing: 12) {
                Text(language.flag)
                    .font(.system(size: 20))
                    .frame(width: 28, alignment: .center)
                Text(language.displayName)
                    .font(.system(size: 16, weight: .medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                if isActive {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.processPlain)
        .accessibilityAddTraits(isActive ? .isSelected : [])
        .accessibilityLabel("\(language.flag) \(language.displayName)")
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

private struct LanguageMenuGlassModifier: ViewModifier {
    private let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(ProcessGlass.regularSurface, in: shape)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
        }
    }
}
