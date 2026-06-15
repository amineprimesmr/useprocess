//
//  PermissionButton.swift
//  Process
//
//  Created by ENNASRI Amine on 22/09/2025.
//

import SwiftUI

struct PermissionButton: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let isLoading: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: color))
                        .scaleEffect(0.8)
                } else if isGranted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(color)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundStyle(OnboardingTheme.bodyText)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(OnboardingTheme.primaryText)

                    Text(description)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(OnboardingTheme.bodyText)
                }

                Spacer()

                if !isGranted && !isLoading {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(OnboardingTheme.mutedText)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .glassStyle()

        .disabled(isGranted || isLoading)
    }
}
