import SwiftUI

/// Affichage plein écran des résultats — style WHOOP, photo dans l'anneau.
struct FaceScanResultView: View {
    let result: FaceScanResult
    var onDone: () -> Void

    var body: some View {
        FaceScanWhoopAnalysisScreen(
            result: result,
            history: FaceScanHistoryStore.shared.history,
            showsDoneButton: true,
            onDone: onDone
        )
    }
}

/// Contenu partagé — résultat post-scan et historique.
struct FaceScanResultContent: View {
    let result: FaceScanResult
    var mediaHeight: CGFloat = 280
    var previous: FaceScanResult?
    var history: [FaceScanResult] = []

    var body: some View {
        FaceScanWhoopAnalysisScreen(
            result: result,
            previous: previous,
            history: history.isEmpty ? FaceScanHistoryStore.shared.history : history
        )
    }
}
