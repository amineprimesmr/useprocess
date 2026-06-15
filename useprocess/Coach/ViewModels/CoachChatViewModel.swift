import Foundation
import SwiftUI

@MainActor
@Observable
final class CoachChatViewModel {
    var messages: [CoachMessage] = []
    var inputText = ""
    var isSending = false
    var streamingText = ""
    var errorMessage: String?
    var claudeConfigured = ClaudeConfiguration.isConfigured
    var transportLabel = ClaudeConfiguration.transportLabel

    private var profile: UnifiedUserProfile?
    private var userId: String? { profile?.userId.isEmpty == false ? profile?.userId : AuthUser.current?.uid }

    func bind(profile: UnifiedUserProfile?) {
        self.profile = profile
        claudeConfigured = ClaudeConfiguration.isConfigured
        transportLabel = ClaudeConfiguration.transportLabel
    }

    func loadThreadIfNeeded() async {
        let stored = await CoachSyncService.loadThread(userId: userId)
        if stored.messages.isEmpty {
            let welcome = CoachEngine.welcomeMessage(profile: profile)
            messages = [welcome]
            await CoachSyncService.appendMessage(welcome, userId: userId)
        } else {
            messages = stored.messages
        }
    }

    func sendCurrentMessage() async {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }
        await sendPrompt(trimmed, persistUserMessage: true)
    }

    func runTool(_ tool: CoachTool) async {
        guard !isSending else { return }
        let prompt = tool.label
        let userMsg = CoachMessage(role: .user, text: "🔹 \(prompt)")
        messages.append(userMsg)
        await CoachSyncService.appendMessage(userMsg, userId: userId)
        isSending = true
        streamingText = ""
        errorMessage = nil
        defer { isSending = false; streamingText = "" }

        do {
            let reply = try await CoachEngine.runTool(tool, profile: profile)
            messages.append(reply)
            await CoachSyncService.appendMessage(reply, userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func sendPrompt(_ trimmed: String, persistUserMessage: Bool) async {
        if persistUserMessage {
            let userMsg = CoachMessage(role: .user, text: trimmed)
            messages.append(userMsg)
            await CoachSyncService.appendMessage(userMsg, userId: userId)
            inputText = ""
        }

        isSending = true
        streamingText = ""
        errorMessage = nil
        defer { isSending = false }

        do {
            var assembled = ""
            for try await chunk in CoachEngine.streamChatMessage(trimmed, profile: profile) {
                assembled += chunk
                streamingText = assembled
            }

            streamingText = ""
            let model = ClaudeModel.preferred(for: .chat).rawValue
            let reply = CoachMessage(role: .assistant, text: assembled, modelUsed: model)
            messages.append(reply)
            await CoachSyncService.appendMessage(reply, userId: userId)
        } catch {
            errorMessage = error.localizedDescription
            streamingText = ""
        }
    }

    func resetConversation() async {
        await CoachSyncService.resetThread(userId: userId)
        let welcome = CoachEngine.welcomeMessage(profile: profile)
        messages = [welcome]
        await CoachSyncService.appendMessage(welcome, userId: userId)
    }
}
