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
    private var cardHoldTimer: Timer?
    private var cardHoldFeedback: UIImpactFeedbackGenerator?
    /// Reste sous la limite système de 32 messages/s observée sur appareil réel.
    private let cardHoldInterval: TimeInterval = 0.04

    // Engagement hold (maintien doigt onboarding)
    private var engagementHoldActive = false
    private var engagementHoldProgress: Double = 0
    private var engagementHoldLastTick: CFAbsoluteTime = 0
    private var engagementHoldGenerator: UIImpactFeedbackGenerator?
    private var engagementHoldStyle: UIImpactFeedbackGenerator.FeedbackStyle = .soft

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
                Task { @MainActor [weak self] in
                    self?.isEngineReady = false
                }
            }

            hapticEngine?.resetHandler = { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self else { return }
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

    /// Vibrations légères ultra-rapides tant que le doigt reste sur la carte (style Opal).
    func beginContinuousCardHold() {
        endContinuousCardHold()

        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        cardHoldFeedback = generator
        generator.impactOccurred(intensity: 0.34)

        cardHoldTimer = Timer.scheduledTimer(withTimeInterval: cardHoldInterval, repeats: true) { _ in
            DispatchQueue.main.async {
                HapticManager.shared.tickContinuousCardHold()
            }
        }
    }

    func endContinuousCardHold() {
        cardHoldTimer?.invalidate()
        cardHoldTimer = nil
        cardHoldFeedback = nil
    }

    private func tickContinuousCardHold() {
        guard let cardHoldFeedback else { return }
        cardHoldFeedback.impactOccurred(intensity: 0.22)
        cardHoldFeedback.prepare()
    }

    // MARK: - Engagement hold crescendo

    /// Démarre un crescendo haptique fiable pour le maintien du doigt (onboarding).
    func beginEngagementHoldCrescendo() {
        endEngagementHoldCrescendo()
        engagementHoldActive = true
        engagementHoldProgress = 0
        engagementHoldLastTick = 0
        engagementHoldStyle = .soft
        engagementHoldGenerator = UIImpactFeedbackGenerator(style: .soft)
        engagementHoldGenerator?.prepare()
        tickEngagementHoldCrescendo(force: true)
    }

    /// Met à jour la progression 0…1 et déclenche un tick si l'intervalle est écoulé.
    func updateEngagementHoldProgress(_ progress: Double) {
        guard engagementHoldActive else { return }
        engagementHoldProgress = min(1, max(0, progress))
        refreshEngagementHoldGeneratorIfNeeded()
        tickEngagementHoldCrescendo(force: false)
    }

    /// Pulse fort une seule fois par jalon (engagement validé visuellement).
    func engagementMilestonePulse() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred(intensity: 0.95)
    }

    func endEngagementHoldCrescendo() {
        engagementHoldActive = false
        engagementHoldProgress = 0
        engagementHoldLastTick = 0
        engagementHoldGenerator = nil
    }

    private func refreshEngagementHoldGeneratorIfNeeded() {
        let desiredStyle: UIImpactFeedbackGenerator.FeedbackStyle
        switch engagementHoldProgress {
        case ..<0.34:
            desiredStyle = .soft
        case ..<0.68:
            desiredStyle = .medium
        default:
            desiredStyle = .heavy
        }

        guard desiredStyle != engagementHoldStyle else { return }
        engagementHoldStyle = desiredStyle
        engagementHoldGenerator = UIImpactFeedbackGenerator(style: desiredStyle)
        engagementHoldGenerator?.prepare()
    }

    private func tickEngagementHoldCrescendo(force: Bool) {
        guard engagementHoldActive, let generator = engagementHoldGenerator else { return }

        let now = CFAbsoluteTimeGetCurrent()
        let progress = engagementHoldProgress

        // Intervalle qui se resserre : ~120 ms → ~40 ms (sous la limite iOS ~32/s).
        let minInterval = 0.04 + (1.0 - progress) * 0.08

        if !force, now - engagementHoldLastTick < minInterval { return }
        engagementHoldLastTick = now

        let intensity = CGFloat(0.25 + progress * 0.75)
        generator.impactOccurred(intensity: intensity)
        generator.prepare()
    }
}
