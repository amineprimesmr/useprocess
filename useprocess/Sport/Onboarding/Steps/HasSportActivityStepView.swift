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

    var body: some View {
        OnboardingStandardStepLayout("Pratiques-tu une", "activité sportive actuellement ?") {
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
                        Text(OnboardingCopy.binaryLabels(sportFirst: "Oui", sportSecond: "Non").0)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)

                        Spacer()

                        if hasSportActivity == true {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 20))
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(.white.opacity(0.3))
                                .font(.system(size: 20))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .glassStyle()
                .buttonBorderShape(.roundedRectangle(radius: 16))
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
                        Text(OnboardingCopy.binaryLabels(sportFirst: "Oui", sportSecond: "Non").1)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)

                        Spacer()

                        if hasSportActivity == false {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 20))
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(.white.opacity(0.3))
                                .font(.system(size: 20))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .glassStyle()
                .buttonBorderShape(.roundedRectangle(radius: 16))
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
