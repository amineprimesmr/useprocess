//
//  HapticManager.swift
//  Process
//
//  Created by ENNASRI Amine on 22/09/2025.
//

import Combine
import UIKit
import CoreHaptics

/// Gestionnaire centralisé pour les feedbacks haptiques
@MainActor
class HapticManager: ObservableObject {
    static let shared = HapticManager()

    private var hapticEngine: CHHapticEngine?
    private var isEngineReady = false
    private var typewriterFeedback: UIImpactFeedbackGenerator?
    private var lastTypewriterHapticTime: CFAbsoluteTime = 0
    private let typewriterMinInterval: CFAbsoluteTime = 0.038

    private init() {}

    private func setupHapticEngine() {
        // Vérifier si l'appareil supporte les haptiques
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            // Silencieux : Les générateurs de feedback simples fonctionnent toujours
            isEngineReady = false
            return
        }

        do {
            hapticEngine = try CHHapticEngine()

            // Gestion des interruptions (appels, etc.)
            hapticEngine?.stoppedHandler = { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor in
                    self.isEngineReady = false
                }
            }

            hapticEngine?.resetHandler = { [weak self] in
                guard let self = self else { return }
                Task { @MainActor in
                    do {
                        try self.hapticEngine?.start()
                        self.isEngineReady = true
                    } catch {
                        self.isEngineReady = false
                    }
                }
            }

            try hapticEngine?.start()
            isEngineReady = true
        } catch {
            // Silencieux : Les générateurs de feedback simples restent disponibles
            isEngineReady = false
        }
    }

    /// Feedback d'impact sécurisé
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        if hapticEngine == nil, CHHapticEngine.capabilitiesForHardware().supportsHaptics {
            setupHapticEngine()
        }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare() // ⚡️ CRUCIAL: Prépare le moteur haptique
        generator.impactOccurred()
    }

    /// Feedback de notification sécurisé
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare() // ⚡️ CRUCIAL: Prépare le moteur haptique
        generator.notificationOccurred(type)
    }

    /// Feedback de sélection sécurisé
    func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare() // ⚡️ CRUCIAL: Prépare le moteur haptique
        generator.selectionChanged()
    }

    /// Impact léger pour les interactions courantes
    func lightImpact() {
        impact(.light)
    }

    /// Impact moyen pour les actions importantes
    func mediumImpact() {
        impact(.medium)
    }

    /// Impact fort pour les actions critiques
    func heavyImpact() {
        impact(.heavy)
    }

    /// Impact souple pour les interactions douces
    func softImpact() {
        impact(.soft)
    }

    /// Impact rigide pour les interactions nettes
    func rigidImpact() {
        impact(.rigid)
    }

    /// Feedback de succès
    func success() {
        notification(.success)
    }

    /// Feedback d'avertissement
    func warning() {
        notification(.warning)
    }

    /// Feedback d'erreur
    func error() {
        notification(.error)
    }

    /// Haptique synchronisé avec une animation typewriter (une impulsion max toutes les ~38 ms).
    func typewriterCharacter(_ character: Character) {
        guard character != " " && character != "\n" && character != "\t" else { return }

        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastTypewriterHapticTime >= typewriterMinInterval else { return }
        lastTypewriterHapticTime = now

        if typewriterFeedback == nil {
            typewriterFeedback = UIImpactFeedbackGenerator(style: .soft)
        }
        typewriterFeedback?.prepare()

        let intensity: CGFloat
        switch character {
        case "!", ".", "?":
            intensity = 0.62
        default:
            intensity = 0.38
        }
        typewriterFeedback?.impactOccurred(intensity: intensity)
    }

    /// Arrête la session typewriter (changement d’onglet, fermeture, annulation).
    func endTypewriterSession() {
        typewriterFeedback = nil
        lastTypewriterHapticTime = 0
    }
}
