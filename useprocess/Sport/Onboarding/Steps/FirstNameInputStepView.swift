//
//  FirstNameInputStepView.swift
//  Process
//
//  Created by ENNASRI Amine on 22/09/2025.
//

import SwiftUI

struct FirstNameInputStepView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var profileService: UnifiedProfileService
    @Binding var firstName: String
    @State private var didBootstrap = false
    /// Évite de re-sauver le même prénom (changement de langue, aller-retour).
    @State private var lastCommittedName = ""
    @FocusState private var isTextFieldFocusedState: Bool

    // Callback pour passer à la page suivante
    var onComplete: (() -> Void)?

    // Callback pour notifier la validation
    var onValidationChanged: ((Bool) -> Void)?

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: OnboardingConstants.titleAreaHeight)

                Spacer()
                    .frame(height: OnboardingConstants.titleToContentSpacing + 72)

                TextField(
                    "",
                    text: $firstName,
                    prompt: Text(OnboardingCopy.t("Comment devons-nous t'appeler ?", en: "What should we call you?"))
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(OnboardingTheme.mutedText)
                )
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(OnboardingTheme.primaryText)
                .tint(OnboardingTheme.primaryText)
                .multilineTextAlignment(.center)
                .textFieldStyle(.plain)
                .focused($isTextFieldFocusedState)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled(true)
                .textContentType(.givenName)
                .submitLabel(.continue)
                .onSubmit {
                    let trimmed = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }

                    onComplete?()
                }
                .padding(.horizontal, 40)

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            bootstrapIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .inactive || phase == .background {
                isTextFieldFocusedState = false
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil,
                    from: nil,
                    for: nil
                )
            }
        }
        .onChange(of: firstName) { _, newValue in
            // Valider automatiquement quand le prénom est saisi
            let isValid = !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            onValidationChanged?(isValid)
        }
        .onDisappear {
            isTextFieldFocusedState = false
            commitFirstName()
        }
    }

    /// Sauvegarde unique, quel que soit le chemin de sortie (bouton CONTINUER global ou touche Retour).
    private func commitFirstName() {
        let trimmed = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard OnboardingViewModel.isRealUserFirstName(trimmed), trimmed != lastCommittedName else { return }
        lastCommittedName = trimmed
        ProcessAnalytics.trackFirstNameSet(trimmed, source: "onboarding_first_name_submit")
        Task.detached(priority: .background) {
            await saveFirstName()
        }
    }

    private func bootstrapIfNeeded() {
        guard !didBootstrap else { return }
        didBootstrap = true
        loadExistingFirstName()
        DispatchQueue.main.asyncAfter(deadline: .now() + OnboardingTransitionTiming.earlyKeyboardFocusDelay) {
            isTextFieldFocusedState = true
        }
    }

    private func loadExistingFirstName() {
        let trimmed = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        if OnboardingViewModel.isRealUserFirstName(trimmed) {
            onValidationChanged?(true)
            return
        }
        firstName = ""

        if let profile = profileService.currentProfile,
           OnboardingViewModel.isRealUserFirstName(profile.firstName) {
            firstName = profile.firstName
        } else if let user = AuthUser.current,
                  let displayName = user.displayName,
                  OnboardingViewModel.isRealUserFirstName(displayName) {
            firstName = displayName
        }
    }

    private func saveFirstName() async {
        let trimmedFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedFirstName.isEmpty else { return }

        // ✅ Générer un username SIMPLE et RAPIDE (sans appels Firestore bloquants)
        // On génère un username basique et on le vérifiera plus tard si nécessaire
        let baseUsername = trimmedFirstName.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")

        do {
                // ✅ SIMPLIFIÉ: Vérifier l'authentification sans attendre (non-bloquant)
                guard let finalUserId = AuthUser.current?.uid else {
                    // Si pas authentifié, stocker temporairement pour sauvegarde différée
                    UserDefaults.standard.set(trimmedFirstName, forKey: "pending_firstname_to_save")
                    UserDefaults.standard.set(baseUsername, forKey: "pending_username_to_save")
                    return
                }

                // Le prénom saisi maintenant gagne toujours sur un ancien prénom en attente.
                let pendingFirstName = trimmedFirstName
                let pendingBase = baseUsername
                UserDefaults.standard.removeObject(forKey: "pending_firstname_to_save")
                UserDefaults.standard.removeObject(forKey: "pending_username_to_save")

                let pendingUsername = try await ProcessUsernameRegistry.shared.suggestAvailableUsername(
                    base: pendingBase.isEmpty ? "user" : pendingBase,
                    userId: finalUserId
                )

                var profile: UnifiedUserProfile

                if let existingProfile = profileService.currentProfile {
                    profile = existingProfile
                    profile.firstName = pendingFirstName
                } else {
                    profile = UnifiedUserProfile(
                        userId: finalUserId,
                        firstName: pendingFirstName
                    )
                }

                try await profileService.saveProfile(profile)
                try await profileService.updateUsername(pendingUsername, displayName: pendingFirstName)

                // ✅ CRITIQUE: Recharger le profil pour s'assurer que currentProfile est à jour
                await profileService.loadProfile()

                // Mettre à jour le displayName de Firebase Auth aussi
                if let user = AuthUser.current,
                   var changeRequest = user.createProfileChangeRequest() {
                    changeRequest.displayName = pendingFirstName
                    try? await changeRequest.commitChanges()
                }
        } catch {
            DebugLogger.error("\(error.localizedDescription)")
        }
}
}
