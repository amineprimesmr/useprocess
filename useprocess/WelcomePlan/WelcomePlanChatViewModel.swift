import Foundation
import SwiftUI

@MainActor
@Observable
final class WelcomePlanChatViewModel {
    var messages: [OnboardingProfileChatMessage] = []
    var isMessageAnimating = false
    var isSubmittingAnswer = false
    var isGenerating = false
    var showsGenerationProgress = false
    var generationProgress: Double = 0
    var generationPhaseLabel: String = ""
    var generationDisplayedPercentage: Int = 0
    var generatedPlan: FaceOriginPlan?
    var errorMessage: String?
    var pendingFaceScan = false
    var showsEnterButton = false

    private(set) var currentQuestion: WelcomePlanQuestion?
    private var activeQuestions: [WelcomePlanQuestion] = []
    private var currentIndex = 0
    private var answers: [String: WelcomePlanAnswer] = [:]
    private var profile: UnifiedUserProfile?
    private var hasStarted = false
    private var lastPhase: WelcomePlanPhase?
    private var skipNextCoachIntro = false
    private var isQuestionReadyForAnswers = false
    private var typewriterTask: Task<Void, Never>?
    private var generationTask: Task<Void, Never>?
    private var pendingTypewriterMessageID: UUID?
    private var pendingTypewriterText: String?

    var showsAnswerOptions: Bool {
        !isComplete
            && !isGenerating
            && !isMessageAnimating
            && !isSubmittingAnswer
            && currentQuestion != nil
            && isQuestionReadyForAnswers
    }

    var isComplete: Bool { generatedPlan != nil }

    var configurationProgress: Double {
        WelcomePlanQuestionBank.configurationProgress(answers: answers, isComplete: isComplete)
    }

    var configurationStepLabel: String {
        WelcomePlanQuestionBank.configurationStepLabel(answers: answers, isComplete: isComplete)
    }

    var configurationPhaseLabel: String {
        if isComplete || isGenerating { return "Protocole prêt" }
        guard let phase = currentQuestion?.phase else { return "Configuration" }
        return WelcomePlanQuestionBank.phaseLabel(for: phase)
    }

    func bind(profile: UnifiedUserProfile?) {
        self.profile = profile
        answers = WelcomePlanStore.shared.questionnaire.answers
        activeQuestions = WelcomePlanQuestionBank.activeQuestions(answers: answers)
        currentIndex = firstUnansweredIndex()
        currentQuestion = question(at: currentIndex)
    }

    func startIfNeeded() async {
        guard !hasStarted else { return }
        hasStarted = true
        activeQuestions = WelcomePlanQuestionBank.activeQuestions(answers: answers)
        currentIndex = firstUnansweredIndex()
        currentQuestion = question(at: currentIndex)

        if currentIndex > 0 {
            lastPhase = activeQuestions[currentIndex - 1].phase
        }

        if !answers.isEmpty {
            restoreConversationHistory()
        }

        if currentIndex >= activeQuestions.count {
            await generatePlan()
        } else {
            await presentCurrentQuestion()
        }
    }

    func submitSingleChoice(_ choiceId: String) async {
        guard let question = currentQuestion else { return }
        let label = WelcomePlanQuestionBank.choiceLabel(for: question.id, choiceId: choiceId)
        await recordAnswer(question: question, answer: WelcomePlanAnswer(choiceIds: [choiceId]), display: label)
    }

    func submitYesNo(_ yes: Bool) async {
        guard let question = currentQuestion else { return }
        let id = yes ? "yes" : "no"
        await recordAnswer(
            question: question,
            answer: WelcomePlanAnswer(choiceIds: [id]),
            display: yes ? "Oui" : "Non"
        )
    }

    func submitMultiChoice(_ choiceIds: Set<String>) async {
        guard let question = currentQuestion else { return }
        let labels = choiceIds.map { WelcomePlanQuestionBank.choiceLabel(for: question.id, choiceId: $0) }
        await recordAnswer(
            question: question,
            answer: WelcomePlanAnswer(choiceIds: Array(choiceIds)),
            display: labels.joined(separator: ", ")
        )
    }

