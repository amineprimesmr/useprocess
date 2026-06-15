//
//  GoalProjectionStepView+ContentViews.swift
//  Process
//

import SwiftUI

extension GoalProjectionStepView {
    // MARK: - Computed Views

    func mainContent(geometry: GeometryProxy?) -> some View {
        EstimationStepLayout(
            titleMessage: mainProjectionMessage,
            displayDay: currentDisplayDay,
            displayMonth: currentDisplayMonth,
            graph: {
                if let date = projectedDate {
                    graphViewWithDurabilityStyle(for: date)
                }
            },
            bottom: {
                bottomMessagesView
            }
        )
    }

    // ✅ CORRIGÉ: Afficher toujours une valeur (jamais vide)
    var currentDisplayDay: String {
        if !displayedDay.isEmpty { return displayedDay }
        if !dayOnly.isEmpty { return dayOnly }
        if let date = projectedDate {
            return "\(Calendar.current.component(.day, from: date))"
        }
        return "..."
    }

    var currentDisplayMonth: String {
        if !displayedMonth.isEmpty { return displayedMonth }
        if !monthOnly.isEmpty { return monthOnly }
        if let date = projectedDate {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "fr_FR")
            formatter.dateFormat = "MMMM"
            return formatter.string(from: date).capitalized
        }
        return "..."
    }

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
                    .foregroundColor(.white.opacity(0.7)) // ✅ Gris très clair
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
                        .foregroundColor(.white.opacity(0.7)) // ✅ Gris très clair
                }
            }

        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 40)
    }


}
