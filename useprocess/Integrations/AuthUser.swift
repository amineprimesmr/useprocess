import FirebaseAuth
import FirebaseCore
import Foundation

enum AuthUser {
    struct Session {
        let uid: String
        let displayName: String?
        let email: String?

        func createProfileChangeRequest() -> ProfileChangeRequestBridge? {
            FirebaseBootstrap.configure()
            guard FirebaseBootstrap.isConfigured,
                  let user = Auth.auth().currentUser,
                  user.uid == uid else {
                return nil
            }
            return ProfileChangeRequestBridge(request: user.createProfileChangeRequest())
        }
    }

    static var current: Session? {
        guard AppConfiguration.firebaseConfigured else { return nil }
        FirebaseBootstrap.configure()
        guard FirebaseBootstrap.isConfigured, FirebaseApp.app() != nil else { return nil }
        guard let user = Auth.auth().currentUser else { return nil }
        return Session(
            uid: user.uid,
            displayName: user.displayName,
            email: user.email
        )
    }
}

struct ProfileChangeRequestBridge {
    private let request: UserProfileChangeRequest

    init(request: UserProfileChangeRequest) {
        self.request = request
    }

    var displayName: String? {
        get { request.displayName }
        set { request.displayName = newValue }
    }

    func commitChanges() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            request.commitChanges { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
