//
//  GoalProjectionStepView+ComputedProperties.swift
//  Process
//

import SwiftUI

extension GoalProjectionStepView {
    // MARK: - Computed Properties

    var mainProjectionMessage: String {
        if let ideal = idealWeight, primaryGoals.contains(.manageWeight) {
            return "Tu feras \(String(format: "%.0f", ideal)) kg le"
        }

        let message = projectionMessage

        if message.isEmpty {
            return "Tu auras atteint 100% de ton potentiel le"
        }

        // Retirer " d'ici le" suivi de la date (la date est déjà dans les boutons glass)
        if let range = message.range(of: " d'ici le") {
            return String(message[..<range.lowerBound])
        }
        // Retirer la date après " le " mais garder " le" à la fin
        // Le service génère " [objectif] le [date]", on veut garder " [objectif] le"
        if let range = message.range(of: " le ") {
            // Garder tout jusqu'à " le " inclus, puis retirer la date qui suit
            let beforeLe = String(message[..<range.upperBound])
            // La date commence après " le " et va jusqu'à la fin
            return beforeLe.trimmingCharacters(in: .whitespaces)
        }
        return message
    }

    // Graphique avec design exact de ProcessResultsDurabilityStepView
    func graphViewWithDurabilityStyle(for date: Date) -> some View {
        let screenWidth = ScreenMetrics.width - 80
        let currentValue: Double
        let targetValue: Double
        let isWeightGoal: Bool

        if let current = currentWeight, let ideal = idealWeight, primaryGoals.contains(.manageWeight) {
            currentValue = current
            targetValue = ideal
            isWeightGoal = true
        } else {
            currentValue = 0
            targetValue = 100
            isWeightGoal = false
        }

        // ✅ Calculer directement le nombre de jours final (sans animation)
        let calendar = Calendar.current
        let now = Date()
        let finalCountdownDays = max(0, calendar.dateComponents([.day], from: now, to: date).day ?? 0)

        let service = GoalProjectionService.shared
        let curveData = service.generateProgressCurveData(
            startDate: Date(),
            endDate: date,
            currentValue: currentValue,
            targetValue: targetValue,
            isWeightGoal: isWeightGoal,
            weightGoal: weightGoal
        )

        return VStack(spacing: 0) { // ✅ Pas d'espacement pour que le graphique commence au même endroit que l'encadré
            GeometryReader { graphGeometry in
                let width = graphGeometry.size.width > 0 ? graphGeometry.size.width : screenWidth
                let height: CGFloat = 200

                // Convertir curveData en points pour le graphique - SIMPLIFIÉ (seulement 6 points)
                let simplifiedData: [Double] = {
                    if curveData.count <= 6 {
                        return curveData.map { data in
                            let minValue = min(currentValue, targetValue)
                            let maxValue = max(currentValue, targetValue)
                            let valueRange = max(maxValue - minValue, 0.1)
                            return (data.value - minValue) / valueRange
                        }
                    } else {
                        // Prendre seulement 6 points équitablement répartis
                        let step = max(1, curveData.count / 6)
                        return Array(stride(from: 0, to: curveData.count, by: step).prefix(6)).map { index in
                            let data = curveData[index]
                            let minValue = min(currentValue, targetValue)
                            let maxValue = max(currentValue, targetValue)
                            let valueRange = max(maxValue - minValue, 0.1)
                            return (data.value - minValue) / valueRange
                        }
                    }
                }()

                // Calculer les points simplifiés
                // ✅ Si objectif poids : selon le weightGoal (perte = haut→bas, gain = bas→haut)
                // ✅ Si objectif performance : toujours bas→haut (potentiel)
                let isAscending: Bool = {
                    if let weightGoal = weightGoal, primaryGoals.contains(.manageWeight) {
                        // Pour les objectifs de poids, respecter le sens selon le type
                        return (weightGoal == .gain)
                    } else {
                        // Pour les objectifs de performance, toujours monter (potentiel)
                        return true
                    }
                }()
                let allProgressPoints = calculateSimpleSmoothPoints(data: simplifiedData, width: width, height: height, isAscending: isAscending)

                // ✅ Utiliser tous les points pour construire le Path, mais ne dessiner que jusqu'à la progression
                let adjustedProgressPoints = allProgressPoints

                ZStack {
                    // ✨ Rectangle sombre en fond - moins large horizontalement
                    RoundedRectangle(cornerRadius: 20)
                        .fill(OnboardingTheme.graphTooltip)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(OnboardingTheme.mutedFill, lineWidth: 1)
                        )

                    // ✨ Texte "Ta progression" en haut à gauche et compte à rebours en haut à droite
                    VStack {
                        HStack {
                            Text("Ta progression")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(OnboardingTheme.primaryText.opacity(0.85))
                                .padding(.leading, 8) // ✅ Réduit de 16 à 8 pour réduire la largeur
                                .padding(.top, 12)

                            Spacer()

                            // ✅ Compte à rebours dans le graphique, à droite (sans animation, tout en gris)
                            HStack(spacing: 4) {
                                Text("Dans")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(OnboardingTheme.bodyText)

                                Text("\(finalCountdownDays)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(OnboardingTheme.bodyText)

                                Text(finalCountdownDays <= 1 ? "jour" : "jours")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(OnboardingTheme.bodyText)
                            }
                            .padding(.trailing, 8) // ✅ Réduit de 16 à 8 pour réduire la largeur
                            .padding(.top, 12)
                        }
                        Spacer()
                    }

                    // ✨ Lignes horizontales en fond (grille) - seulement les lignes du milieu (1, 2, 3)
                    // ✅ Décalées pour commencer plus près du bord gauche
                    Path { path in
                        for i in 1...3 {
                            let y = height * CGFloat(i) / 4
                            // ✅ Commence exactement au bord gauche (pas de marge)
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: width, y: y))
                        }
                    }
                    .stroke(OnboardingTheme.mutedFill, lineWidth: 1)

                        // ✨ Zone de remplissage sous la courbe (avec gradient violet) - ANIMÉE avec trimmedPath pour synchronisation fluide
                        if !adjustedProgressPoints.isEmpty {
                            Path { path in
                            let bottomOffset: CGFloat = height * 8.0
                            let bottomY = height + bottomOffset

                            path.move(to: CGPoint(x: 0, y: bottomY))

                            // ✅ Construire le chemin COMPLET une seule fois
                            if let firstPoint = adjustedProgressPoints.first {
                                path.addLine(to: CGPoint(x: firstPoint.x, y: firstPoint.y))
                            }

                            // Construire la courbe complète
                            for index in 1..<adjustedProgressPoints.count {
                                let point = adjustedProgressPoints[index]
                                let prevPoint = adjustedProgressPoints[index - 1]
                                let controlPoint1 = CGPoint(
                                    x: prevPoint.x + (point.x - prevPoint.x) / 3,
                                    y: prevPoint.y
                                )
                                let controlPoint2 = CGPoint(
                                    x: point.x - (point.x - prevPoint.x) / 3,
                                    y: point.y
                                )
                                path.addCurve(to: point, control1: controlPoint1, control2: controlPoint2)
                            }

                            // Fermer le chemin
                            if let lastPoint = adjustedProgressPoints.last {
                                path.addLine(to: CGPoint(x: lastPoint.x, y: bottomY))
                            }

                            path.addLine(to: CGPoint(x: 0, y: bottomY))
                            path.closeSubpath()
                        }
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: Color(red: 0.7, green: 0.55, blue: 0.85).opacity(0.7), location: 0.0),
                                    .init(color: Color(red: 0.5, green: 0.3, blue: 0.7).opacity(0.9), location: 0.4),
                                    .init(color: Color(red: 0.4, green: 0.2, blue: 0.6).opacity(1.0), location: 0.5),
                                    .init(color: Color(red: 0.5, green: 0.3, blue: 0.7).opacity(0.6), location: 0.6),
                                    .init(color: Color(red: 0.6, green: 0.4, blue: 0.8).opacity(0.3), location: 0.75),
                                    .init(color: Color.clear, location: 1.0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .mask(
                            // ✅ Masque progressif qui suit exactement la progression de la courbe
                            GeometryReader { maskGeometry in
                                HStack(spacing: 0) {
                                    Rectangle()
                                        .fill(OnboardingTheme.primaryText)
                                        .frame(width: maskGeometry.size.width * curveAnimationProgress)
                                    Spacer()
                                }
                            }
                        )
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .white, location: 0.0),
                                    .init(color: .white.opacity(0.8), location: 0.6),
                                    .init(color: .white.opacity(0.3), location: 0.85),
                                    .init(color: .clear, location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        // ✨ OMBRE SOUS LA COURBE - ANIMÉE avec trimmedPath pour animation fluide
                        if !adjustedProgressPoints.isEmpty {
                            Path { path in
                                // ✅ Construire le chemin COMPLET une seule fois
                                for index in 0..<adjustedProgressPoints.count {
                                    let point = adjustedProgressPoints[index]
                                    let adjustedPoint = CGPoint(x: point.x, y: point.y + 2)
                                    if index == 0 {
                                        path.move(to: adjustedPoint)
                                    } else {
                                        let prevPoint = adjustedProgressPoints[index - 1]
                                        let prevAdjustedPoint = CGPoint(x: prevPoint.x, y: prevPoint.y + 2)
                                        let controlPoint1 = CGPoint(
                                            x: prevAdjustedPoint.x + (adjustedPoint.x - prevAdjustedPoint.x) / 3,
                                            y: prevAdjustedPoint.y
                                        )
                                        let controlPoint2 = CGPoint(
                                            x: adjustedPoint.x - (adjustedPoint.x - prevAdjustedPoint.x) / 3,
                                            y: adjustedPoint.y
                                        )
                                        path.addCurve(to: adjustedPoint, control1: controlPoint1, control2: controlPoint2)
                                    }
                                }
                            }
                            .trimmedPath(from: 0, to: curveAnimationProgress) // ✅ Utiliser trimmedPath pour animation fluide et continue
                            .stroke(
                                OnboardingTheme.graphTooltip,
                                style: StrokeStyle(lineWidth: 5, lineCap: .square, lineJoin: .round) // ✅ .square au lieu de .round pour éviter l'arrondi au début
                            )
                            .blur(radius: 3)
                        }

                        // ✨ Courbe principale avec gradient violet - ANIMÉE avec trimmedPath pour animation fluide
                        if !adjustedProgressPoints.isEmpty {
                            Path { path in
                                // ✅ Construire le chemin COMPLET une seule fois
                                for index in 0..<adjustedProgressPoints.count {
                                    let point = adjustedProgressPoints[index]
                                    if index == 0 {
                                        path.move(to: point)
                                    } else {
                                        let prevPoint = adjustedProgressPoints[index - 1]
                                        let controlPoint1 = CGPoint(
                                            x: prevPoint.x + (point.x - prevPoint.x) / 3,
                                            y: prevPoint.y
                                        )
                                        let controlPoint2 = CGPoint(
                                            x: point.x - (point.x - prevPoint.x) / 3,
                                            y: point.y
                                        )
                                        path.addCurve(to: point, control1: controlPoint1, control2: controlPoint2)
                                    }
                                }
                            }
                            .trimmedPath(from: 0, to: curveAnimationProgress) // ✅ Utiliser trimmedPath pour animation fluide et continue
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.77, green: 0.64, blue: 0.97),
                                        Color(red: 0.6, green: 0.4, blue: 0.8),
                                        Color(red: 0.42, green: 0.05, blue: 0.51)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: 5, lineCap: .square, lineJoin: .round) // ✅ .square au lieu de .round pour éviter l'arrondi au début
                            )
                        }

