import SwiftUI
import UIKit

/// État observable du toast. La fenêtre n'étant pas observable, lire ses propriétés
/// stockées depuis SwiftUI ne redessinait jamais le toast (contenu vide, `onChange`
/// jamais déclenché) — d'où une fenêtre invisible qui restait interactive.
@Observable
final class DynamicIslandToastState {
    var toast: DynamicIslandToastMessage?
    var isPresented = false
}

final class DynamicIslandPassThroughWindow: UIWindow {
    let state = DynamicIslandToastState()

    /// Tap sur le toast lui-même.
    var onToastTap: (() -> Void)?
    /// Fermeture demandée depuis le toast — remontée au binding SwiftUI.
    var onDismissRequest: (() -> Void)?

    var toast: DynamicIslandToastMessage? {
        get { state.toast }
        set { state.toast = newValue }
    }

    var isPresented: Bool {
        get { state.isPresented }
        set { state.isPresented = newValue }
    }

    /// Ferme le toast **et** rend la main à l'app : sans le passage à
    /// `isUserInteractionEnabled = false`, la fenêtre continuait d'intercepter les taps.
    func requestDismiss() {
        state.isPresented = false
        isUserInteractionEnabled = false
        onDismissRequest?()
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard state.isPresented else { return nil }
        return super.hitTest(point, with: event)
    }
}
