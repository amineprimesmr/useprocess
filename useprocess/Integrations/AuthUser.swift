import FirebaseAuth
import Foundation

enum AuthUser {
    struct Session {
        let uid: String
        let displayName: String?
        let email: String?

        func createProfileChangeRequest() -> ProfileChangeRequestBridge? {
            guard AppConfiguration.firebaseConfigured,
                  let user = Auth.auth().currentUser,
                  user.uid == uid else {
                return nil
            }
            return ProfileChangeRequestBridge(request: user.createProfileChangeRequest())
        }
    }

    static var current: Session? {
        if AppConfiguration.firebaseConfigured, let user = Auth.auth().currentUser {
            return Session(
                uid: user.uid,
                displayName: user.displayName,
                email: user.email
            )
        }
        if AuthenticationManager.shared.isDemoSession {
            return Session(
                uid: AuthenticationManager.demoUserID,
                displayName: "Démo",
                email: nil
            )
        }
        return nil
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
