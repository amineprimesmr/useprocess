//
//  IdealWeightStepView.swift
//  Process
//
//  Saisie du poids idéal — même UX que WeightStepView (clavier, toggle KG/LBS, overlay titre).
//

import SwiftUI
import UIKit

struct IdealWeightStepView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var profileService: UnifiedProfileService

    @Binding var idealWeight: Double
    let currentWeight: Double
    let recommendedIdealWeight: Double?

    var onValidationChanged: ((Bool) -> Void)?
    var onContinue: (() -> Void)?
    var onPersistAnswers: (() -> Void)?

    @State private var unit: WeightUnit = ProcessMeasurementPreference.prefersImperial ? .lbs : .kg
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

    private var numericFieldWidth: CGFloat {
        let sample = displayWeightString.isEmpty ? "0" : displayWeightString
        let font = UIFont.systemFont(ofSize: 56, weight: .bold)
        let measured = (sample as NSString).size(withAttributes: [.font: font]).width
        return ceil(max(42, measured + 10))
    }

    private var isValidWeight: Bool {
        guard !weightString.isEmpty else { return false }

        let weightKg = displayWeight
        guard weightKg > 0, weightKg >= 35, weightKg <= 200 else { return false }
        return isDistinctFromCurrentWeight(weightKg)
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

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    TextField("", text: $weightString)
                        .font(.system(size: 56, weight: .bold))
                        .foregroundStyle(OnboardingTheme.primaryText)
                        .tint(OnboardingTheme.primaryText)
                        .multilineTextAlignment(.center)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(PlainTextFieldStyle())
                        .frame(width: numericFieldWidth)
                        .focused($isTextFieldFocused)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .onSubmit {
                            handleContinue()
                        }

                    Text(unit == .kg ? "kg" : "lbs")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(OnboardingTheme.bodyText)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 40)
                .onTapGesture {
                    isTextFieldFocused = true
                }

                Spacer()
            }

            OnboardingTitleView(OnboardingCopy.t("Un poids de référence ?", en: "A reference weight?"))
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
            let normalized = Self.normalizeWeightInput(newValue)
            if normalized != newValue {
                weightString = normalized
                return
            }

            idealWeight = displayWeight
            onValidationChanged?(isValidWeight)

            if OnboardingViewModel.isPlausibleWeight(displayWeight) {
                onPersistAnswers?()
            }
        }
        .onDisappear {
            isTextFieldFocused = false
        }
    }

    private func handleContinue() {
        let trimmed = weightString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        idealWeight = displayWeight
        guard isValidWeight else { return }

        HapticManager.shared.impact(.medium)

        resignKeyboard()
        onContinue?()

        Task.detached(priority: .background) {
            await saveIdealWeight()
        }
    }

    private static func normalizeWeightInput(_ raw: String) -> String {
        var result = ""
        var sawSeparator = false
        for character in raw {
            if character.isNumber {
                result.append(character)
            } else if (character == "." || character == ","), !sawSeparator {
                result.append(".")
                sawSeparator = true
            }
        }
        return result
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
        if OnboardingViewModel.isPlausibleWeight(idealWeight) {
            populateWeightString(from: idealWeight)
            onValidationChanged?(isValidWeight)
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

    private func loadExistingWeight() {
        if OnboardingViewModel.isPlausibleWeight(idealWeight),
           isDistinctFromCurrentWeight(idealWeight) {
            populateWeightString(from: idealWeight)
        } else if let profile = profileService.currentProfile,
                  let savedIdeal = profile.idealWeight,
                  OnboardingViewModel.isPlausibleWeight(savedIdeal),
                  isDistinctFromCurrentWeight(savedIdeal) {
            idealWeight = savedIdeal
            populateWeightString(from: savedIdeal)
        } else {
            idealWeight = 0
            weightString = ""
        }

        onValidationChanged?(isValidWeight)
    }

    private func isDistinctFromCurrentWeight(_ weightKg: Double) -> Bool {
        guard OnboardingViewModel.isPlausibleWeight(currentWeight) else { return true }
        return abs(weightKg - currentWeight) >= 0.5
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
