import FirebaseAuth
import SwiftUI

@MainActor
@Observable
final class ProcessAffiliateStore {
    static let shared = ProcessAffiliateStore()

    private(set) var dashboard: ProcessAffiliateDashboardResponse?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private init() {}

    func reload() async {
        guard FirebaseBootstrap.isConfigured,
              AuthUser.current != nil,
              ClaudeConfiguration.functionsBaseURL != nil else {
            dashboard = nil
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            dashboard = try await AffiliateRemoteService.dashboard()
        } catch let error as AffiliateRemoteError {
            if case .httpError(404, _) = error {
                dashboard = nil
            } else {
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearForSignOut() {
        dashboard = nil
        errorMessage = nil
        isLoading = false
    }
}
