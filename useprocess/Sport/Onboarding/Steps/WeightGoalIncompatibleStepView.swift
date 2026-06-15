//
//  WeightGoalIncompatibleStepView.swift
//  Process
//
//  Page de blocage lorsque l'objectif de poids est incompatible avec l'IMC actuel
//  Même UX et animations que PersonalizedWelcomeStepView
//

import SwiftUI

struct WeightGoalIncompatibleStepView: View {
    @EnvironmentObject var profileService: UnifiedProfileService

    // ✅ Paramètres
    let firstName: String
    let currentWeight: Double
    let height: Double
    let selectedGoal: WeightGoal

    var onBack: (() -> Void)?
    var onValidationChanged: ((Bool) -> Void)?

    @State private var animationProgress: CGFloat = 0.0
    @State private var displayedText: String = ""
    @State private var typewriterTask: Task<Void, Never>? // ✅ Task pour pouvoir l'annuler

    // ✅ Récupérer le prénom avec fallback
    private var userFirstName: String {
        let trimmed = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && trimmed != "Utilisateur" {
            return trimmed
        }
        if let profileFirstName = profileService.currentProfile?.firstName,
           !profileFirstName.isEmpty,
           profileFirstName != "Utilisateur" {
            return profileFirstName
        }
        return "toi"
    }

    // ✅ Calculer l'IMC actuel
    private var currentBMI: Double {
        let heightInMeters = height / 100.0
        return currentWeight / (heightInMeters * heightInMeters)
    }

    // ✅ Déterminer le message selon l'incompatibilité
    private var message: String {
        if currentBMI >= 25.0 && selectedGoal == .gain {
            // Surpoids/Obésité + objectif "prendre du poids"
            return "\(userFirstName), tu es actuellement en surpoids par rapport à ta taille. Tu ne peux pas avoir comme objectif de prendre du poids. Nous te recommandons de choisir l'objectif de perdre du poids pour améliorer ta santé."
        } else if currentBMI < 18.5 && selectedGoal == .lose {
            // Maigreur + objectif "perdre du poids"
            return "\(userFirstName), tu es actuellement en dessous de ton poids de forme. Tu ne peux pas avoir comme objectif de perdre du poids. Nous te recommandons de choisir l'objectif de prendre du poids pour améliorer ta santé."
        }
        // Fallback (ne devrait pas arriver)
        return "\(userFirstName), cet objectif n'est pas adapté à ta situation actuelle."
    }

    private var fullText: String {
        message
    }

    var body: some View {
        OnboardingStandardStepLayout {
            VStack(spacing: 40) {
                VStack(spacing: 20) {
                    TypewriterTextView(
                        text: fullText,
                        displayedText: displayedText,
                        fontSize: 28,
                        fontWeight: .semibold,
                        defaultColor: OnboardingTheme.narrativeText,
                        highlightColor: OnboardingTheme.narrativeText,
                        highlightStart: ""
                    )
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 40)
                }
                .padding(.horizontal, 40)

                Spacer()
            }
        }
        .onAppear {
            // Valider automatiquement (mais l'utilisateur ne peut que revenir en arrière)
            onValidationChanged?(true)

            // Animation machine à écrire lettre par lettre
            startTypewriterAnimation()
        }
        .onDisappear {
            // ✅ Annuler la Task pour arrêter les vibrations quand on quitte la page
            typewriterTask?.cancel()
            typewriterTask = nil
        }
    }

    // MARK: - Animation Machine à Écrire

    private func startTypewriterAnimation() {
        displayedText = ""
        let text = fullText
        let characters = Array(text)

        // ✅ Annuler la Task précédente si elle existe
        typewriterTask?.cancel()

        // Utiliser Task pour animation asynchrone plus fluide
        typewriterTask = Task {
            for (_, character) in characters.enumerated() {
                // ✅ Vérifier si la Task a été annulée
                if Task.isCancelled {
                    return
                }

                // Délai variable pour effet plus naturel
                let delay: TimeInterval
                if character == " " {
                    delay = 0.02 // Espaces plus rapides
                } else if character == "." || character == "!" {
                    delay = 0.08 // Pause plus longue pour ponctuation
                } else {
                    delay = 0.04 // Vitesse normale
                }

                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                // ✅ Vérifier à nouveau après le sleep
                if Task.isCancelled {
                    return
                }

                guard !Task.isCancelled else { return }

                displayedText += String(character)

                // Vibration stylée
                if character != " " {
                    // Vibration légère pour chaque lettre
                    HapticManager.shared.impact(.soft)
                }

                // Vibration plus forte pour ponctuation
                if character == "!" || character == "." {
                    HapticManager.shared.impact(.light)
                }
            }

            // ✅ Vérifier avant la vibration finale
            guard !Task.isCancelled else { return }

            // Animation terminée - Vibration finale de succès
            guard !Task.isCancelled else { return }

            HapticManager.shared.notification(.success)

            // Animation d'apparition pour les autres éléments
            withAnimation(.easeInOut(duration: 0.8)) {
                animationProgress = 1.0
            }
        }
    }
}
