//
//  IdealWeightStepView.swift
//  Process
//
//  Saisie du poids idéal avec recommandation stable (basée sur le profil onboarding).
//

import SwiftUI

struct IdealWeightStepView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var profileService: UnifiedProfileService

    @Binding var idealWeight: Double

    let currentWeight: Double
    let height: Double
    let age: Int
    let gender: Gender
    let weightGoal: WeightGoal?
    let firstName: String

    var onValidationChanged: ((Bool) -> Void)?
    var onPersistAnswers: (() -> Void)?

    @State private var weightString: String = ""
    @State private var recommendedWeight: Double = 0
    @State private var didInitialize = false
    @State private var saveTask: Task<Void, Never>?
    @FocusState private var isTextFieldFocused: Bool

    private var currentBodyComposition: BodyComposition {
        BodyCompositionEstimate.calculate(
            height: height,
            weight: max(currentWeight, 1),
            age: age,
            gender: gender
        )
    }

    private var isValidWeight: Bool {
        guard !weightString.isEmpty else { return false }
        guard let weight = Double(weightString), weight >= 35, weight <= 200 else { return false }
        guard currentWeight > 0 else { return weight > 0 }
        return abs(weight - currentWeight) >= 0.5
    }

    init(
        idealWeight: Binding<Double> = .constant(70.0),
        currentWeight: Double = 70.0,
        height: Double = 175.0,
        age: Int = 25,
        gender: Gender = .male,
        weightGoal: WeightGoal? = nil,
        firstName: String = "",
        onValidationChanged: ((Bool) -> Void)? = nil,
        onPersistAnswers: (() -> Void)? = nil
    ) {
        self._idealWeight = idealWeight
        self.currentWeight = currentWeight
        self.height = height
        self.age = age
        self.gender = gender
        self.weightGoal = weightGoal
        self.firstName = firstName
        self.onValidationChanged = onValidationChanged
        self.onPersistAnswers = onPersistAnswers
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: OnboardingConstants.titleTopPadding)

                VStack(spacing: 8) {
                    OnboardingTitleView("Quel est ton", "poids idéal ?")

                    if recommendedWeight > 0 {
                        Text("Poids recommandé : \(Int(recommendedWeight.rounded())) kg")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(OnboardingTheme.footnoteText)
                            .multilineTextAlignment(.center)
                            .animation(nil, value: recommendedWeight)
                    }
                }
                .padding(.horizontal, 40)

                Spacer()
                    .frame(height: OnboardingConstants.titleToContentSpacing)

                ZStack {
                    TextField("", text: $weightString)
                        .font(.system(size: 56, weight: .bold))
                        .foregroundColor(.clear)
                        .multilineTextAlignment(.center)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(PlainTextFieldStyle())
                        .focused($isTextFieldFocused)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(weightString.isEmpty ? "" : weightString)
                            .font(.system(size: 56, weight: .bold))
                            .foregroundStyle(OnboardingTheme.primaryText)
                            .onboardingValueGlow(colorScheme: colorScheme)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: weightString)

                        if !weightString.isEmpty {
                            Text("kg")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(OnboardingTheme.bodyText)
                        }
                    }
                    .allowsHitTesting(false)
                }
                .padding(.horizontal, 40)
                .onTapGesture {
                    isTextFieldFocused = true
                }

                Spacer()
            }
            .frame(minHeight: ScreenMetrics.height)
        }
        .scrollDisabled(true)
        .scrollDismissesKeyboard(.never)
        .onAppear {
            initializeIfNeeded()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextFieldFocused = true
            }
            OnboardingValidationScheduler.deferValidation {
                onValidationChanged?(isValidWeight)
            }
        }
        .onChange(of: idealWeight) { _, newValue in
            guard newValue > 0 else { return }
            let formatted = formatIdealWeight(newValue)
            if weightString.isEmpty || weightString != formatted {
                weightString = formatted
            }
            OnboardingValidationScheduler.deferValidation {
                onValidationChanged?(isValidWeight)
            }
        }
        .onChange(of: weightString) { _, newValue in
            let filtered = newValue.filter { $0.isNumber || $0 == "." }
            if filtered != newValue {
                weightString = filtered
                return
            }

            if let weight = Double(newValue), weight > 0 {
                idealWeight = weight
                scheduleSave(weight)
                onPersistAnswers?()
            }

            OnboardingValidationScheduler.deferValidation {
                onValidationChanged?(isValidWeight)
            }
        }
        .onDisappear {
            saveTask?.cancel()
            isTextFieldFocused = false
        }
    }

    // MARK: - Init & persistance

    private func initializeIfNeeded() {
        guard !didInitialize else { return }
        didInitialize = true

        recommendedWeight = computeStableRecommendation()

        if OnboardingViewModel.isPlausibleWeight(idealWeight) {
            weightString = formatIdealWeight(idealWeight)
        } else if let profile = profileService.currentProfile,
                  let ideal = profile.idealWeight,
                  OnboardingViewModel.isPlausibleWeight(ideal) {
            idealWeight = ideal
            weightString = formatIdealWeight(ideal)
        } else {
            idealWeight = 0
            weightString = ""
        }
    }

    /// Recommandation figée à l’ouverture — ne dépend pas de la saisie en cours.
    private func computeStableRecommendation() -> Double {
        guard height > 0, currentWeight > 0 else { return 0 }

        return PersonalizedIdealWeightCalculator.calculatePersonalizedIdealWeight(
            currentWeight: currentWeight,
            height: height,
            age: age,
            gender: gender,
            weightGoal: weightGoal,
            bodyFatPercentage: currentBodyComposition.bodyFatPercentage,
            leanBodyMass: currentBodyComposition.leanMass,
            bodyComposition: currentBodyComposition
        )
    }

    private func scheduleSave(_ weight: Double) {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            await saveIdealWeight(weight)
        }
    }

    private func formatIdealWeight(_ weight: Double) -> String {
        let rounded = weight.rounded()
        if abs(weight - rounded) < 0.01 {
            return "\(Int(rounded))"
        }
        return String(format: "%.1f", weight)
    }

    private func saveIdealWeight(_ weight: Double) async {
        guard var profile = profileService.currentProfile else { return }
        profile.idealWeight = weight
        try? await profileService.saveProfile(profile)
    }
}
