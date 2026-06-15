import Foundation

/// Nom d'affichage de l'app — remplace « Process » dans tous les textes utilisateur.
enum AppBranding {
    static var name: String {
        AppConfiguration.appDisplayName
    }

    static func replacingProcess(in text: String) -> String {
        text
            .replacingOccurrences(of: "Process", with: name)
            .replacingOccurrences(of: "process", with: name)
    }
}