    func submitTime(_ date: Date) async {
        guard let question = currentQuestion else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let text = formatter.string(from: date)
        await recordAnswer(
            question: question,
            answer: WelcomePlanAnswer(timeValue: text),
            display: text
        )
    }

    func submitText(_ text: String, skipped: Bool = false) async {
        guard let question = currentQuestion else { return }
        let display = skipped || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : text
        await recordAnswer(
            question: question,
            answer: WelcomePlanAnswer(textValue: skipped ? nil : text, skipped: skipped),
            display: display
        )
    }

    func submitInfoContinue() async {
        guard let question = currentQuestion, question.kind == .info else { return }
        await recordAnswer(
            question: question,
            answer: WelcomePlanAnswer(choiceIds: ["continue"]),
            display: "Continuer"
        )
    }

    func finishAndEnterApp(previewMode: Bool = false, onComplete: @escaping () -> Void) async {
        guard let plan = generatedPlan else { return }
        if !previewMode {
            WelcomePlanStore.shared.markQuestionnaireComplete()
            WelcomePlanStore.shared.savePlan(plan)
            await WelcomePlanProfileSync.apply(
                answers: answers,
                plan: plan,
                profileService: UnifiedProfileService.shared
            )
            AppSession.shared.completeWelcomePlanChat()
            CoachConversationStore.stripInjectedProgramSummaryMessages()
        }
        onComplete()
    }

    // MARK: - Private

    private func restoreConversationHistory() {
        var simulated: [String: WelcomePlanAnswer] = [:]
        var questions = WelcomePlanQuestionBank.activeQuestions(answers: simulated)

        while let nextIndex = questions.firstIndex(where: { simulated[$0.id] == nil }),
              let answer = answers[questions[nextIndex].id] {
            let question = questions[nextIndex]

            if let intro = WelcomePlanCoachCopy.coachIntro(
                for: question,
                answers: simulated,
                profile: profile,
                skipBecausePhaseTransition: false
            ) {
                messages.append(.init(role: .assistant, text: intro, layoutAnchorText: intro))
            }
            messages.append(
                .init(role: .assistant, text: question.prompt, layoutAnchorText: question.prompt)
            )
            messages.append(.init(role: .user, text: displayLabel(for: question, answer: answer)))

            simulated[question.id] = answer
            questions = WelcomePlanQuestionBank.activeQuestions(answers: simulated)
        }
    }

