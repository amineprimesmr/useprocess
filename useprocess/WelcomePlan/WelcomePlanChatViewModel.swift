import Foundation
import SwiftUI

@MainActor
@Observable
final class WelcomePlanChatViewModel {
    var messages: [CoachMessage] = []
    var isTyping = false
    var isGenerating = false
    var generatedPlan: FaceOriginPlan?
    var errorMessage: String?
    var pendingFaceScan = false

    private(set) var currentQuestion: WelcomePlanQuestion?
    private var activeQuestions: [WelcomePlanQuestion] = []
    private var currentIndex = 0
    private var answers: [String: WelcomePlanAnswer] = [:]
    private var profile: UnifiedUserProfile?
    private var hasStarted = false
    private var lastPhase: WelcomePlanPhase?

    var progress: Double {
        guard !activeQuestions.isEmpty else { return 0 }
        let answered = answers.keys.filter { id in activeQuestions.contains(where: { $0.id == id }) }.count
        return Double(answered) / Double(activeQuestions.count)
    }

    var isComplete: Bool { generatedPlan != nil }

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

        await presentCurrentQuestion()
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
        }
        onComplete()
    }

    // MARK: - Private

    private func firstUnansweredIndex() -> Int {
        activeQuestions.firstIndex(where: { answers[$0.id] == nil }) ?? activeQuestions.count
    }

    private func question(at index: Int) -> WelcomePlanQuestion? {
        guard index >= 0, index < activeQuestions.count else { return nil }
        return activeQuestions[index]
    }

    private func recordAnswer(question: WelcomePlanQuestion, answer: WelcomePlanAnswer, display: String) async {
        answers[question.id] = answer
        WelcomePlanStore.shared.saveAnswer(questionId: question.id, answer: answer)
        appendUserMessage(display)

        activeQuestions = WelcomePlanQuestionBank.activeQuestions(answers: answers)
        currentIndex = (activeQuestions.firstIndex(where: { $0.id == question.id }) ?? currentIndex) + 1

        if question.id == "optional_face_scan", answer.choiceIds.first == "yes" {
            pendingFaceScan = true
        }

        await advanceFlow()
    }

    private func advanceFlow() async {
        if currentIndex >= activeQuestions.count {
            await generatePlan()
            return
        }

        let next = activeQuestions[currentIndex]
        if lastPhase != next.phase {
            lastPhase = next.phase
            if let transition = WelcomePlanQuestionBank.phaseTransitionMessage(for: next.phase) {
                await appendCoachMessage(transition)
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

        if let intro = question.coachIntro {
            await appendCoachMessage(intro)
        }

        await appendCoachMessage(question.prompt)
    }

    private func generatePlan() async {
        guard !isGenerating else { return }
        isGenerating = true
        currentQuestion = nil
        isTyping = true

        await appendCoachMessage("Je compile ton Protocole Origine…")

        try? await Task.sleep(for: .milliseconds(900))

        var plan = WelcomePlanGenerator.generate(answers: answers, profile: profile)

        if ClaudeConfiguration.isConfigured {
            if let enhanced = await enhanceSummaryWithClaude(plan: plan) {
                plan.executiveSummary = enhanced
            }
        }

        generatedPlan = plan
        isTyping = false
        isGenerating = false

        await appendCoachMessages([
            "Voilà. Ton Protocole Origine est prêt.",
            planSummarySnippet(plan),
            FaceOriginPlan.noSupplementsPhilosophy,
            pendingFaceScan
                ? "Tu as choisi le scan visage — on l'ouvrira juste après."
                : "Retrouve le détail complet dans Santé. On ajuste avec le coach au fil des semaines."
        ])
    }

    private func planSummarySnippet(_ plan: FaceOriginPlan) -> String {
        let habits = plan.dailyHabits.prefix(3).map(\.title).joined(separator: " · ")
        return """
        \(plan.executiveSummary)

        Durée : \(plan.durationMinWeeks) à \(plan.durationMaxWeeks) semaines (\(plan.totalWeeks) semaines calendrier).
        Habitudes clés : \(habits).
        \(plan.trainingProtocol.sessionsPerWeek) séances/sem · Sommeil cible \(String(format: "%.1f", plan.sleepProtocol.targetHours)) h.
        """
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
        messages.append(CoachMessage(role: .user, text: text))
    }

    private func appendCoachMessage(_ text: String) async {
        isTyping = true
        try? await Task.sleep(for: .milliseconds(420))
        messages.append(CoachMessage(role: .assistant, text: text))
        isTyping = false
    }

    private func appendCoachMessages(_ texts: [String]) async {
        for text in texts {
            await appendCoachMessage(text)
        }
    }
}
