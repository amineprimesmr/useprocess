//
//  WeightStepView.swift
//
//  ✨ Page de saisie du poids avec clavier numérique natif et toggle KG/LBS
//  Structure IDENTIQUE à HeightStepView pour éviter les mouvements avec le clavier
//

import SwiftUI
import UIKit

struct WeightStepView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var profileService: UnifiedProfileService

    @Binding var selectedWeight: Double  // en kg
    var onValidationChanged: ((Bool) -> Void)?
    var onContinue: (() -> Void)?

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

            OnboardingTitleView(OnboardingCopy.t("Quel est ton poids ?", en: "What's your weight?"))
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
            // US = "." ; FR et autres = "," — on normalise pour Double().
            let normalized = Self.normalizeWeightInput(newValue)
            if normalized != newValue {
                weightString = normalized
                return
            }

            selectedWeight = displayWeight
            // Valider en kg (pas la valeur brute LBS) — sinon Continue US faux positifs/négatifs.
            onValidationChanged?(OnboardingViewModel.isPlausibleWeight(displayWeight))
        }
        .onDisappear {
            isTextFieldFocused = false
        }
    }

    private func bootstrapIfNeeded() {
        guard !didBootstrap else { return }
        didBootstrap = true
        loadExistingWeight()
        DispatchQueue.main.asyncAfter(deadline: .now() + OnboardingTransitionTiming.keyboardFocusDelay) {
            isTextFieldFocused = true
        }
    }

    private func restoreWeightStringIfNeeded() {
        guard weightString.isEmpty else { return }
        if OnboardingViewModel.isPlausibleWeight(selectedWeight) {
            populateWeightString(from: selectedWeight)
            onValidationChanged?(OnboardingViewModel.isPlausibleWeight(displayWeight))
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
        guard !trimmed.isEmpty else { return }
        selectedWeight = displayWeight
        guard OnboardingViewModel.isPlausibleWeight(selectedWeight) else { return }

        HapticManager.shared.impact(.medium)

        resignKeyboard()
        onContinue?()

        Task.detached(priority: .background) {
            await saveWeight()
        }
    }

    /// Accepte chiffres + un seul séparateur décimal (`.` ou `,` → `.`).
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

        onValidationChanged?(OnboardingViewModel.isPlausibleWeight(displayWeight))
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