                        // ✨ TRAIT BLANC LÉGER SUR LE DESSUS DE LA COURBE - ANIMÉE avec trimmedPath pour animation fluide
                        if !adjustedProgressPoints.isEmpty {
                            Path { path in
                                // ✅ Construire le chemin COMPLET une seule fois
                                for index in 0..<adjustedProgressPoints.count {
                                    let point = adjustedProgressPoints[index]
                                    let adjustedPoint = CGPoint(x: point.x, y: point.y - 2)
                                    if index == 0 {
                                        path.move(to: adjustedPoint)
                                    } else {
                                        let prevPoint = adjustedProgressPoints[index - 1]
                                        let prevAdjustedPoint = CGPoint(x: prevPoint.x, y: prevPoint.y - 2)
                                        let controlPoint1 = CGPoint(
                                            x: prevAdjustedPoint.x + (adjustedPoint.x - prevAdjustedPoint.x) / 3,
                                            y: prevAdjustedPoint.y
                                        )
                                        let controlPoint2 = CGPoint(
                                            x: adjustedPoint.x - (adjustedPoint.x - prevAdjustedPoint.x) / 3,
                                            y: adjustedPoint.y
                                        )
                                        path.addCurve(to: adjustedPoint, control1: controlPoint1, control2: controlPoint2)
                                    }
                                }
                            }
                            .trimmedPath(from: 0, to: curveAnimationProgress) // ✅ Utiliser trimmedPath pour animation fluide et continue
                            .stroke(
                                OnboardingTheme.softBorder,
                                style: StrokeStyle(lineWidth: 1, lineCap: .square, lineJoin: .round) // ✅ .square au lieu de .round pour éviter l'arrondi au début
                            )
                        }

