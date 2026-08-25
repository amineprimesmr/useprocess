import Foundation

extension ProcessAnalytics {
    /// Track la réponse validée en quittant une étape + met à jour le profil PostHog.
    static func trackOnboardingAnswer(step: OnboardingStep, viewModel: OnboardingViewModel) {
        let answer = answerProperties(for: step, viewModel: viewModel)
        var props: [String: Any] = [
            "step": step.analyticsName,
            "step_raw": step.rawValue,
            "step_index": OnboardingFunnelScreen.from(step: step)?.funnelIndex ?? step.liveOrderIndex,
            "answer_keys": Array(answer.keys).sorted()
        ]
        for (key, value) in answer {
            props[key] = value
        }

        let person = personProperties(from: viewModel)
        capture("onboarding_answer", properties: props, userProperties: person.isEmpty ? nil : person)

        switch step {
        case .firstNameInput:
            trackFirstNameSet(viewModel.firstName, source: "onboarding_first_name")
            trackOnboardingProfileSnapshot(viewModel: viewModel, trigger: step.analyticsName)
        case .genderSelection, .ageSelection, .height, .weight:
            trackOnboardingProfileSnapshot(viewModel: viewModel, trigger: step.analyticsName)
        case .dashboardPreview:
            trackFaceScanProfile(viewModel: viewModel)
        default:
            break
        }
    }

    static func trackOnboardingProfileSnapshot(
        viewModel: OnboardingViewModel,
        trigger: String
    ) {
        var props = personProperties(from: viewModel)
        props["trigger"] = trigger
        if let bmi = bodyMassIndex(viewModel) {
            props["bmi"] = bmi
        }
        capture(
            "onboarding_profile_snapshot",
            properties: props,
            userProperties: personProperties(from: viewModel)
        )
    }

    static func trackOnboardingCompletedWithProfile(viewModel: OnboardingViewModel) {
        var props = personProperties(from: viewModel)
        if let step = currentOnboardingStepName {
            props["last_step"] = step
        }
        if let bmi = bodyMassIndex(viewModel) {
            props["bmi"] = bmi
        }
        if let hasGoal = viewModel.hasWeightGoal {
            props["has_weight_goal"] = hasGoal
        }
        if let goal = viewModel.selectedWeightGoal {
            props["weight_goal"] = goal.rawValue
        }
        if viewModel.isIdealWeightEntered,
           OnboardingViewModel.isPlausibleWeight(viewModel.idealWeightValue) {
            props["ideal_weight_kg"] = viewModel.idealWeightValue
        }
        let drivers = viewModel.onboardingDebloatDrivers.map(\.rawValue).sorted()
        if !drivers.isEmpty { props["debloat_drivers"] = drivers }
        if let quality = viewModel.nutritionProfile.nutritionQuality {
            props["nutrition_quality"] = quality.rawValue
        }
        if let sleep = viewModel.sleepProfile.sleepQuality {
            props["sleep_quality"] = sleep.rawValue
        }
        if let code = viewModel.referralCode, !code.isEmpty {
            props["referral_code"] = code
        }

        capture(
            "onboarding_completed",
            properties: props,
            userProperties: personProperties(from: viewModel)
        )
        ProcessAppsFlyer.shared.logEvent("af_tutorial_completion", values: [
            "af_content_id": "onboarding"
        ])
    }

    // MARK: - Private

    private static func trackFaceScanProfile(viewModel: OnboardingViewModel) {
        guard let markers = viewModel.onboardingFaceMarkers else { return }
        let props: [String: Any] = [
            "face_puffiness": markers.puffinessScore,
            "face_under_eye": markers.underEyeFatigueScore,
            "face_jaw_tension": markers.jawTensionScore,
            "face_symmetry": markers.facialSymmetryScore,
            "face_skin_clarity": markers.skinClarityScore,
            "face_definition": markers.faceDefinitionScore as Any
        ]
        capture("onboarding_face_markers", properties: props.sanitizedAnalyticsValues())
    }

