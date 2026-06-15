import SwiftUI

/// Évite « Publishing changes from within view updates » en reportant les mises à jour ObservableObject.
enum OnboardingValidationScheduler {
    @MainActor
    static func deferValidation(_ action: @escaping () -> Void) {
        DispatchQueue.main.async {
            action()
        }
    }
}

extension View {
    func deferOnboardingValidation(_ action: @escaping () -> Void) -> some View {
        onAppear {
            OnboardingValidationScheduler.deferValidation(action)
        }
    }
}
