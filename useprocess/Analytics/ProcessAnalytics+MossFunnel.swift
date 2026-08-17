import Foundation

extension ProcessAnalytics {
    /// Sous-pages Moss → face scan → popups création programme.
    /// Une seule event `onboarding_moss_page_viewed` + `page` pour builder un funnel PostHog précis.
    enum MossPage: String, CaseIterable {
        case introSwollenFace = "intro_swollen_face"
        case introCauses = "intro_causes"
        case introNext = "intro_next"
        case debloatDriver = "debloat_driver"
        case hydrationLevel = "hydration_level"
        case junkFood = "junk_food"
        case sleepHours = "sleep_hours"
        case cardioFrequency = "cardio_frequency"
        case profileSummary = "profile_summary"
        case faceScanOffer = "face_scan_offer"
        case faceScanCapture = "face_scan_capture"
        case faceScanAnalyzing = "face_scan_analyzing"
        case faceScanResults = "face_scan_results"
        case programCreationPhaseHealth = "program_creation_phase_health"
        case programCreationPopupHealthKit = "program_creation_popup_healthkit"
        case programCreationPhaseProfile = "program_creation_phase_profile"
        case programCreationPopupTriedDebloat = "program_creation_popup_tried_debloat"
        case programCreationPhasePlan = "program_creation_phase_plan"
        case programCreationSuccess = "program_creation_success"

        var pageIndex: Int {
            Self.allCases.firstIndex(of: self) ?? -1
        }

        var parentStep: String {
            switch self {
            case .programCreationPhaseHealth,
                 .programCreationPopupHealthKit,
                 .programCreationPhaseProfile,
                 .programCreationPopupTriedDebloat,
                 .programCreationPhasePlan,
                 .programCreationSuccess:
                return "programCreation"
            default:
                return "weightMotivation"
            }
        }

        var kind: String {
            switch self {
            case .faceScanCapture, .faceScanAnalyzing, .faceScanResults:
                return "face_scan"
            case .programCreationPhaseHealth,
                 .programCreationPopupHealthKit,
                 .programCreationPhaseProfile,
                 .programCreationPopupTriedDebloat,
                 .programCreationPhasePlan,
                 .programCreationSuccess:
                return "program_creation"
            default:
                return "chat_question"
            }
        }

        static func chatQuestion(id: String) -> MossPage? {
            if id == "face_scan_offer" {
                return .profileSummary
            }
            return MossPage(rawValue: id)
        }

        static func programCreationPhase(index: Int) -> MossPage? {
            switch index {
            case 0: return .programCreationPhaseHealth
            case 1: return .programCreationPhaseProfile
            case 2: return .programCreationPhasePlan
            default: return nil
            }
        }

        static func programCreationPopup(kind: OnboardingAnalysisProgressConfig.PopupKind) -> MossPage {
            switch kind {
            case .healthKit: return .programCreationPopupHealthKit
            case .yesNo: return .programCreationPopupTriedDebloat
            }
        }
    }

    /// Vue d’une sous-page Moss (question, scan, popup programme…).
    static func trackMossPageViewed(
        _ page: MossPage,
        questionKind: String? = nil,
        questionsTotal: Int? = nil,
        extra: [String: Any] = [:]
    ) {
        let name = page.rawValue
        guard name != lastMossPageName else { return }
        lastMossPageName = name

        var props: [String: Any] = [
            "page": name,
            "page_index": page.pageIndex,
            "page_kind": page.kind,
            "parent_step": page.parentStep
        ]
        if let questionKind { props["question_kind"] = questionKind }
        if let questionsTotal { props["questions_total"] = questionsTotal }
        for (key, value) in extra {
            props[key] = value
        }

        capture("onboarding_moss_page_viewed", properties: props)
        screen("moss_\(name)")
    }

    /// Action sur une sous-page (réponse, skip, cancel, continue…).
    static func trackMossAction(
        page: MossPage,
        action: String,
        answerID: String? = nil,
        answerDisplay: String? = nil,
        extra: [String: Any] = [:]
    ) {
        var props: [String: Any] = [
            "page": page.rawValue,
            "page_index": page.pageIndex,
            "page_kind": page.kind,
            "parent_step": page.parentStep,
            "action": action
        ]
        if let answerID { props["answer_id"] = answerID }
        if let answerDisplay {
            props["answer_display"] = answerDisplay
            props["answer_length"] = answerDisplay.count
        }
        for (key, value) in extra {
            props[key] = value
        }
        capture("onboarding_moss_action", properties: props)
    }

    /// Helper chat : page vue + contexte question.
    static func trackMossChatQuestionViewed(
        questionID: String,
        questionKind: String,
        questionIndex: Int,
        questionsTotal: Int
    ) {
        guard let page = MossPage.chatQuestion(id: questionID) else { return }
        trackMossPageViewed(
            page,
            questionKind: questionKind,
            questionsTotal: questionsTotal,
            extra: [
                "question_id": questionID,
                "question_index": questionIndex
            ]
        )
    }

    static func trackMossChatAnswer(
        questionID: String,
        questionKind: String,
        questionIndex: Int,
        questionsTotal: Int,
        answerDisplay: String,
        answerID: String? = nil,
        profileExtras: [String: Any] = [:]
    ) {
        guard let page = MossPage.chatQuestion(id: questionID) else {
            // Fallback legacy event si id inconnu.
            var props: [String: Any] = [
                "question_id": questionID,
                "answer_display": answerDisplay,
                "answer_length": answerDisplay.count,
                "question_kind": questionKind,
                "question_index": questionIndex,
                "questions_total": questionsTotal
            ]
            for (key, value) in profileExtras { props[key] = value }
            capture("onboarding_chat_answer", properties: props)
            return
        }

        trackMossAction(
            page: page,
            action: "answered",
            answerID: answerID,
            answerDisplay: answerDisplay,
            extra: {
                var props: [String: Any] = [
                    "question_id": questionID,
                    "question_kind": questionKind,
                    "question_index": questionIndex,
                    "questions_total": questionsTotal
                ]
                for (key, value) in profileExtras {
                    props[key] = value
                }
                return props
            }()
        )

        // Conserve l’event historique pour les dashboards existants.
        var legacy: [String: Any] = [
            "question_id": questionID,
            "answer_display": answerDisplay,
            "answer_length": answerDisplay.count,
            "question_kind": questionKind,
            "question_index": questionIndex,
            "questions_total": questionsTotal,
            "page": page.rawValue,
            "page_index": page.pageIndex
        ]
        if let answerID { legacy["answer_id"] = answerID }
        for (key, value) in profileExtras { legacy[key] = value }
        capture("onboarding_chat_answer", properties: legacy)
    }
}
