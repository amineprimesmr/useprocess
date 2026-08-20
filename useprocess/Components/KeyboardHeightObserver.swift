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
    /// Dernière hauteur connue — projection CTA pendant willShow (taille → poids).
    @Published private(set) var lastKnownOverlap: CGFloat = 0
    /// Durée UIKit du clavier en cours (willChange / willHide).
    @Published private(set) var transitionDuration: TimeInterval = 0.33

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
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.apply(notification)
            }
            .store(in: &cancellables)
    }

    private func apply(_ notification: Notification) {
        guard let overlap = Self.overlapHeight(from: notification) else { return }
        if overlap > 0 {
            lastKnownOverlap = overlap
        }
        if let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval {
            transitionDuration = max(0.2, duration)
        }
        height = overlap
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
