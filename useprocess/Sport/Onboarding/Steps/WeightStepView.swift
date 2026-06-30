//
//  WeightStepView.swift
//
//  ✨ Page de saisie du poids avec clavier numérique natif et toggle KG/LBS
//  Structure IDENTIQUE à HeightStepView pour éviter les mouvements avec le clavier
//

import SwiftUI

struct WeightStepView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var profileService: UnifiedProfileService

    @Binding var selectedWeight: Double  // en kg
    var onValidationChanged: ((Bool) -> Void)?
    var onContinue: (() -> Void)?

    @State private var unit: WeightUnit = .kg
    @State private var weightString: String = ""
    @State private var didBootstrap = false
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

    var body: some View {
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

            OnboardingTitleView("Quel est ton poids ?")
                .onboardingTitleOverlay()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            bootstrapIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                restoreWeightStringIfNeeded()
            case .inactive, .background:
                resignKeyboard()
            default:
                break
            }
        }
        .onChange(of: weightString) { _, newValue in
            let filtered = newValue.filter { $0.isNumber || $0 == "." }
            if filtered != newValue {
                weightString = filtered
                return
            }

            let weightValue = Double(newValue) ?? 0
            onValidationChanged?(!newValue.isEmpty && weightValue > 0)
            selectedWeight = displayWeight
        }
        .onDisappear {
            isTextFieldFocused = false
        }
    }

    private func bootstrapIfNeeded() {
        guard !didBootstrap else { return }
        didBootstrap = true
        loadExistingWeight()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isTextFieldFocused = true
        }
    }

    private func restoreWeightStringIfNeeded() {
        guard weightString.isEmpty else { return }
        if OnboardingViewModel.isPlausibleWeight(selectedWeight) {
            populateWeightString(from: selectedWeight)
            onValidationChanged?(true)
        }
    }

    private func resignKeyboard() {
        isTextFieldFocused = false
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    private func handleContinue() {
        let trimmed = weightString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, Double(trimmed) ?? 0 > 0 else { return }

        HapticManager.shared.impact(.medium)

        resignKeyboard()
        onContinue?()

        selectedWeight = displayWeight
        Task.detached(priority: .background) {
            await saveWeight()
        }
    }

    private func loadExistingWeight() {
        if OnboardingViewModel.isPlausibleWeight(selectedWeight) {
            populateWeightString(from: selectedWeight)
        } else if let profile = profileService.currentProfile,
                  OnboardingViewModel.isPlausibleWeight(profile.weight) {
            selectedWeight = profile.weight
            populateWeightString(from: profile.weight)
        } else {
            selectedWeight = 0
            weightString = ""
        }

        let isValid = !weightString.isEmpty && (Double(weightString) ?? 0) > 0
        onValidationChanged?(isValid)
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
        if selectedWeight > 0 {
            if unit == .kg {
                weightString = "\(Int(selectedWeight))"
            } else {
                let lbs = selectedWeight * 2.20462
                weightString = "\(Int(lbs))"
            }
        } else if !weightString.isEmpty {
            let currentValue = Double(weightString) ?? 0
            if unit == .kg {
                let kg = currentValue * 0.453592
                weightString = "\(Int(kg))"
                selectedWeight = kg
            } else {
                let lbs = currentValue * 2.20462
                weightString = "\(Int(lbs))"
                selectedWeight = currentValue
            }
        }
    }

    private func saveWeight() async {
        guard var profile = profileService.currentProfile else { return }
        guard OnboardingViewModel.isPlausibleWeight(selectedWeight) else { return }

        profile.weight = selectedWeight
        do {
            try await profileService.saveProfile(profile)
            await profileService.loadProfile()
        } catch {
            DebugLogger.error("\(error.localizedDescription)")
        }
    }
}
