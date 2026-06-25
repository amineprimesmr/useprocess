//
//  IdealWeightStepView.swift
//  Process
//
//  Saisie du poids idéal — même UX que WeightStepView (clavier, toggle KG/LBS, overlay titre).
//

import SwiftUI

struct IdealWeightStepView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var profileService: UnifiedProfileService

    @Binding var idealWeight: Double
    let currentWeight: Double
    let recommendedIdealWeight: Double?

    var onValidationChanged: ((Bool) -> Void)?
    var onContinue: (() -> Void)?
    var onPersistAnswers: (() -> Void)?

    @State private var unit: WeightUnit = .kg
    @State private var weightString: String = ""
    @FocusState private var isTextFieldFocused: Bool

    enum WeightUnit {
        case kg
        case lbs

        var displayName: String {
            switch self {
            case .kg: return "KG"
            case .lbs: return "LBS"
            }
        }
    }

    private var displayWeight: Double {
        if weightString.isEmpty {
            return 0
        }
        let value = Double(weightString) ?? 0
        return unit == .kg ? value : value * 0.453592
    }

    private var displayWeightString: String {
        if weightString.isEmpty {
            return ""
        }
        return weightString
    }

    private var isValidWeight: Bool {
        guard !weightString.isEmpty else { return false }

        let weightKg = displayWeight
        guard weightKg > 0, weightKg >= 35, weightKg <= 200 else { return false }
        guard OnboardingViewModel.isPlausibleWeight(currentWeight) else { return true }
        return abs(weightKg - currentWeight) >= 0.5
    }

    init(
        idealWeight: Binding<Double>,
        currentWeight: Double,
        recommendedIdealWeight: Double? = nil,
        onValidationChanged: ((Bool) -> Void)? = nil,
        onContinue: (() -> Void)? = nil,
        onPersistAnswers: (() -> Void)? = nil
    ) {
        self._idealWeight = idealWeight
        self.currentWeight = currentWeight
        self.recommendedIdealWeight = recommendedIdealWeight
        self.onValidationChanged = onValidationChanged
        self.onContinue = onContinue
        self.onPersistAnswers = onPersistAnswers
    }

    var body: some View {
        ScrollView {
            ZStack {
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: OnboardingConstants.titleAreaHeight)

                    Spacer()
                        .frame(height: OnboardingConstants.titleToContentSpacing)

                    OnboardingUnitSegmentToggle(
                        leftLabel: "KG",
                        rightLabel: "LBS",
                        isLeftSelected: Binding(
                            get: { unit == .kg },
                            set: { unit = $0 ? .kg : .lbs }
                        )
                    )
                    .padding(.bottom, 60)
                    .onChange(of: unit) { _, _ in
                        convertWeight()
                    }

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
                            .onSubmit {
                                handleContinue()
                            }

                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(displayWeightString)
                                .font(.system(size: 56, weight: .bold))
                                .foregroundStyle(OnboardingTheme.primaryText)
                                .onboardingValueGlow(colorScheme: colorScheme)
                                .contentTransition(.numericText())
                                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: weightString)

                            Text(unit == .kg ? "kg" : "lbs")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(OnboardingTheme.bodyText)
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

                VStack {
                    OnboardingTitleView("Quel est ton poids idéal ?")
                        .padding(.top, OnboardingConstants.titleTopPadding)
                    Spacer()
                }
            }
        }
        .scrollDisabled(true)
        .scrollDismissesKeyboard(.never)
        .onAppear {
            loadExistingWeight()
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

            let weightValue = Double(newValue) ?? 0
            onValidationChanged?(isValidWeight)
            idealWeight = displayWeight

            if weightValue > 0 {
                onPersistAnswers?()
            }
        }
        .onDisappear {
            isTextFieldFocused = false
        }
    }

    private func handleContinue() {
        let trimmed = weightString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, Double(trimmed) ?? 0 > 0, isValidWeight else { return }

        HapticManager.shared.impact(.medium)

        isTextFieldFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

        onContinue?()

        idealWeight = displayWeight
        Task.detached(priority: .background) {
            await saveIdealWeight()
        }
    }

    private func loadExistingWeight() {
        if OnboardingViewModel.isPlausibleWeight(idealWeight) {
            populateWeightString(from: idealWeight)
        } else if let profile = profileService.currentProfile,
                  let savedIdeal = profile.idealWeight,
                  OnboardingViewModel.isPlausibleWeight(savedIdeal) {
            idealWeight = savedIdeal
            populateWeightString(from: savedIdeal)
        } else if let recommendedIdealWeight,
                  OnboardingViewModel.isPlausibleWeight(recommendedIdealWeight) {
            idealWeight = recommendedIdealWeight
            populateWeightString(from: recommendedIdealWeight)
        } else {
            idealWeight = 0
            weightString = ""
        }

        onValidationChanged?(isValidWeight)
    }

    private func populateWeightString(from weightKg: Double) {
        if unit == .kg {
            weightString = formatWeight(weightKg)
        } else {
            weightString = formatWeight(weightKg * 2.20462)
        }
    }

    private func formatWeight(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(value - rounded) < 0.01 {
            return "\(Int(rounded))"
        }
        return String(format: "%.1f", value)
    }

    private func convertWeight() {
        if idealWeight > 0 {
            if unit == .kg {
                weightString = formatWeight(idealWeight)
            } else {
                let lbs = idealWeight * 2.20462
                weightString = formatWeight(lbs)
            }
        } else if !weightString.isEmpty {
            let currentValue = Double(weightString) ?? 0
            if unit == .kg {
                let kg = currentValue * 0.453592
                weightString = formatWeight(kg)
                idealWeight = kg
            } else {
                let lbs = currentValue * 2.20462
                weightString = formatWeight(lbs)
                idealWeight = currentValue
            }
        }

        onValidationChanged?(isValidWeight)
    }

    private func saveIdealWeight() async {
        guard var profile = profileService.currentProfile else { return }
        guard OnboardingViewModel.isPlausibleWeight(idealWeight) else { return }

        profile.idealWeight = idealWeight
        do {
            try await profileService.saveProfile(profile)
            await profileService.loadProfile()
        } catch {
            DebugLogger.error("\(error.localizedDescription)")
        }
    }
}
