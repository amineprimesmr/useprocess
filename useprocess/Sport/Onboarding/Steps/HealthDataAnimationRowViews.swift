//
//  HealthDataAnimationRowViews.swift
//  Process
//
//  Lignes liste sources / données (extrait de HealthDataAnimationStepView).
//

import SwiftUI

// ✨ Vue pour une ligne de source de données (même style que DataItemRowView)
struct SourceDataItemRowView: View {
    let source: String
    let isLoading: Bool
    let isCompleted: Bool

    var body: some View {
        HStack(spacing: 16) {
            // Nom
            Text(source)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(OnboardingTheme.narrativeText)
                .multilineTextAlignment(.leading)

            Spacer()

            // État : chargement ou check vert
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: OnboardingTheme.primaryText))
                    .scaleEffect(0.7)
            } else if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color(red: 0.13, green: 0.98, blue: 0.47))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(OnboardingTheme.subtleFill)
        )
    }
}

// ✨ Vue pour une ligne de données (DATA section)
struct DataItemRowView: View {
    let item: HealthDataAnimationStepView.DataItem
    let isLoading: Bool
    let isCompleted: Bool

    var body: some View {
        HStack(spacing: 16) {
            // Icône (optionnelle, peut être vide)
            if !item.icon.isEmpty {
                Image(systemName: item.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(OnboardingTheme.bodyText)
                    .frame(width: 20, height: 20)
            }

            // Nom
            Text(item.name)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(OnboardingTheme.narrativeText)
                .multilineTextAlignment(.leading)

            Spacer()

            // État : chargement, check vert, pending ou barre de progression
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: OnboardingTheme.primaryText))
                    .scaleEffect(0.7)
            } else if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color(red: 0.13, green: 0.98, blue: 0.47))
            } else if item.isPending {
                Image(systemName: "star.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(OnboardingTheme.mutedText)
            } else if item.hasProgress {
                // Barre de progression horizontale
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(OnboardingTheme.softFill)
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(red: 0.13, green: 0.98, blue: 0.47))
                            .frame(width: geometry.size.width * 0.6, height: 4)
                    }
                }
                .frame(width: 60, height: 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(OnboardingTheme.subtleFill)
        )
    }
}
