import FirebaseFirestore
import Foundation
import Observation

struct ProcessSupportMessage: Identifiable, Equatable {
    enum Role: String {
        case user
        case operatorRole = "operator"
    }

    enum Status: String {
        case sent
        case sending
        case failed
    }

    let id: String
    let role: Role
    let text: String
    let createdAt: Date
    var status: Status
}

@MainActor
@Observable
final class ProcessSupportChatViewModel {
    var messages: [ProcessSupportMessage] = []
    var inputText = ""
    var isSending = false
    var errorMessage: String?
    var isLoading = true

    private var listener: ListenerRegistration?
    private var pending: [ProcessSupportMessage] = []

    func start() {
        stop()
        guard let uid = AuthUser.current?.uid else {
            isLoading = false
            errorMessage = AppCopy.tSync(
                "Connecte-toi pour discuter avec l'équipe.",
                en: "Sign in to chat with the team."
            )
            return
        }

        listener = Firestore.firestore()
            .collection("users")
            .document(uid)
            .collection("supportMessages")
            .order(by: "createdAt", descending: false)
            .limit(to: 200)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    self?.applySnapshot(snapshot, error: error)
                }
            }
    }

    func stop() {
        listener?.remove()
        listener = nil
    }

    func sendCurrentMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }

        let messageId = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let pendingMessage = ProcessSupportMessage(
            id: messageId,
            role: .user,
            text: text,
            createdAt: Date(),
            status: .sending
        )

        inputText = ""
        isSending = true
        errorMessage = nil
        pending.append(pendingMessage)
        rebuildMessages(remote: remoteMessages)
        HapticManager.shared.impact(.light)

        let profile = UnifiedProfileService.shared.currentProfile
        let firstName = profile?.firstName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let nickname: String?
        if OnboardingViewModel.isRealUserFirstName(firstName) {
            nickname = firstName
        } else {
            nickname = AuthUser.current?.displayName
        }

        do {
            try await ProcessSupportRemoteService.send(
                text: text,
                messageId: messageId,
                nickname: nickname,
                email: AuthUser.current?.email
            )
            if let index = pending.firstIndex(where: { $0.id == messageId }) {
                pending[index].status = .sent
            }
            ProcessAnalytics.trackSupportMessageSent()
            rebuildMessages(remote: remoteMessages)
        } catch {
            if let index = pending.firstIndex(where: { $0.id == messageId }) {
                pending[index].status = .failed
            }
            errorMessage = error.localizedDescription
            rebuildMessages(remote: remoteMessages)
        }

        isSending = false
    }

    func retry(_ message: ProcessSupportMessage) async {
        guard message.status == .failed else { return }
        inputText = message.text
        pending.removeAll { $0.id == message.id }
        rebuildMessages(remote: remoteMessages)
        await sendCurrentMessage()
    }

    private var remoteMessages: [ProcessSupportMessage] {
        messages.filter { message in
            message.status == .sent && pending.allSatisfy { $0.id != message.id }
        }
    }

    private func applySnapshot(_ snapshot: QuerySnapshot?, error: Error?) {
        isLoading = false
        if let error {
            #if DEBUG
            print("[SupportChat] listen error: \(error.localizedDescription)")
            #endif
            if messages.isEmpty {
                errorMessage = AppCopy.tSync(
                    "Impossible de charger la conversation.",
                    en: "Couldn't load the conversation."
                )
            }
            return
        }

        let remote = snapshot?.documents.compactMap(Self.mapMessage) ?? []
        let remoteIDs = Set(remote.map(\.id))
        pending.removeAll { remoteIDs.contains($0.id) }
        rebuildMessages(remote: remote)
    }

    private func rebuildMessages(remote: [ProcessSupportMessage]) {
        let remoteIDs = Set(remote.map(\.id))
        let extras = pending.filter { !remoteIDs.contains($0.id) }
        messages = (remote + extras).sorted { $0.createdAt < $1.createdAt }
    }

    private static func mapMessage(_ document: QueryDocumentSnapshot) -> ProcessSupportMessage? {
        let data = document.data()
        let text = (data["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else { return nil }

        let from = data["from"] as? String ?? ""
        let role: ProcessSupportMessage.Role = from == "operator" ? .operatorRole : .user
        let createdAt: Date
        if let timestamp = data["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = Date()
        }

        return ProcessSupportMessage(
            id: document.documentID,
            role: role,
            text: text,
            createdAt: createdAt,
            status: .sent
        )
    }
}
