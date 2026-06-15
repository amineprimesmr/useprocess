//
//  GoalProjectionStepView.swift
//  Process
//
//  Vue de projection dynamique avec courbe de progression
//

import SwiftUI

struct GoalProjectionStepView: View {
    let primaryGoals: Set<PrimaryGoal>
    let currentWeight: Double?
    let idealWeight: Double?
    let weightGoal: WeightGoal?
    let experienceLevel: ExperienceLevel?
    let yearsOfExperience: Int
    let selectedSports: Set<String>
    let deadline: GoalDeadline?
    let trainingFrequency: String?
    let goalPace: GoalPace?

    @State var projectedDate: Date?
    @State var projectionMessage: String = ""
    @State var dayOnly: String = "" // Ex: "29"
    @State var monthOnly: String = "" // Ex: "avril"
    @State var monthlyProjectionMessage: String = ""
    @State var monthlyProjectionSecondLine: String = "" // Deuxième ligne du message mensuel
    @State var displayedDay: String = "" // Pour l'animation
    @State var displayedMonth: String = "" // Pour l'animation
    @State var countdownDays: Int = 0 // Compte à rebours en jours
    @State var curveAnimationProgress: Double = 0 // Progression de l'animation de la courbe
    @State var countdownTask: Task<Void, Never>? // ✅ Task pour pouvoir l'annuler
    @State var isCountdownFinished: Bool = false // ✅ Suivre si l'animation du compteur est finie
    @State private var curveAnimationTimer: Timer? // ✅ Timer pour l'animation de la courbe

    var onValidationChanged: ((Bool) -> Void)?

    @State private var showCelebration = false

    var body: some View {
        mainContent(geometry: nil) // ✅ Pas besoin de GeometryReader, utiliser nil
            .onAppear {
            calculateProjection()

            // ✅ CRITIQUE: S'assurer que curveAnimationProgress commence à 0
            curveAnimationProgress = 0.0

            // ✅ Démarrer l'animation de la courbe progressivement avec un Timer pour un contrôle précis
            Task {
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 secondes

                // ✅ Annuler le timer précédent s'il existe
                curveAnimationTimer?.invalidate()

                // ✅ Utiliser un Timer pour mettre à jour progressivement curveAnimationProgress
                let duration: TimeInterval = 3.0
                let startTime = Date()
                curveAnimationTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { timer in
                    let elapsed = Date().timeIntervalSince(startTime)
                    let progress = min(elapsed / duration, 1.0)

                    // ✅ Utiliser easeOut curve manuellement
                    let easeOutProgress = 1.0 - pow(1.0 - progress, 3.0)

                    curveAnimationProgress = easeOutProgress

                    if progress >= 1.0 {
                        timer.invalidate()
                        curveAnimationProgress = 1.0
                    }
                }

                if let timer = curveAnimationTimer {
                    RunLoop.main.add(timer, forMode: .common)
                }
            }

            // ✅ Démarrer le compte à rebours animé
            startCountdownAnimation()

            // Animation de célébration après un court délai
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    showCelebration = true
                }
            }

            // ✅ NE PAS valider immédiatement - le bouton sera activé quand le compteur sera fini
            onValidationChanged?(false)
        }
        .onDisappear {
            // ✅ Annuler la Task pour arrêter les vibrations quand on quitte la page
            countdownTask?.cancel()
            countdownTask = nil
            // ✅ Annuler le timer d'animation de la courbe
            curveAnimationTimer?.invalidate()
            curveAnimationTimer = nil
        }
        .onChange(of: primaryGoals) { _, _ in
            calculateProjection()
        }
        .onChange(of: idealWeight) { _, _ in
            calculateProjection()
        }
        .onChange(of: experienceLevel) { _, _ in
            calculateProjection()
        }
        .onChange(of: yearsOfExperience) { _, _ in
            calculateProjection()
        }
        .onChange(of: trainingFrequency) { _, _ in
            calculateProjection()
        }
    }
}
