import SwiftUI

/// Récupère la fenêtre principale pour créer la fenêtre overlay Dynamic Island.
struct WindowExtractor: UIViewRepresentable {
    var result: (UIWindow) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        DispatchQueue.main.async {
            if let window = view.window {
                result(window)
            }
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
