//
//  HasSportActivityStepView.swift
//  Process
//
//  Page : Pratiques-tu une activité sportive ? (Oui/Non)
//

import SwiftUI

struct HasSportActivityStepView: View {
    @EnvironmentObject var profileService: UnifiedProfileService
    @Binding var hasSportActivity: Bool?

    var onValidationChanged: ((Bool) -> Void)?

    private let choiceShape = RoundedRectangle(cornerRadius: 16, style: .continuous)

    var body: some View {
        OnboardingStandardStepLayout(
            OnboardingCopy.t("Pratiques-tu une", en: "Do you currently"),
            OnboardingCopy.t("activité sportive actuellement ?", en: "play any sports?")
        ) {
            VStack(spacing: 20) {
                Button(action: {
                    HapticManager.shared.selection()
                    hasSportActivity = true
                    onValidationChanged?(true)

                    Task {
                        if let profile = profileService.currentProfile {
                            try? await profileService.saveProfile(profile)
                        }
                    }
                }) {
                    HStack(spacing: 12) {
                        Text(OnboardingCopy.binaryLabels(frFirst: "Oui", frSecond: "Non", enFirst: "Yes", enSecond: "No").0)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(OnboardingTheme.primaryText)

                        Spacer()

                        if hasSportActivity == true {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 20))
                        } else {
                            Image(systemName: "circle")
                                .foregroundStyle(OnboardingTheme.mutedText)
                                .font(.system(size: 20))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .processGlassButton(in: choiceShape)
                .opacity(hasSportActivity == true ? 1.0 : 0.6)

                Button(action: {
                    HapticManager.shared.selection()
                    hasSportActivity = false
                    onValidationChanged?(true)

                    Task {
                        if let profile = profileService.currentProfile {
                            try? await profileService.saveProfile(profile)
                        }
                    }
                }) {
                    HStack(spacing: 12) {
                        Text(OnboardingCopy.binaryLabels(frFirst: "Oui", frSecond: "Non", enFirst: "Yes", enSecond: "No").1)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(OnboardingTheme.primaryText)

                        Spacer()

                        if hasSportActivity == false {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 20))
                        } else {
                            Image(systemName: "circle")
                                .foregroundStyle(OnboardingTheme.mutedText)
                                .font(.system(size: 20))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .processGlassButton(in: choiceShape)
                .opacity(hasSportActivity == false ? 1.0 : 0.6)
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .onAppear {
            OnboardingValidationScheduler.deferValidation {
                onValidationChanged?(hasSportActivity != nil)
            }
        }
}
}
