//
//  IdealWeightStepView.swift
//  Process
//
//  Saisie du poids idéal avec recommandation basée sur IMC, taille, âge et genre.
//

import SwiftUI

struct IdealWeightStepView: View {
    @EnvironmentObject var profileService: UnifiedProfileService
    @EnvironmentObject var healthManager: HealthManager
    @Binding var idealWeight: Double

    let currentWeight: Double
    let height: Double
    let weightGoal: WeightGoal?
    let firstName: String

    var onValidationChanged: ((Bool) -> Void)?

    @State private var weightString: String = ""
    @FocusState private var isTextFieldFocused: Bool

    private var profile: UnifiedUserProfile? {
        profileService.currentProfile
    }

    private var age: Int {
        profile?.age ?? 25
    }

    private var gender: Gender {
        profile?.gender ?? .male
    }

    private var currentBodyComposition: BodyComposition {
        BodyCompositionEstimate.calculate(
            height: height,
            weight: currentWeight,
            age: age,
            gender: gender
        )
    }

    private var recommendedWeight: Double {
        PersonalizedIdealWeightCalculator.calculatePersonalizedIdealWeight(
            currentWeight: currentWeight,
            height: height,
            age: age,
            gender: gender,
            weightGoal: weightGoal ?? effectiveWeightGoal,
            bodyFatPercentage: currentBodyComposition.bodyFatPercentage,
            leanBodyMass: currentBodyComposition.leanMass,
            bodyComposition: currentBodyComposition
        )
    }

    private var displayWeightString: String {
        weightString
    }

    private var effectiveWeightGoal: WeightGoal? {
        if let weightGoal { return weightGoal }
        guard let weight = Double(weightString), weight > 0 else { return nil }
        if weight < currentWeight { return .lose }
        if weight > currentWeight { return .gain }
        return nil
    }

    private var isValidWeight: Bool {
        guard !weightString.isEmpty else { return false }
        guard let weight = Double(weightString), weight > 0 else { return false }

        if let goal = effectiveWeightGoal {
            switch goal {
            case .lose:
                return weight < currentWeight && weight >= 35
            case .gain:
                return weight > currentWeight && weight <= 200
            }
        }
        return weight >= 35 && weight <= 200 && weight != currentWeight
    }

    init(
        idealWeight: Binding<Double> = .constant(70.0),
        currentWeight: Double = 70.0,
        height: Double = 175.0,
        weightGoal: WeightGoal? = nil,
        firstName: String = "",
        onValidationChanged: ((Bool) -> Void)? = nil
    ) {
        self._idealWeight = idealWeight
        self.currentWeight = currentWeight
        self.height = height
        self.weightGoal = weightGoal
        self.firstName = firstName
        self.onValidationChanged = onValidationChanged
    }

    var body: some View {
        ScrollView {
            OnboardingStandardStepLayout("Quel est ton", "poids idéal ?") {
                VStack(spacing: 0) {
                    Text("Poids recommandé : \(Int(recommendedWeight)) kg")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.top, 8)

                    ZStack {
                        TextField("", text: $weightString)
                            .font(.system(size: 56, weight: .bold))
                            .foregroundColor(.clear)
                            .multilineTextAlignment(.center)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(PlainTextFieldStyle())
                            .focused($isTextFieldFocused)

                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(displayWeightString.isEmpty ? "" : displayWeightString)
                                .font(.system(size: 56, weight: .bold))
                                .foregroundColor(.white)
                                .shadow(color: .white.opacity(0.4), radius: 12, x: 0, y: 0)
                                .shadow(color: .white.opacity(0.2), radius: 20, x: 0, y: 0)
                                .contentTransition(.numericText())
                                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: weightString)

                            if !displayWeightString.isEmpty {
                                Text("kg")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
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
        }
        .scrollDisabled(true)
        .scrollDismissesKeyboard(.never)
        .onAppear {
            loadExistingIdealWeight()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextFieldFocused = true
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
                Task { await saveIdealWeight(weight) }
            }

            onValidationChanged?(isValidWeight)
        }
    }

    private func loadExistingIdealWeight() {
        if idealWeight > 0 {
            weightString = formatIdealWeight(idealWeight)
        } else if let profile = profileService.currentProfile,
                  let ideal = profile.idealWeight,
                  ideal > 0 {
            idealWeight = ideal
            weightString = formatIdealWeight(ideal)
        } else {
            weightString = ""
        }
        onValidationChanged?(isValidWeight)
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
