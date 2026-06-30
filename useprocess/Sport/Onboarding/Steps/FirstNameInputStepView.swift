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
    @State private var isTextFieldFocused = false
    @State private var didBootstrap = false
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

                ZStack {
                    TextField("", text: $firstName)
                        .font(.system(size: firstName.isEmpty ? 22 : 36, weight: .medium))
                        .foregroundColor(.clear)
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.plain)
                        .focused($isTextFieldFocusedState)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled(true)
                        .textContentType(.givenName)
                        .onSubmit {
                            let trimmed = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }

                            HapticManager.shared.impact(.medium)
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            onComplete?()

                            Task.detached(priority: .background) {
                                await saveFirstNameAndContinue()
                            }
                        }

                    if firstName.isEmpty {
                        Text(OnboardingCopy.text("Comment devons-nous t'appeler ?", blank: "Saisie libre"))
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(OnboardingTheme.mutedText)
                            .multilineTextAlignment(.center)
                            .allowsHitTesting(false)
                    } else {
                        Text(firstName)
                            .font(.system(size: 36, weight: .medium))
                            .foregroundStyle(OnboardingTheme.primaryText)
                            .multilineTextAlignment(.center)
                            .allowsHitTesting(false)
                    }
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
        .onChange(of: isTextFieldFocusedState) { _, newValue in
            isTextFieldFocused = newValue
        }
        .onChange(of: firstName) { _, newValue in
            // Valider automatiquement quand le prénom est saisi
            let isValid = !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            onValidationChanged?(isValid)
        }
        .onDisappear {
            isTextFieldFocusedState = false
        }
    }

    private func bootstrapIfNeeded() {
        guard !didBootstrap else { return }
        didBootstrap = true
        loadExistingFirstName()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
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

    private func saveFirstNameAndContinue() async {
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

                // ✅ NOUVEAU: Vérifier s'il y a un prénom en attente à sauvegarder
                let pendingFirstName = UserDefaults.standard.string(forKey: "pending_firstname_to_save") ?? trimmedFirstName
                let pendingBase = UserDefaults.standard.string(forKey: "pending_username_to_save") ?? baseUsername
                if UserDefaults.standard.string(forKey: "pending_firstname_to_save") != nil {
                    UserDefaults.standard.removeObject(forKey: "pending_firstname_to_save")
                    UserDefaults.standard.removeObject(forKey: "pending_username_to_save")
                }

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

                // Ne pas passer automatiquement - l'utilisateur doit cliquer sur CONTINUER
                // onComplete?() sera appelé quand l'utilisateur clique sur le bouton
        } catch {
            DebugLogger.error("\(error.localizedDescription)")
        }
}
}
