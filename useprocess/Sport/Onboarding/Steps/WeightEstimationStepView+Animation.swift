//
//  WeightEstimationStepView+Animation.swift
//  Process
//

import SwiftUI

extension WeightEstimationStepView {
    // MARK: - Methods

    func calculateProjectedDate() {
        let calendar = Calendar.current
        let now = Date()
        let service = GoalProjectionService.shared

        // ✅ Détecter si c'est la deuxième estimation (après questions sport)
        // On détecte cela si on a des informations de sport/expérience
        let isSecondEstimation = experienceLevel != nil || !selectedSports.isEmpty || trainingFrequency != nil

        // ✅ CRITIQUE: Récupérer la date initiale de la première estimation pour l'animation
        let initialDate = service.getInitialProjectedDate()

        var calculatedDate: Date?

        if isSecondEstimation {
            // ✅ DEUXIÈME ESTIMATION: Utiliser le système intelligent avec toutes les informations
            // Cela va calculer une date plus optimiste (antérieure à la première)
            calculatedDate = service.calculateProjectedDate(
                primaryGoals: Set([.manageWeight]),
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
        } else {
            // ✅ PREMIÈRE ESTIMATION: Calcul simple avec weeklyRate
            let difference = abs(idealWeight - currentWeight)
            guard difference > 0 else {
                calculatedDate = calendar.date(byAdding: .month, value: 1, to: now)
                if let date = calculatedDate {
                    // Stocker la date initiale pour la deuxième estimation
                    service.storeInitialProjectedDate(date, for: "weightEstimation")
                    // Animer depuis une date plus éloignée (20% plus loin)
                    let daysDifference = calendar.dateComponents([.day], from: now, to: date).day ?? 0
                    let initialDays = Int(Double(daysDifference) * 1.2)
                    if let initialDate = calendar.date(byAdding: .day, value: initialDays, to: now) {
                        // ✅ CRITIQUE: Toujours passer un callback pour démarrer le compteur et activer le bouton
                        animateDateFrom(initialDate, to: date) { duration in
                            self.startCountdownAnimation(totalDuration: duration)
                        }
                    } else {
                        updateDateDisplay(date: date)
                        // ✅ CRITIQUE: Si pas d'animation de date, démarrer le compteur et activer le bouton après un délai
                        startCountdownAnimation()
                        // ✅ Activer le bouton après la durée standard de 4 secondes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                            self.isCountdownFinished = true
                            self.onValidationChanged?(true)
                        }
                    }
                    projectedDate = date
                }
                return
            }

            // Calculer le nombre de semaines nécessaires
            let weeksNeeded = Int(ceil(difference / weeklyRate))
            calculatedDate = calendar.date(byAdding: .weekOfYear, value: weeksNeeded, to: now)
        }

        // ✅ SÉCURITÉ: Si le calcul a échoué, utiliser une date par défaut (2 mois)
        if calculatedDate == nil {
            calculatedDate = calendar.date(byAdding: .month, value: 2, to: now)
        }

        // ✅ Gérer l'animation de date
        if let date = calculatedDate {
            // ✅ CRITIQUE: TOUJOURS assigner projectedDate et updateDateDisplay IMMÉDIATEMENT
            projectedDate = date
            updateDateDisplay(date: date) // ← Affiche la date finale dès le début

            if let initial = initialDate, initial > date {
                // ✅ DEUXIÈME ESTIMATION: Animer depuis la première date (plus tard) vers la nouvelle (plus tôt)
                service.storeInitialProjectedDate(initial, for: "weightEstimation")
                // Note: L'animation de date sera gérée dans onAppear avec le callback
            } else if initialDate == nil {
                // ✅ PREMIÈRE ESTIMATION: Stocker la date initiale
                service.storeInitialProjectedDate(date, for: "weightEstimation")
                // Animer depuis une date plus éloignée (20% plus loin)
                let daysDifference = calendar.dateComponents([.day], from: now, to: date).day ?? 0
                let initialDays = Int(Double(daysDifference) * 1.2)
                if let animInitialDate = calendar.date(byAdding: .day, value: initialDays, to: now) {
                    // Pour la première estimation, démarrer l'animation de date
                    _ = animateDateFrom(animInitialDate, to: date) { duration in
                        self.startCountdownAnimation(totalDuration: duration)
                    }
                } else {
                    // Si pas d'animation de date, démarrer le compteur normalement
                    startCountdownAnimation()
                }
            } else {
                // Pas d'animation nécessaire, démarrer le compteur
                startCountdownAnimation()
                // Activer le bouton après la durée standard de 4 secondes
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                    self.isCountdownFinished = true
                    self.onValidationChanged?(true)
                }
            }
        } else {
            // ✅ CRITIQUE: Si aucune date n'a été calculée, activer le bouton quand même après un délai
            // (cas de sécurité pour éviter que l'utilisateur reste bloqué)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.isCountdownFinished = true
                self.onValidationChanged?(true)
            }
        }
    }

    /// Anime la date depuis une date initiale (plus éloignée) vers une date cible (plus proche)
    /// ✅ Retourne la durée de l'animation pour synchroniser avec le compteur de jours
    @discardableResult
    func animateDateFrom(_ fromDate: Date, to toDate: Date, startCountdownCallback: ((TimeInterval) -> Void)? = nil) -> TimeInterval {
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

        // ✅ CRITIQUE: Utiliser une durée fixe de 4.0 secondes pour synchroniser avec le compteur de jours
        // (au lieu d'une durée variable entre 1 et 3 secondes)
        let animationDuration: TimeInterval = 4.0

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

            // ✅ Annuler les tasks précédentes
            dateAnimationTasks.forEach { $0.cancel() }
            dateAnimationTasks.removeAll()

            for (index, day) in daySteps.enumerated() {
                let workItem = DispatchWorkItem {
                    withAnimation(.easeOut(duration: dayStepDuration)) {
                        displayedDay = "\(day)"
                    }
                    // ✅ Vibration exactement une fois par jour qui défile (sauf le premier jour)
                    if index > 0 {
                        HapticManager.shared.impact(.soft)
                    }
                }
                dateAnimationTasks.append(workItem)
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * dayStepDuration, execute: workItem)
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

        // ✅ Démarrer le compteur de jours en même temps que l'animation de date
        // Passer la durée de l'animation au callback pour qu'il puisse synchroniser le compteur
        if let callback = startCountdownCallback {
            callback(animationDuration)
        }

        // Mettre à jour l'affichage final après l'animation
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
            updateDateDisplay(date: toDate)

            // ✅ CRITIQUE: Marquer que l'animation est finie et activer le bouton ICI
            // (au même moment que les vibrations finissent)
            self.isCountdownFinished = true
            self.onValidationChanged?(true)
        }

        return animationDuration
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

        let totalDifference = abs(idealWeight - currentWeight)
        let totalDays = calendar.dateComponents([.day], from: now, to: date).day ?? 30
        let daysInMonth = calendar.dateComponents([.day], from: now, to: oneMonthLater).day ?? 30

        if totalDays > 0 {
            let monthlyProgress = (totalDifference * Double(daysInMonth)) / Double(totalDays)
            let monthlyWeight = String(format: "%.1f", monthlyProgress)

            if weightGoal == .lose {
                monthlyProjectionSecondLine = "tu vas perdre \(monthlyWeight) kg en un mois"
            } else if weightGoal == .gain {
                monthlyProjectionSecondLine = "tu vas prendre \(monthlyWeight) kg en un mois"
            } else {
                monthlyProjectionSecondLine = "tu vas atteindre \(monthlyWeight) kg de progression en un mois"
            }
        } else {
            monthlyProjectionSecondLine = "tu vas atteindre ton objectif rapidement"
        }
    }

    // ✅ Message en bas avec images check
    var bottomMessagesView: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Première ligne : "Basé sur ton profil" avec image check
            HStack(alignment: .top, spacing: 10) {
                Image("check")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)

                Text("Basé sur ton profil")
                    .font(.system(size: 15, weight: .regular)) // ✅ Moins gras
                    .foregroundStyle(OnboardingTheme.bodyText) // ✅ Gris très clair
            }
            .padding(.top, 8) // ✅ Un peu plus haut

            // Deuxième ligne : message de progression avec image check
            if !monthlyProjectionSecondLine.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image("check")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)

                    Text(monthlyProjectionSecondLine)
                        .font(.system(size: 15, weight: .regular)) // ✅ Moins gras
                        .foregroundStyle(OnboardingTheme.bodyText) // ✅ Gris très clair
                }
            }

        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 40)
    }

    // ✅ Fonction pour démarrer l'animation du compte à rebours
    // ✅ totalDuration: durée totale de l'animation (doit correspondre à l'animation de date)
    func startCountdownAnimation(totalDuration: TimeInterval = 4.0) {
        guard let date = projectedDate else {
            // ✅ CRITIQUE: Si pas de date, activer le bouton immédiatement
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isCountdownFinished = true
                self.onValidationChanged?(true)
            }
            return
        }

        // ✅ Annuler la Task précédente si elle existe
        countdownTask?.cancel()

        let calendar = Calendar.current
        let now = Date()
        let daysDifference = calendar.dateComponents([.day], from: now, to: date).day ?? 0

        // ✅ Commencer avec une valeur plus élevée pour l'effet de décompte
        let initialDays = max(daysDifference, Int(Double(daysDifference) * 1.2))
        countdownDays = initialDays

        // ✅ Animer progressivement vers la valeur réelle avec la durée synchronisée
        let steps = abs(initialDays - daysDifference)

        // ✅ Marquer que le compteur n'est pas encore fini (mais ne pas activer le bouton ici)
        // Le bouton sera activé par animateDateFrom() quand les vibrations finissent
        isCountdownFinished = false

        if steps > 0 {
            let stepInterval = totalDuration / Double(steps)
            let direction = initialDays > daysDifference ? -1 : 1

            countdownTask = Task { @MainActor in
                var currentDays = initialDays

                while currentDays != daysDifference {
                    // ✅ Vérifier si la Task a été annulée
                    if Task.isCancelled {
                        return
                    }

                    currentDays += direction

                    withAnimation(.spring(response: 0.15, dampingFraction: 0.8)) {
                        countdownDays = currentDays
                    }

                    // ✅ PAS DE VIBRATION ICI - Les vibrations sont gérées par l'animation de date (animateDateFrom)
                    // PAS DE VIBRATION FINALE ICI - Elle sera gérée par animateDateFrom()

                    try? await Task.sleep(nanoseconds: UInt64(stepInterval * 1_000_000_000))

                    // ✅ Vérifier à nouveau après le sleep
                    if Task.isCancelled {
                        return
                    }
                }

                // ✅ Ne pas activer le bouton ici - il sera activé par animateDateFrom()
                // Le compteur de jours finit, mais le bouton attend que les vibrations finissent aussi
            }
        } else {
            countdownDays = daysDifference
            // ✅ Si pas d'animation, ne pas activer immédiatement si on attend l'animation de date
            // (mais on peut activer si il n'y a pas d'animation de date)
        }
    }
}