    private func displayLabel(for question: WelcomePlanQuestion, answer: WelcomePlanAnswer) -> String {
        if answer.skipped { return "—" }
        if let text = answer.textValue?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            return text
        }
        if let time = answer.timeValue { return time }
        if !answer.choiceIds.isEmpty {
            return answer.choiceIds
                .map { WelcomePlanQuestionBank.choiceLabel(for: question.id, choiceId: $0) }
                .joined(separator: ", ")
        }
        return "—"
    }

    private func firstUnansweredIndex() -> Int {
        activeQuestions.firstIndex(where: { answers[$0.id] == nil }) ?? activeQuestions.count
    }

    private func question(at index: Int) -> WelcomePlanQuestion? {
        guard index >= 0, index < activeQuestions.count else { return nil }
        return activeQuestions[index]
    }

    private func recordAnswer(question: WelcomePlanQuestion, answer: WelcomePlanAnswer, display: String) async {
        guard !isSubmittingAnswer else { return }
        isSubmittingAnswer = true

        answers[question.id] = answer
        WelcomePlanStore.shared.saveAnswer(questionId: question.id, answer: answer)

        activeQuestions = WelcomePlanQuestionBank.activeQuestions(answers: answers)
        currentIndex = (activeQuestions.firstIndex(where: { $0.id == question.id }) ?? currentIndex) + 1

        if question.id == "optional_face_scan", answer.choiceIds.first == "yes" {
            pendingFaceScan = true
        }

        typewriterTask?.cancel()
        isQuestionReadyForAnswers = false
        currentQuestion = nil

        withAnimation(OnboardingProfileChatDepthStyle.historySpring) {
            appendUserMessage(display)
        }

        await advanceFlow()
        isSubmittingAnswer = false
    }

    private func advanceFlow() async {
        if currentIndex >= activeQuestions.count {
            await generatePlan()
            return
        }

        let next = activeQuestions[currentIndex]
        if lastPhase != next.phase {
            lastPhase = next.phase
            if let transition = WelcomePlanCoachCopy.phaseTransition(
                for: next.phase,
                answers: answers,
                profile: profile
            ) {
                await appendAssistantMessage(transition)
                skipNextCoachIntro = true
            }
        }

        currentQuestion = next
        await presentCurrentQuestion()
    }

    private func presentCurrentQuestion() async {
        guard let question = currentQuestion else {
            await generatePlan()
            return
        }

        isQuestionReadyForAnswers = false

        if let intro = WelcomePlanCoachCopy.coachIntro(
            for: question,
            answers: answers,
            profile: profile,
            skipBecausePhaseTransition: skipNextCoachIntro
        ) {
            await appendAssistantMessage(intro)
        }
        skipNextCoachIntro = false

        let messageID = UUID()
        pendingTypewriterMessageID = messageID
        pendingTypewriterText = question.prompt

        withAnimation(OnboardingProfileChatDepthStyle.historySpring) {
            messages.append(
                .init(
                    id: messageID,
                    role: .assistant,
                    text: "",
                    layoutAnchorText: question.prompt
                )
            )
            isMessageAnimating = true
        }

        try? await Task.sleep(nanoseconds: 180_000_000)
        await runTypewriter(initialDelay: true)
        isQuestionReadyForAnswers = true
    }

    private func generatePlan() async {
        guard !isGenerating else { return }
        isGenerating = true
        showsGenerationProgress = true
        generationProgress = 0
        generationDisplayedPercentage = 0
        generationPhaseLabel = "Lecture de ton profil…"
        currentQuestion = nil
        isQuestionReadyForAnswers = false
        showsEnterButton = false

        appendAssistantMessageInstant("Je compile ton Protocole Origine…")
        startGenerationProgressAnimation()

        async let builtPlan: FaceOriginPlan = buildGeneratedPlan()
        async let minimumWait: Void = {
            try? await Task.sleep(nanoseconds: 2_200_000_000)
        }()

        let plan = await builtPlan
        await minimumWait
        await generationTask?.value

        generationProgress = 1
        generationDisplayedPercentage = 100
        generationPhaseLabel = "Protocole prêt"
        HapticManager.shared.notification(.success)
        try? await Task.sleep(for: .milliseconds(350))

        generatedPlan = plan
        isGenerating = false
        showsGenerationProgress = false

        appendAssistantMessageInstant(completionMessage())

        withAnimation(OnboardingProfileChatAnswerReveal.spring) {
            showsEnterButton = true
        }
    }

    private func buildGeneratedPlan() async -> FaceOriginPlan {
        var plan = WelcomePlanGenerator.generate(answers: answers, profile: profile)

        if ClaudeConfiguration.isConfigured {
            if let enhanced = await enhanceSummaryWithClaude(plan: plan) {
                plan.executiveSummary = enhanced
            }
        }

        return plan
    }

    private func completionMessage() -> String {
        if pendingFaceScan {
            return "C'est prêt. On lance le scan visage juste après."
        }
        return "C'est prêt. Retrouve ton plan complet dans Santé."
    }

    private func startGenerationProgressAnimation() {
        generationTask?.cancel()

        let phases = [
            "Lecture de ton profil…",
            "Calibrage sommeil & nutrition…",
            "Assemblage du protocole…",
            "Dernières touches…"
        ]

        generationTask = Task {
            let tickNs: UInt64 = 40_000_000
            let step = 0.018
            var phaseIndex = 0
            generationPhaseLabel = phases[0]

            while generationProgress < 0.94, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: tickNs)
                guard !Task.isCancelled else { return }

                generationProgress = min(0.94, generationProgress + step)
                generationDisplayedPercentage = Int((generationProgress * 100).rounded())

                let nextPhaseIndex = min(
                    Int(generationProgress * Double(phases.count)),
                    phases.count - 1
                )
                if nextPhaseIndex != phaseIndex {
                    phaseIndex = nextPhaseIndex
                    generationPhaseLabel = phases[phaseIndex]
                }
            }
        }
    }

    private func appendAssistantMessageInstant(_ text: String) {
        withAnimation(OnboardingProfileChatDepthStyle.historySpring) {
            messages.append(
                .init(
                    role: .assistant,
                    text: text,
                    layoutAnchorText: text
                )
            )
        }
    }

    private func enhanceSummaryWithClaude(plan: FaceOriginPlan) async -> String? {
        let block = """
        Objectif : \(plan.primaryFaceGoal)
        Piliers : \(plan.pillarScores.map { "\($0.pillar) \($0.score)/100" }.joined(separator: ", "))
        Résumé actuel : \(plan.executiveSummary)
        """
        let prompt = """
        Reformule ce résumé de plan Protocole Origine en 6-8 phrases (ton Enzo, tutoiement).
        100 % naturel, zéro pilule, zéro complément.
        \(block)
        """

        do {
            return try await CoachAPITransport.complete(
                task: .programSummary,
                system: EnzoCoachingVoiceGuide.systemPrompt,
                userText: prompt,
                model: ClaudeModel.preferred(for: .programSummary),
                maxTokens: 500
            )
        } catch {
            return nil
        }
    }

    private func appendUserMessage(_ text: String) {
        messages.append(.init(role: .user, text: text))
    }

    private func appendAssistantMessage(_ text: String) async {
        let messageID = UUID()
        pendingTypewriterMessageID = messageID
        pendingTypewriterText = text

        withAnimation(OnboardingProfileChatDepthStyle.historySpring) {
            messages.append(
                .init(
                    id: messageID,
                    role: .assistant,
                    text: "",
                    layoutAnchorText: text
                )
            )
            isMessageAnimating = true
        }

        await runTypewriter(initialDelay: true)
    }

    private func runTypewriter(initialDelay: Bool) async {
        typewriterTask?.cancel()
        guard let messageID = pendingTypewriterMessageID,
              let text = pendingTypewriterText else {
            isMessageAnimating = false
            return
        }

        isMessageAnimating = true

        if initialDelay {
            try? await Task.sleep(nanoseconds: 260_000_000)
        } else {
            try? await Task.sleep(nanoseconds: 45_000_000)
        }

        typewriterTask = Task {
            var displayed = ""
            for character in Array(text) {
                guard !Task.isCancelled else { return }

                let delayNs = typewriterDelay(for: character)
                try? await Task.sleep(nanoseconds: delayNs)
                guard !Task.isCancelled else { return }

                displayed.append(character)
                updateMessage(id: messageID, text: displayed)

                if character != " " && character != "\n" && character != "\t" {
                    HapticManager.shared.impact(.soft)
                }
                if character == "!" || character == "." || character == "?" {
                    HapticManager.shared.impact(.light)
                }
            }
        }

        await typewriterTask?.value
        isMessageAnimating = false
        pendingTypewriterMessageID = nil
        pendingTypewriterText = nil
    }

    private func typewriterDelay(for character: Character) -> UInt64 {
        switch character {
        case " ", "\n", "\t":
            return 20_000_000
        case ".", "!", "?", "…":
            return 90_000_000
        case ",", ";", ":":
            return 60_000_000
        case "%":
            return 45_000_000
        default:
            return 36_000_000
        }
    }

    private func updateMessage(id: UUID, text: String) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        let anchor = messages[index].layoutAnchorText
        messages[index] = .init(id: id, role: .assistant, text: text, layoutAnchorText: anchor)
    }
}