                        // ✨ Point blanc à la fin de la courbe - ANIMÉE (apparaît uniquement à la fin de l'animation)
                        if curveAnimationProgress >= 1.0, let lastPoint = adjustedProgressPoints.last {
                            Circle()
                                .fill(OnboardingTheme.primaryText)
                                .frame(width: 12, height: 12)
                                .position(lastPoint)
                        }
                    }
                }
                .animation(nil, value: curveAnimationProgress)
            }
            .frame(height: 200)
            // ✅ Pas de padding horizontal pour que le graphique commence au même endroit que l'encadré

            // Labels "Aujourd'hui" et le mois sous le rectangle
            HStack {
                Text("Aujourd'hui")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(OnboardingTheme.footnoteText)
                    .padding(.leading, 4) // ✅ Plus à gauche (réduit de 20 à 4)
                Spacer()
                Text(formatMonth(date))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(OnboardingTheme.footnoteText)
                    .padding(.trailing, 20) // ✅ Plus à droite
            }
            .padding(.horizontal, 8)
            .padding(.top, 8) // ✅ Plus bas (augmenté de -4 à 8)
        }
        .padding(.horizontal, 40)
    }

    // ✅ Fonction pour calculer les points simplifiés
    // ✅ isAscending: true = commence en bas finit en haut (potentiel/prise de poids), false = commence en haut finit en bas (perte de poids)
    // ✅ Ajout de variations pour rendre la courbe moins régulière et plus réaliste
    func calculateSimpleSmoothPoints(data: [Double], width: CGFloat, height: CGFloat, isAscending: Bool = false) -> [CGPoint] {
        guard !data.isEmpty else { return [] }

        // ✅ Pas de padding horizontal - la courbe commence exactement au bord gauche (x = 0)
        let usableWidth = width
        let stepWidth = usableWidth / CGFloat(max(1, data.count - 1))
        var points: [CGPoint] = []

        // ✅ Fonction pour générer une variation aléatoire mais déterministe basée sur l'index
        func randomVariation(for index: Int) -> CGFloat {
            // Utiliser un générateur pseudo-aléatoire basé sur l'index pour la reproductibilité
            let seed = Double(index) * 0.314159 + Double(index * index) * 0.123456
            let variation1 = sin(seed) * cos(seed * 2.5) // Variation entre -1 et 1
            let variation2 = sin(seed * 1.7) * cos(seed * 3.1) // Variation supplémentaire pour plus d'irrégularité
            let combinedVariation = (variation1 + variation2 * 0.5) / 1.5 // Combiner les variations
            return CGFloat(combinedVariation) * 25.0 // ✅ Variation max augmentée de 15 à 25 points pour plus d'irrégularité
        }

        // ✅ Direction de la courbe selon isAscending
        // isAscending = false : premier point en haut (normalizedValue = 0), dernier en bas (normalizedValue = 1)
        // isAscending = true : premier point en bas (normalizedValue = 1), dernier en haut (normalizedValue = 0)
        for (index, _) in data.enumerated() {
            let x: CGFloat
            // ✅ Commence exactement au bord gauche (0), même pour le premier point)
            if index == 0 {
                x = 0
            } else {
                x = CGFloat(index) * stepWidth
            }
            // Normaliser par l'index
            let normalizedValue = data.count > 1 ? Double(index) / Double(data.count - 1) : 0.0
            // ✅ Inverser la normalisation si isAscending (pour commencer en bas et finir en haut)
            let adjustedNormalizedValue = isAscending ? (1.0 - normalizedValue) : normalizedValue
            // ✅ AJOUT: Variation pour rendre la courbe moins régulière
            let baseY = (CGFloat(adjustedNormalizedValue) * height * 0.75) + (height * 0.20)
            // ✅ Plus de variation au milieu, moins aux extrémités pour garder le réalisme
            // ✅ Augmenter le facteur de variation pour plus d'irrégularité
            let variationFactor = sin(adjustedNormalizedValue * .pi) // 0 aux extrémités, 1 au milieu
            let additionalVariation = sin(Double(index) * 0.7) * cos(Double(index) * 1.3) * 8.0 // Variation supplémentaire
            let variation = randomVariation(for: index) * CGFloat(variationFactor) + CGFloat(additionalVariation)
            let y = baseY + variation

            points.append(CGPoint(x: x, y: min(height * 0.95, max(height * 0.20, y))))
        }

        return points
    }

    func formatMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "MMMM"
        return formatter.string(from: date).capitalized
    }


}
