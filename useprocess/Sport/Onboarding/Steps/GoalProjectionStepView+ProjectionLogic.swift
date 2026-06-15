//
//  GoalProjectionStepView+ProjectionLogic.swift
//  Process
//

import SwiftUI

extension GoalProjectionStepView {
    // MARK: - Methods

    func calculateProjection() {
        let service = GoalProjectionService.shared

        let previousDate = projectedDate ?? service.getInitialProjectedDate()

        // Calculer la date projetée
        var calculatedDate = service.calculateProjectedDate(
            primaryGoals: primaryGoals,
            currentWeight: currentWeight,
            idealWeight: idealWeight,
            weightGoal: weightGoal,
            experienceLevel: experienceLevel,
            yearsOfExperience: yearsOfExperience,
            selectedSports: selectedSports,
            deadline: deadline,
            trainingFrequency: trainingFrequency,
            goalPace: goalPace
        )

        // ✅ SÉCURITÉ: Si le service retourne nil, utiliser une date par défaut (3 mois)
        if calculatedDate == nil {
            calculatedDate = Calendar.current.date(byAdding: .month, value: 3, to: Date())
        }

        if let date = calculatedDate {

            // ✅ CRITIQUE: TOUJOURS assigner projectedDate et updateDateDisplay IMMÉDIATEMENT
            projectedDate = date
            updateDateDisplay(date: date) // ← Affiche la date finale dès le début

            // ✅ Si on a une date précédente ET qu'elle est plus éloignée que la nouvelle,
            // la stocker comme date initiale pour l'animation de décompte
            if let previous = previousDate, previous > date {
                service.storeInitialProjectedDate(previous, for: "goalProjection")
                // Animer depuis la date précédente vers la nouvelle
                animateDateFrom(previous, to: date)
            } else if previousDate == nil {
                // Première fois : stocker la date initiale
            service.storeInitialProjectedDate(date, for: "goalProjection")
                // Animer depuis une date plus éloignée (20% plus loin)
                let calendar = Calendar.current
                let daysDifference = calendar.dateComponents([.day], from: Date(), to: date).day ?? 0
                let initialDays = Int(Double(daysDifference) * 1.2)
                if let animInitialDate = calendar.date(byAdding: .day, value: initialDays, to: Date()) {
                    animateDateFrom(animInitialDate, to: date)
                }
            }

            // Générer le message
            let generatedMessage = service.generateProjectionMessage(
                primaryGoals: primaryGoals,
                projectedDate: date,
                idealWeight: idealWeight,
                weightGoal: weightGoal
            )

            // ✅ SÉCURITÉ: Si le message est vide, utiliser un message par défaut
            if generatedMessage.isEmpty {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "fr_FR")
                formatter.dateFormat = "d MMMM"
                let dateString = formatter.string(from: date)
                if primaryGoals.contains(.manageWeight), let ideal = idealWeight {
                    projectionMessage = "Tu feras \(String(format: "%.0f", ideal)) kg le \(dateString)"
                } else {
                    projectionMessage = "Tu auras atteint 100% de ton potentiel le \(dateString)"
                }
            } else {
                projectionMessage = generatedMessage
            }


            // Calculer le message mensuel
            calculateMonthlyProjectionMessage()
        }
    }

    func updateDateDisplay(date: Date) {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: date)
        dayOnly = "\(day)"

        let monthFormatter = DateFormatter()
        monthFormatter.locale = Locale(identifier: "fr_FR")
        monthFormatter.dateFormat = "MMMM"
        monthOnly = monthFormatter.string(from: date).capitalized
    }

    /// Anime la date depuis une date initiale (plus éloignée) vers une date cible (plus proche)
    func animateDateFrom(_ fromDate: Date, to toDate: Date) {
        let calendar = Calendar.current
        let fromDay = calendar.component(.day, from: fromDate)
        let toDay = calendar.component(.day, from: toDate)

        let fromMonthFormatter = DateFormatter()
        fromMonthFormatter.locale = Locale(identifier: "fr_FR")
        fromMonthFormatter.dateFormat = "MMMM"
        let fromMonth = fromMonthFormatter.string(from: fromDate).capitalized

        let toMonthFormatter = DateFormatter()
        toMonthFormatter.locale = Locale(identifier: "fr_FR")
        toMonthFormatter.dateFormat = "MMMM"
        let toMonth = toMonthFormatter.string(from: toDate).capitalized

        // Calculer le nombre de jours entre les deux dates
        let daysDifference = abs(calendar.dateComponents([.day], from: fromDate, to: toDate).day ?? 0)

        // Définir la durée de l'animation (plus longue si la différence est grande)
        let animationDuration = min(max(Double(daysDifference) * 0.01, 1.0), 3.0) // Entre 1 et 3 secondes

        // Commencer avec la date initiale
        displayedDay = "\(fromDay)"
        displayedMonth = fromMonth

        // Mettre à jour les valeurs finales
        dayOnly = "\(toDay)"
        monthOnly = toMonth

        // Animer le jour
        if fromDay != toDay {
            // ✅ CORRECTION: Créer un tableau directement au lieu d'utiliser une expression ternaire avec types incompatibles
            let daySteps: [Int]
            if fromDay < toDay {
                daySteps = Array(fromDay...toDay)
            } else {
                daySteps = Array((toDay...fromDay).reversed())
            }

            let dayStepDuration = animationDuration / Double(daySteps.count)

            for (index, day) in daySteps.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * dayStepDuration) {
                    withAnimation(.easeOut(duration: dayStepDuration)) {
                        displayedDay = "\(day)"
                    }
                }
            }
        } else {
            displayedDay = "\(toDay)"
        }

        // Animer le mois si nécessaire
        if fromMonth != toMonth {
            // Attendre que l'animation du jour soit à mi-chemin
            DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration * 0.5) {
                withAnimation(.easeOut(duration: animationDuration * 0.5)) {
                    displayedMonth = toMonth
                }
            }
        } else {
            displayedMonth = toMonth
        }

        // Mettre à jour l'affichage final après l'animation
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
            updateDateDisplay(date: toDate)
        }
    }

    func calculateMonthlyProjectionMessage() {
        // ✅ Première ligne : toujours "Basé sur ton profil"
        monthlyProjectionMessage = "Basé sur ton profil"

        guard let date = projectedDate else {
            monthlyProjectionSecondLine = "tu progresseras à ton rythme"
            return
        }

        let calendar = Calendar.current
        let now = Date()

        guard let oneMonthLater = calendar.date(byAdding: .month, value: 1, to: now) else {
            monthlyProjectionSecondLine = "tu progresseras à ton rythme"
            return
        }

        let totalDays = calendar.dateComponents([.day], from: now, to: date).day ?? 30
        let daysInMonth = calendar.dateComponents([.day], from: now, to: oneMonthLater).day ?? 30

        if totalDays > 0 {
            if primaryGoals.contains(.manageWeight),
               let current = currentWeight,
               let ideal = idealWeight,
               let goal = weightGoal {
                let totalDifference = abs(ideal - current)
                let monthlyProgress = (totalDifference * Double(daysInMonth)) / Double(totalDays)
                let monthlyWeight = String(format: "%.1f", monthlyProgress)

                if goal == .lose {
                    monthlyProjectionSecondLine = "tu vas perdre \(monthlyWeight) kg en un mois"
                } else if goal == .gain {
                    monthlyProjectionSecondLine = "tu vas prendre \(monthlyWeight) kg en un mois"
                } else {
                    monthlyProjectionSecondLine = "tu vas progresser de \(monthlyWeight) kg en un mois"
                }
            } else {
                let progressPercentage = (Double(daysInMonth) / Double(totalDays)) * 100
                monthlyProjectionSecondLine = "tu progresseras de \(String(format: "%.0f", progressPercentage))% en un mois"
            }
        } else {
            monthlyProjectionSecondLine = "tu vas atteindre ton objectif rapidement"
        }
    }

    // ✅ Fonction pour démarrer l'animation du compte à rebours
    func startCountdownAnimation() {
        guard let date = projectedDate else { return }

        // ✅ Annuler la Task précédente si elle existe
        countdownTask?.cancel()

        let calendar = Calendar.current
        let now = Date()
        let daysDifference = calendar.dateComponents([.day], from: now, to: date).day ?? 0

        // ✅ Commencer avec une valeur plus élevée pour l'effet de décompte
        let initialDays = max(daysDifference, Int(Double(daysDifference) * 1.2))
        countdownDays = initialDays

        // ✅ Animer progressivement vers la valeur réelle - PLUS LENT
        let totalDuration: TimeInterval = 4.0 // ✅ Augmenté de 2.5 à 4.0 pour rendre plus lent
        let steps = abs(initialDays - daysDifference)

        // ✅ Marquer que le compteur n'est pas encore fini
        isCountdownFinished = false

        if steps > 0 {
            let stepInterval = totalDuration / Double(steps)
            let direction = initialDays > daysDifference ? -1 : 1

            // ✅ Calculer le nombre réel de jours qui changent (pas les steps)

            countdownTask = Task { @MainActor in
                var currentDays = initialDays
                var lastVibratedDay: Int? // ✅ Suivre le dernier jour réel pour lequel on a vibré

                while currentDays != daysDifference {
                    // ✅ Vérifier si la Task a été annulée
                    if Task.isCancelled {
                        return
                    }

                    currentDays += direction

                    withAnimation(.spring(response: 0.15, dampingFraction: 0.8)) {
                        countdownDays = currentDays
                    }

                    // ✅ Vibration UNIQUEMENT pour les jours réels (pas les jours fictifs initiaux)
                    // Si daysDifference = 9, on doit vibrer exactement 9 fois (une fois par jour qui défile)
                    let isInRealRange = (direction < 0 && currentDays >= daysDifference) || (direction > 0 && currentDays <= daysDifference)

                    if isInRealRange && currentDays != lastVibratedDay {
                        // ✅ Vérifier à nouveau avant de vibrer
                        guard !Task.isCancelled else { return }

                        HapticManager.shared.impact(.soft)
                        lastVibratedDay = currentDays
                    }

                    try? await Task.sleep(nanoseconds: UInt64(stepInterval * 1_000_000_000))

                    // ✅ Vérifier à nouveau après le sleep
                    if Task.isCancelled {
                        return
                    }
                }

                // ✅ Vérifier avant la vibration finale
                guard !Task.isCancelled else { return }

                // Haptic feedback final
                HapticManager.shared.notification(.success)

                // ✅ Marquer que le compteur est fini et activer le bouton
                isCountdownFinished = true
                onValidationChanged?(true)
            }
        } else {
            countdownDays = daysDifference
            // ✅ Si pas d'animation, activer immédiatement
            isCountdownFinished = true
            onValidationChanged?(true)
        }
    }
}
