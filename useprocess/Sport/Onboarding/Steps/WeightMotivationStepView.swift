//
//  WeightMotivationStepView.swift
//  Process
//
//  Page de motivation après la sélection du poids idéal
//

import SwiftUI

struct WeightMotivationStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    let currentWeight: Double
    let idealWeight: Double
    let weightGoal: WeightGoal?

    var onComplete: (() -> Void)?
    var onValidationChanged: ((Bool) -> Void)?

    @State private var animationProgress: CGFloat = 0.0
    @State private var displayedText: String = ""
    @State private var typewriterTask: Task<Void, Never>? // ✅ Task pour pouvoir l'annuler

    // Calculer le nombre de kg à perdre/prendre
    private var weightDifference: Double {
        abs(idealWeight - currentWeight)
    }

    private var actionText: String {
        guard let goal = weightGoal else { return "atteindre" }
        return goal == .lose ? "perdre" : "prendre"
    }

    // Texte complet à animer
    private var fullText: String {
        let sport = "\(actionText.capitalized) \(Int(weightDifference)) kg est un objectif réalisable. Ce n'est pas du tout difficile"
        return OnboardingCopy.text(sport, blank: "Message de motivation à personnaliser")
    }

    private var statisticsText: String {
        let sport: String
        if let goal = weightGoal {
            switch goal {
            case .lose:
                sport = "91% des utilisateurs de Process maintiennent leur perte de poids même 6 mois plus tard."
            case .gain:
                sport = "91% des utilisateurs de Process maintiennent leur prise de poids même 6 mois plus tard."
            }
        } else {
            sport = "91% des utilisateurs de Process maintiennent leur objectif de poids même 6 mois plus tard."
        }
        return OnboardingCopy.text(sport, blank: "Statistique à personnaliser")
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
                        defaultColor: .white.opacity(0.9),
                        highlightColor: Color(red: 0.13, green: 0.98, blue: 0.47),
                        highlightStart: "Ce n'est pas"
                    )
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 40)
                }
                .padding(.horizontal, 40)

                Text(statisticsText)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 20)
                    .opacity(animationProgress)

                Spacer()
            }
        }
        .onAppear {
            // ✅ Ne pas valider immédiatement - attendre que tous les textes soient apparus
            onValidationChanged?(false)
            // ✅ CRITIQUE: Réinitialiser le flag de validation dans le ViewModel
            viewModel.isWeightMotivationCompleted = false

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

            // ✅ Attendre que l'animation de la statistique soit complètement terminée avant de valider
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                viewModel.isWeightMotivationCompleted = true
                onValidationChanged?(true)
            }
        }
    }
}

// MARK: - Typewriter Text View Component

struct TypewriterTextView: View {
    let text: String
    let displayedText: String
    let fontSize: CGFloat
    let fontWeight: Font.Weight
    let defaultColor: Color
    let highlightColor: Color
    let highlightStart: String

    var body: some View {
        ZStack {
            // ✅ Texte complet invisible en arrière-plan pour fixer la mise en page
            // Cela empêche le texte de changer de ligne pendant l'animation
            Text(text)
                .font(.system(size: fontSize, weight: fontWeight))
                .foregroundColor(.clear)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .frame(maxWidth: .infinity)

            // ✅ Texte animé visible par-dessus
            Text(attributedDisplayText)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .frame(maxWidth: .infinity)
        }
    }

    // ✅ Computed property pour créer l'AttributedString avec couleurs dynamiques
    private var attributedDisplayText: AttributedString {
        var attributedString = AttributedString(displayedText)

        // Appliquer la couleur par défaut à tout le texte
        attributedString.foregroundColor = defaultColor
        attributedString.font = .system(size: fontSize, weight: fontWeight)

        // Appliquer la couleur highlight à la partie spécifiée
        // Utiliser range(of:) directement sur l'AttributedString pour trouver la partie à mettre en vert
        if let highlightRange = attributedString.range(of: highlightStart) {
            // Appliquer la couleur verte à partir de highlightStart jusqu'à la fin
            let endRange = highlightRange.lowerBound..<attributedString.endIndex
            attributedString[endRange].foregroundColor = highlightColor
        }

        return attributedString
    }
}
