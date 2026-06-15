//
//  WeightEstimationStepView.swift
//  Process
//
//  Vue d'estimation de la date d'atteinte du poids idéal
//  ✅ Design unifié avec GoalProjectionStepView
//

import SwiftUI

struct WeightEstimationStepView: View {
    let currentWeight: Double
    let idealWeight: Double
    let weightGoal: WeightGoal
    let weeklyRate: Double  // Vitesse en kg/semaine (0.2, 0.3, 0.5, 0.7, 1.0) - Utilisé pour la première estimation

    // ✅ Paramètres optionnels pour la deuxième estimation (après questions sport)
    let experienceLevel: ExperienceLevel?
    let yearsOfExperience: Int
    let selectedSports: Set<String>
    let deadline: GoalDeadline?
    let trainingFrequency: String?
    let goalPace: GoalPace?

    var onValidationChanged: ((Bool) -> Void)?

    @State var projectedDate: Date?
    @State var dayOnly: String = "" // Ex: "29"
    @State var monthOnly: String = "" // Ex: "avril"
    @State var monthlyProjectionMessage: String = ""
    @State var monthlyProjectionSecondLine: String = "" // Deuxième ligne du message mensuel
    @State var displayedDay: String = "" // Pour l'animation
    @State var displayedMonth: String = "" // Pour l'animation
    @State var countdownDays: Int = 0 // Compte à rebours en jours
    @State var curveAnimationProgress: Double = 0 // Progression de l'animation de la courbe
    @State var countdownTask: Task<Void, Never>? // ✅ Task pour pouvoir l'annuler
    @State var dateAnimationTasks: [DispatchWorkItem] = [] // ✅ Tasks pour l'animation de date pour pouvoir les annuler
    @State var isCountdownFinished: Bool = false // ✅ Suivre si l'animation du compteur est finie
    @State var curveAnimationTimer: Timer? // ✅ Timer pour l'animation de la courbe
    @State var showingInitialDate: Bool = false // ✅ Pour afficher la date initiale pendant 1 seconde
    @State var initialDisplayDate: Date? // ✅ Date initiale à afficher (pour la deuxième estimation)

    var body: some View {
        EstimationStepLayout(
            titleMessage: mainProjectionMessage,
            displayDay: currentDisplayDay,
            displayMonth: currentDisplayMonth,
            graph: {
                if let displayDate = showingInitialDate ? initialDisplayDate : projectedDate {
                    graphViewWithDurabilityStyle(for: displayDate, isSecondEstimation: showingInitialDate)
                }
            },
            bottom: {
                bottomMessagesView
            }
        )
            .onAppear {
                calculateProjectedDate()
                calculateMonthlyProjectionMessage()

                // ✅ CRITIQUE: S'assurer que curveAnimationProgress commence à 0
                curveAnimationProgress = 0.0

                // ✅ NE PAS valider immédiatement - le bouton sera activé quand le compteur sera fini
                onValidationChanged?(false)
                isCountdownFinished = false

                // ✅ GARANTIE DE SÉCURITÉ: Activer le bouton après un délai maximum (6 secondes)
                // pour éviter que l'utilisateur reste bloqué même si les animations échouent
                let safetyTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 6_000_000_000) // 6 secondes
                    if !isCountdownFinished {
                        isCountdownFinished = true
                        onValidationChanged?(true)
                    }
                }

                // ✅ Démarrer les animations avec délai pour la date initiale (si deuxième estimation)
                let service = GoalProjectionService.shared
                let initialDate = service.getInitialProjectedDate()
                let isSecondEstimation = experienceLevel != nil || !selectedSports.isEmpty || trainingFrequency != nil

