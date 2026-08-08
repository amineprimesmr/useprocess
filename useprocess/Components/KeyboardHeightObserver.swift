//
//  KeyboardHeightObserver.swift
//  Process
//
//  Hauteur réelle du clavier (overlap écran) — pour ancrer les CTAs au-dessus
//  sur tous les formats / locales (EN QuickType bar inclus), sans heuristique %.
//

import Combine
import SwiftUI
import UIKit

@MainActor
final class KeyboardHeightObserver: ObservableObject {
    @Published private(set) var height: CGFloat = 0

    private var cancellables = Set<AnyCancellable>()

    init() {
        // willChange = animation ; didChange = filet si la barre de suggestions
        // EN (QuickType) ajuste la frame après le will*.
        let willChange = NotificationCenter.default.publisher(
            for: UIResponder.keyboardWillChangeFrameNotification
        )
        let didChange = NotificationCenter.default.publisher(
            for: UIResponder.keyboardDidChangeFrameNotification
        )
        let willHide = NotificationCenter.default.publisher(
            for: UIResponder.keyboardWillHideNotification
        )
        let didHide = NotificationCenter.default.publisher(
            for: UIResponder.keyboardDidHideNotification
        )

        Publishers.MergeMany(willChange, didChange, willHide, didHide)
            .compactMap { Self.overlapHeight(from: $0) }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] overlap in
                self?.height = overlap
            }
            .store(in: &cancellables)
    }

    /// Overlap du clavier avec le bas de la fenêtre active (0 si masqué).
    private static func overlapHeight(from notification: Notification) -> CGFloat? {
        if notification.name == UIResponder.keyboardWillHideNotification
            || notification.name == UIResponder.keyboardDidHideNotification {
            return 0
        }

        guard
            let userInfo = notification.userInfo,
            let endFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
        else {
            return nil
        }

        guard let window = activeKeyWindow else {
            let screenHeight = ScreenMetrics.height
            guard screenHeight > 0 else { return max(0, endFrame.height) }
            return max(0, screenHeight - endFrame.origin.y)
        }

        let converted = window.convert(endFrame, from: nil)
        return max(0, window.bounds.maxY - converted.minY)
    }

    private static var activeKeyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }
}
