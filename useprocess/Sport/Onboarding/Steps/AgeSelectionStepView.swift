//
//  AgeSelectionStepView.swift
//  Process
//
//  Page de sélection d'âge avec roulette scrollable ultra fluide
//

import SwiftUI

struct AgeSelectionStepView: View {
    @Binding var selectedAge: Int
    @State private var didInitializeUI = false

    var onValidationChanged: ((Bool) -> Void)?

    private let minAge = 13
    private let maxAge = 100
    private let defaultAge = 25

    @EnvironmentObject var profileService: UnifiedProfileService

    var body: some View {
        OnboardingStandardStepLayout(title: OnboardingCopy.t("Quel est ton âge ?", en: "How old are you?")) {
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 40)

                AgeWheelPicker(
                    selectedAge: $selectedAge,
                    minAge: minAge,
                    maxAge: maxAge,
                    onAgeChanged: { newAge in
                        HapticManager.shared.selection()
                        onValidationChanged?(true)

                        Task {
                            try? await Task.sleep(nanoseconds: 500_000_000)
                            if selectedAge == newAge {
                                await OnboardingProgressService.shared.saveAge(newAge, to: profileService)
                            }
                        }
                    }
                )
                .padding(.horizontal, 40)

                Spacer()
            }
        }
        .onAppear {
            guard !didInitializeUI else {
                onValidationChanged?(selectedAge >= minAge && selectedAge <= maxAge)
                return
            }
            didInitializeUI = true

            if selectedAge < minAge || selectedAge > maxAge {
                selectedAge = defaultAge
            }

            onValidationChanged?(selectedAge >= minAge && selectedAge <= maxAge)
        }
    }
}
