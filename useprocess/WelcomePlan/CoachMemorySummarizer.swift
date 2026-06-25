import Foundation

enum CoachMemorySummarizer {

    @MainActor
    static func refreshIfNeeded(profile: UnifiedUserProfile?, force: Bool = false) async {
        guard ClaudeConfiguration.isConfigured else { return }

        let memory = CoachMemoryStore.shared.memory
        if !force, let last = memory.aiSummaryUpdatedAt,
           Date().timeIntervalSince(last) < 6 * 3600 { return }

        let conversations = CoachConversationLibraryStore.shared.sortedConversations
        guard !conversations.isEmpty else { return }

        var blocks: [String] = []
        for conv in conversations.prefix(8) {
            let users = conv.messages.filter { $0.role == .user }.suffix(3).map(\.text)
            let assistants = conv.messages.filter { $0.role == .assistant }.suffix(2).map(\.text)
            blocks.append("""
            ### \(conv.title) (\(conv.messageCount) msgs)
            User: \(users.joined(separator: " | "))
            Coach: \(assistants.joined(separator: " | "))
            """)
        }

        let planBlock: String
        if let plan = WelcomePlanStore.shared.plan {
            let meals = CoachPlanContextBuilder.todayMealsBlock(plan: plan)
                .components(separatedBy: "\n")
                .prefix(4)
                .joined(separator: " ")
            planBlock = """
            Plan actif semaine \(plan.calendar.currentWeekNumber())/13 — \(plan.primaryFaceGoal).
            \(meals)
            Ajustements récents : \(CoachMemoryStore.shared.memory.planAdjustments.prefix(3).joined(separator: " | "))
            """
        } else {
            planBlock = "Pas de plan actif"
        }

        let prompt = """
        Synthétise TOUTE la mémoire utilisateur useprocess en 12 bullet points max (français).
        Inclus : objectifs, habitudes, douleurs, ajustements plan, sujets récurrents coach.
        \(planBlock)

        CONVERSATIONS :
        \(blocks.joined(separator: "\n"))

        Faits existants : \(memory.keyFacts.prefix(8).joined(separator: " · "))
        """

        do {
            let summary = try await CoachAPITransport.complete(
                task: .programSummary,
                system: EnzoCoachingVoiceGuide.systemPrompt,
                userText: prompt,
                model: ClaudeModel.preferred(for: .programSummary),
                maxTokens: 600
            )
            CoachMemoryStore.shared.setAISummary(summary)
            if let uid = profile?.userId ?? UserScopedStorage.currentUserId() {
                await WelcomePlanFirestoreRepository.shared.saveMemory(CoachMemoryStore.shared.memory, userId: uid)
            }
        } catch {}
    }
}