    private static func personProperties(from viewModel: OnboardingViewModel) -> [String: Any] {
        var props: [String: Any] = [:]
        if let gender = viewModel.selectedGender {
            props["gender"] = gender.rawValue
            props["sex"] = gender.rawValue
        }
        if viewModel.isAgeSelected, viewModel.selectedAge > 0 {
            props["age"] = viewModel.selectedAge
        }
        if viewModel.selectedHeight > 0 {
            props["height_cm"] = Int(viewModel.selectedHeight.rounded())
        }
        if OnboardingViewModel.isPlausibleWeight(viewModel.selectedWeight) {
            props["weight_kg"] = (viewModel.selectedWeight * 10).rounded() / 10
        }
        let name = viewModel.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        if OnboardingViewModel.isRealUserFirstName(name) {
            props["first_name"] = name
            props["name"] = name
        }
        if viewModel.isIdealWeightEntered,
           OnboardingViewModel.isPlausibleWeight(viewModel.idealWeightValue) {
            props["ideal_weight_kg"] = (viewModel.idealWeightValue * 10).rounded() / 10
        }
        if let goal = viewModel.selectedWeightGoal {
            props["weight_goal"] = goal.rawValue
        }
        if let bmi = bodyMassIndex(viewModel) {
            props["bmi"] = bmi
        }
        return props
    }

    private static func bodyMassIndex(_ viewModel: OnboardingViewModel) -> Double? {
        guard OnboardingViewModel.isPlausibleWeight(viewModel.selectedWeight),
              viewModel.selectedHeight >= 120 else { return nil }
        let meters = viewModel.selectedHeight / 100
        let value = viewModel.selectedWeight / (meters * meters)
        return (value * 10).rounded() / 10
    }

    private static func answerProperties(
        for step: OnboardingStep,
        viewModel: OnboardingViewModel
    ) -> [String: Any] {
        var props: [String: Any] = [:]

        switch step {
        case .genderSelection:
            if let gender = viewModel.selectedGender {
                props["gender"] = gender.rawValue
                props["sex"] = gender.rawValue
            }

        case .ageSelection:
            props["age"] = viewModel.selectedAge

        case .height:
            props["height_cm"] = viewModel.selectedHeight

        case .weight:
            props["weight_kg"] = viewModel.selectedWeight
            if let bmi = bodyMassIndex(viewModel) { props["bmi"] = bmi }
            if let gender = viewModel.selectedGender { props["gender"] = gender.rawValue }
            if viewModel.isAgeSelected { props["age"] = viewModel.selectedAge }

        case .firstNameInput:
            let name = viewModel.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
            props["first_name"] = name
            props["first_name_length"] = name.count

        case .dashboardPreview:
            props["face_analysis_completed"] = viewModel.isFaceAnalysisCompleted
            if let markers = viewModel.onboardingFaceMarkers {
                props["face_puffiness"] = markers.puffinessScore
                props["face_under_eye"] = markers.underEyeFatigueScore
                props["face_jaw_tension"] = markers.jawTensionScore
                props["face_symmetry"] = markers.facialSymmetryScore
                props["face_skin_clarity"] = markers.skinClarityScore
                if let definition = markers.faceDefinitionScore {
                    props["face_definition"] = definition
                }
            }

        case .referralCode:
            let code = viewModel.referralCode ?? ""
            props["has_referral_code"] = !code.isEmpty
            if !code.isEmpty { props["referral_code"] = code }

        case .programCreation:
            props["program_creation_completed"] = viewModel.isProgramCreationCompleted
            props["debloat_drivers"] = viewModel.onboardingDebloatDrivers.map(\.rawValue).sorted()

        default:
            break
        }

        // Enrichissement commun
        if step != .genderSelection, let gender = viewModel.selectedGender {
            props["gender"] = props["gender"] ?? gender.rawValue
        }
        if step != .ageSelection, viewModel.isAgeSelected {
            props["age"] = props["age"] ?? viewModel.selectedAge
        }

        return props.sanitizedAnalyticsValues()
    }
}

private extension Dictionary where Key == String, Value == Any {
    func sanitizedAnalyticsValues() -> [String: Any] {
        compactMapValues { value in
            let mirror = Mirror(reflecting: value)
            if mirror.displayStyle == .optional, mirror.children.isEmpty {
                return nil
            }
            return value
        }
    }
}
