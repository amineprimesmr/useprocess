//
//  HeightStepView.swift
//  Process
//
//  Page de sélection de la taille : toggle CM/FT + TickPicker (graduations).
//

import SwiftUI

struct HeightStepView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var profileService: UnifiedProfileService

    @Binding var selectedHeight: Double  // en cm
    var onValidationChanged: ((Bool) -> Void)?

    @State private var unit: HeightUnit = .cm
    /// Index 0 = 140 cm, index `tickIndexMax` = 220 cm (pas de 1 cm). Utilisé avec `TickPicker` (iOS 18+).
    @State private var tickSelection: Int = 36
    @State private var sliderValue: Double = 0.5
    @State private var lastHapticHeight: Int = -1
    @State private var saveTask: Task<Void, Never>?

    private let minHeightCM: Double = 140
    private let maxHeightCM: Double = 220
    /// Nombre d'intervalles : 140…220 cm → 81 valeurs, indices 0…80.
    private let tickIndexMax: Int = 80

    enum HeightUnit {
        case cm
        case ft

        var displayName: String {
            switch self {
            case .cm: return "CM"
            case .ft: return "FT"
            }
        }
    }

    private var displayHeight: String {
        switch unit {
        case .cm:
            return "\(Int(selectedHeight))"
        case .ft:
            let totalInches = selectedHeight / 2.54
            let feet = Int(totalInches / 12)
            let inches = Int(totalInches.truncatingRemainder(dividingBy: 12))
            return "\(feet)'\(inches)\""
        }
    }

    private var displayUnit: String {
        unit == .cm ? "cm" : ""
    }

    private var heightTickConfig: TickConfig {
        TickConfig(
            tickWidth: 2,
            tickHeight: 32,
            tickHPadding: 3,
            inActiveHeightProgress: 0.55,
            interactionHeight: 72,
            activeTint: OnboardingTheme.tickActiveTint(for: colorScheme),
            inActiveTint: OnboardingTheme.tickInactiveTint(for: colorScheme),
            alignment: .bottom,
            animation: .interpolatingSpring(duration: 0.3, bounce: 0, initialVelocity: 0)
        )
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: OnboardingConstants.titleAreaHeight)

                Spacer()
                    .frame(height: OnboardingConstants.titleToContentSpacing)

                VStack(spacing: 0) {
                    OnboardingUnitSegmentToggle(
                        leftLabel: "CM",
                        rightLabel: "FT",
                        isLeftSelected: Binding(
                            get: { unit == .cm },
                            set: { unit = $0 ? .cm : .ft }
                        )
                    )
                    .padding(.bottom, 60)

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(displayHeight)
                            .font(.system(size: 56, weight: .bold, design: .default))
                            .foregroundStyle(OnboardingTheme.primaryText)
                            .onboardingValueGlow(colorScheme: colorScheme)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedHeight)

                        Text(displayUnit)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(OnboardingTheme.bodyText)
                    }
                    .padding(.bottom, 32)

                    TickPicker(
                        count: tickIndexMax,
                        config: heightTickConfig,
                        selection: $tickSelection
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 15)
                    .padding(.top, 24)
                    .padding(.bottom, 56)
                    .onChange(of: tickSelection) { _, newValue in
                        applyTickIndex(newValue)
                    }

                    Spacer()
                }
            }

            VStack {
                OnboardingTitleView("Quelle est ta taille ?")
                    .padding(.top, OnboardingConstants.titleTopPadding)
                Spacer()
            }
        }
        .onAppear {
            if selectedHeight <= 0 {
                if let profile = profileService.currentProfile, profile.height > 0 {
                    selectedHeight = profile.height
                } else {
                    selectedHeight = 176.0
                }
            }

            syncTickSelectionFromHeight()
            onValidationChanged?(selectedHeight > 0)
        }
        .onChange(of: selectedHeight) { _, newValue in
            onValidationChanged?(newValue > 0)
        }
    }

    private func syncTickSelectionFromHeight() {
        let cmRounded = Int(selectedHeight.rounded())
        let clampedCm = min(max(cmRounded, Int(minHeightCM)), Int(maxHeightCM))
        selectedHeight = Double(clampedCm)
        tickSelection = clampedCm - Int(minHeightCM)
        sliderValue = (selectedHeight - minHeightCM) / (maxHeightCM - minHeightCM)
        lastHapticHeight = clampedCm
    }

    private func applyTickIndex(_ index: Int) {
        let safe = min(max(index, 0), tickIndexMax)
        let newHeightCM = Double(Int(minHeightCM) + safe)
        guard Int(selectedHeight.rounded()) != Int(newHeightCM) else { return }

        selectedHeight = newHeightCM

        let currentHeightCm = Int(newHeightCM)
        if currentHeightCm != lastHapticHeight {
            lastHapticHeight = currentHeightCm
            HapticManager.shared.selection()
        }

        scheduleSaveHeight()
    }

    private func updateHeightFromSliderLegacy() {
        let rawCM = minHeightCM + sliderValue * (maxHeightCM - minHeightCM)
        let newHeightCM = Double(Int(rawCM.rounded()))
        selectedHeight = min(max(newHeightCM, minHeightCM), maxHeightCM)

        let currentHeightCm = Int(selectedHeight)
        if currentHeightCm != lastHapticHeight {
            lastHapticHeight = currentHeightCm
            HapticManager.shared.selection()
        }

        scheduleSaveHeight()
    }

    private func scheduleSaveHeight() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await saveHeight()
        }
    }

    private func saveHeight() async {
        guard var profile = profileService.currentProfile else { return }

        profile.height = selectedHeight
        do {
            try await profileService.saveProfile(profile)
        } catch {
            DebugLogger.error("\(error.localizedDescription)")
        }
    }
}