                if isSecondEstimation, let initial = initialDate, let final = projectedDate, initial > final {
                    // ✅ DEUXIÈME ESTIMATION: Afficher d'abord la date initiale pendant 1 seconde
                    initialDisplayDate = initial
                    showingInitialDate = true
                    updateDateDisplay(date: initial) // Afficher la date initiale

                    Task {
                        // Attendre 1 seconde avec la date initiale
                        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 seconde

                        // ✅ Vérifier si la Task a été annulée
                        guard !Task.isCancelled else {
                            safetyTask.cancel()
                            return
                        }

                        // ✅ Maintenant animer vers la nouvelle date ET démarrer le compteur en même temps
                        showingInitialDate = false
                        _ = animateDateFrom(initial, to: final) { duration in
                            // ✅ Callback: démarrer le compteur de jours EN MÊME TEMPS que l'animation de date
                            self.startCountdownAnimation(totalDuration: duration)
                        }

                        // ✅ Annuler la tâche de sécurité car l'animation normale va gérer l'activation du bouton
                        safetyTask.cancel()

                        // ✅ Démarrer l'animation de la courbe (qui finit plus tôt)
                        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 secondes après le début de l'animation de date

                        // ✅ Vérifier à nouveau si la Task a été annulée
                        guard !Task.isCancelled else { return }

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
                } else {
                    // ✅ PREMIÈRE ESTIMATION: Animation normale
                    Task {
                        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 secondes

                        // ✅ Vérifier si la Task a été annulée
                        guard !Task.isCancelled else {
                            safetyTask.cancel()
                            return
                        }

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

                        // ✅ Le compte à rebours sera démarré par animateDateFrom() avec le callback
                        // (appelé dans calculateProjectedDate() pour la première estimation)
                        // ✅ Si le compteur n'a pas été démarré par animateDateFrom, le démarrer ici
                        if countdownDays == 0, let date = projectedDate {
                            let calendar = Calendar.current
                            let now = Date()
                            let daysDifference = calendar.dateComponents([.day], from: now, to: date).day ?? 0
                            if daysDifference > 0 {
                                // Le compteur n'a pas été démarré, le démarrer maintenant
                                startCountdownAnimation()
                                // ✅ Activer le bouton après la durée standard
                                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                                    safetyTask.cancel()
                                    self.isCountdownFinished = true
                                    self.onValidationChanged?(true)
                                }
                            } else {
                                // Pas de jours à compter, activer immédiatement
                                safetyTask.cancel()
                                isCountdownFinished = true
                                onValidationChanged?(true)
                            }
                        } else {
                            // Le compteur a été démarré par animateDateFrom, annuler la tâche de sécurité
                            // (le bouton sera activé par animateDateFrom quand l'animation finit)
                        }
                    }
                }
            }
            .onDisappear {
                // ✅ Annuler la Task pour arrêter les vibrations quand on quitte la page
                countdownTask?.cancel()
                countdownTask = nil
                // ✅ Annuler toutes les tasks d'animation de date
                dateAnimationTasks.forEach { $0.cancel() }
                dateAnimationTasks.removeAll()
                // ✅ Annuler le timer d'animation de la courbe
                curveAnimationTimer?.invalidate()
                curveAnimationTimer = nil
            }
    }

    // MARK: - Computed Properties

    private var mainProjectionMessage: String {
        // Afficher uniquement le poids idéal, pas la différence de poids
        return "Tu feras \(String(format: "%.0f", idealWeight)) kg le"
    }

    // ✅ CORRIGÉ: Afficher toujours une valeur (jamais vide)
    private var currentDisplayDay: String {
        if !displayedDay.isEmpty { return displayedDay }
        if !dayOnly.isEmpty { return dayOnly }
        // Fallback: calculer immédiatement
        if let date = projectedDate {
            return "\(Calendar.current.component(.day, from: date))"
        }
        return "..."
    }

    private var currentDisplayMonth: String {
        if !displayedMonth.isEmpty { return displayedMonth }
        if !monthOnly.isEmpty { return monthOnly }
        // Fallback: calculer immédiatement
        if let date = projectedDate {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "fr_FR")
            formatter.dateFormat = "MMMM"
            return formatter.string(from: date).capitalized
        }
        return "..."
    }
}
