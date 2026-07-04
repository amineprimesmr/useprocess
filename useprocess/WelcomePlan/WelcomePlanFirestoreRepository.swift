import FirebaseFirestore
import Foundation

struct WelcomePlanCloudPayload: Codable {
    var planJSON: String?
    var questionnaireJSON: String?
    var memoryJSON: String?
    var updatedAt: Date
}

@MainActor
final class WelcomePlanFirestoreRepository {
    static let shared = WelcomePlanFirestoreRepository()

    private var db: Firestore { Firestore.firestore() }

    private init() {}

    private func docRef(userId: String) -> DocumentReference {
        db.collection("users").document(userId).collection("welcomePlan").document("current")
    }

    func savePlan(_ plan: FaceOriginPlan, userId: String) async {
        guard !AppSession.shared.isAccountWipeInProgress else { return }
        guard AppConfiguration.firebaseConfigured, userId != "local-user", !userId.isEmpty else { return }
        guard let json = await Task.detached(priority: .utility, operation: {
            Self.encode(plan)
        }).value else { return }
        try? await docRef(userId: userId).setData([
            "planJSON": json,
            "updatedAt": Timestamp(date: Date())
        ], merge: true)
    }

    func saveQuestionnaire(_ questionnaire: WelcomePlanQuestionnaireState, userId: String) async {
        guard AppConfiguration.firebaseConfigured, userId != "local-user", !userId.isEmpty else { return }
        guard let json = await Task.detached(priority: .utility, operation: {
            Self.encode(questionnaire)
        }).value else { return }
        try? await docRef(userId: userId).setData([
            "questionnaireJSON": json,
            "updatedAt": Timestamp(date: Date())
        ], merge: true)
    }

    func saveMemory(_ memory: CoachGlobalMemory, userId: String) async {
        guard AppConfiguration.firebaseConfigured, userId != "local-user", !userId.isEmpty else { return }
        guard let data = try? JSONEncoder().encode(memory),
              let json = String(data: data, encoding: .utf8) else { return }
        try? await docRef(userId: userId).setData([
            "memoryJSON": json,
            "updatedAt": Timestamp(date: Date())
        ], merge: true)
    }

    func fetchRemote(userId: String) async -> WelcomePlanCloudPayload? {
        guard AppConfiguration.firebaseConfigured, userId != "local-user", !userId.isEmpty else { return nil }
        guard let snap = try? await docRef(userId: userId).getDocument(), snap.exists else { return nil }

        let updatedAt = (snap.data()?["updatedAt"] as? Timestamp)?.dateValue() ?? Date.distantPast
        return WelcomePlanCloudPayload(
            planJSON: snap.data()?["planJSON"] as? String,
            questionnaireJSON: snap.data()?["questionnaireJSON"] as? String,
            memoryJSON: snap.data()?["memoryJSON"] as? String,
            updatedAt: updatedAt
        )
    }

    func syncFromRemote(userId: String) async {
        guard let remote = await fetchRemote(userId: userId) else { return }

        if let planJSON = remote.planJSON,
           let data = planJSON.data(using: .utf8),
           let remotePlan = await Task.detached(priority: .utility, operation: {
               try? JSONDecoder().decode(FaceOriginPlan.self, from: data)
           }).value {
            let localKey = UserScopedStorage.key("welcome.plan", userId: userId)
            let localUpdated = await localPlanUpdatedAt(userId: userId)
            if remotePlan.lastUpdated > localUpdated {
                UserDefaults.standard.set(data, forKey: localKey)
                let storedProgress = StoredOriginPlanProgress(
                    progress: remotePlan.progress,
                    lastUpdated: remotePlan.lastUpdated
                )
                if let progressData = try? JSONEncoder().encode(storedProgress) {
                    UserDefaults.standard.set(
                        progressData,
                        forKey: UserScopedStorage.key("welcome.plan.progress", userId: userId)
                    )
                }
            }
        }

        if let questionnaireJSON = remote.questionnaireJSON,
           let data = questionnaireJSON.data(using: .utf8),
           let remoteQuestionnaire = try? JSONDecoder().decode(WelcomePlanQuestionnaireState.self, from: data) {
            let localKey = UserScopedStorage.key("welcome.questionnaire", userId: userId)
            let localCompleted = UserDefaults.standard.data(forKey: localKey)
                .flatMap { try? JSONDecoder().decode(WelcomePlanQuestionnaireState.self, from: $0) }?
                .completedAt ?? .distantPast
            let remoteCompleted = remoteQuestionnaire.completedAt ?? .distantPast
            if remote.updatedAt > localCompleted || remoteCompleted > localCompleted {
                UserDefaults.standard.set(data, forKey: localKey)
            }
        }

        if let memoryJSON = remote.memoryJSON,
           let data = memoryJSON.data(using: .utf8),
           let remoteMemory = try? JSONDecoder().decode(CoachGlobalMemory.self, from: data) {
            let localKey = UserScopedStorage.key("coach.global.memory", userId: userId)
            if let localData = UserDefaults.standard.data(forKey: localKey),
               let localMemory = try? JSONDecoder().decode(CoachGlobalMemory.self, from: localData),
               remoteMemory.lastUpdated > localMemory.lastUpdated {
                UserDefaults.standard.set(data, forKey: localKey)
            } else if UserDefaults.standard.data(forKey: localKey) == nil {
                UserDefaults.standard.set(data, forKey: localKey)
            }
        }
    }

    private func localPlanUpdatedAt(userId: String) async -> Date {
        let key = UserScopedStorage.key("welcome.plan", userId: userId)
        let progressKey = UserScopedStorage.key("welcome.plan.progress", userId: userId)
        let planData = UserDefaults.standard.data(forKey: key)
        let progressData = UserDefaults.standard.data(forKey: progressKey)
        let dates = await Task.detached(priority: .utility) {
            let planDate = planData
                .flatMap { try? JSONDecoder().decode(FaceOriginPlan.self, from: $0) }?
                .lastUpdated ?? .distantPast
            let progressDate = progressData
                .flatMap { try? JSONDecoder().decode(StoredOriginPlanProgress.self, from: $0) }?
                .lastUpdated ?? .distantPast
            return (planDate, progressDate)
        }.value
        let (planDate, progressDate) = dates
        return max(planDate, progressDate)
    }

    nonisolated private static func encode<T: Encodable>(_ value: T) -> String? {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
