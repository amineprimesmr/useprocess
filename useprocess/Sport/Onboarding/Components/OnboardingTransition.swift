//
//  OnboardingTransition.swift
//  Process
//
//  Transitions onboarding — spring + slide directionnel (début), smooth (suite).
//

import SwiftUI

// MARK: - Direction de transition

enum TransitionDirection {
    case forward
    case backward
}

// MARK: - Timing

enum OnboardingTransitionTiming {
    static let earlyKeyboardFocusDelay: TimeInterval = 0.62
    /// Focus pendant le slide de page (ex. taille → poids) pour monter le CTA avec le pad.
    static let keyboardFocusDuringPageTransitionDelay: TimeInterval = 0.14
}

// MARK: - Animations

extension Animation {
    /// Début onboarding (genre → prénom) — spring visible, comme avant.
    static var onboardingTransition: Animation {
        .spring(response: 0.42, dampingFraction: 0.86, blendDuration: 0.18)
    }

    /// Suite onboarding — fluide, sans rebond.
    static var onboardingPage: Animation {
        .smooth(duration: 0.33, extraBounce: 0)
    }

    static var onboardingScanPagePush: Animation {
        .smooth(duration: 0.40, extraBounce: 0)
    }

    /// Entrée dashboard depuis le chat Moss ou les témoignages — fondu + scale discret.
    static var onboardingDashboardReveal: Animation {
        .smooth(duration: 0.46, extraBounce: 0)
    }

    static var glowUpResultsCover: Animation {
        .smooth(duration: 0.40, extraBounce: 0)
    }
}

// MARK: - Transitions

extension AnyTransition {
    /// Slide questionnaire early — move(edge:) + fondu (genre → prénom).
    static func onboardingQuestionnaireSlide(direction: TransitionDirection) -> AnyTransition {
        .asymmetric(
            insertion: .move(edge: direction == .forward ? .trailing : .leading)
                .combined(with: .opacity),
            removal: .move(edge: direction == .forward ? .leading : .trailing)
                .combined(with: .opacity)
        )
    }

    /// Slide discret + crossfade — suite onboarding.
    static func onboardingPageSlide(direction: TransitionDirection) -> AnyTransition {
        let enterX: CGFloat = direction == .forward ? 22 : -22
        let exitX: CGFloat = direction == .forward ? -14 : 14
        return .asymmetric(
            insertion: .offset(x: enterX).combined(with: .opacity),
            removal: .offset(x: exitX).combined(with: .opacity)
        )
    }

    /// Flux scan / chat — push plus marqué.
    static func onboardingScanPagePush(direction: TransitionDirection) -> AnyTransition {
        .asymmetric(
            insertion: .move(edge: direction == .forward ? .trailing : .leading)
                .combined(with: .opacity),
            removal: .move(edge: direction == .forward ? .leading : .trailing)
                .combined(with: .opacity)
        )
    }

    /// Chat Moss / témoignages → dashboard — fondu croisé, sans slide latéral.
    static func onboardingDashboardReveal(direction: TransitionDirection) -> AnyTransition {
        let outgoingScale: CGFloat = direction == .forward ? 0.985 : 1.015
        return .asymmetric(
            insertion: .opacity
                .combined(with: .scale(scale: 0.975, anchor: .center)),
            removal: .opacity
                .combined(with: .scale(scale: outgoingScale, anchor: .center))
        )
    }

    /// Page glow-up : entre / sort par la droite.
    static var glowUpResultsCover: AnyTransition {
        .asymmetric(
            insertion: .offset(x: 28).combined(with: .opacity),
            removal: .offset(x: 28).combined(with: .opacity)
        )
    }
}

// MARK: - Flux scan onboarding (capture → analyse → résultats)

enum OnboardingScanFlowMotion {
    static let animation = Animation.onboardingScanPagePush
    static let forwardTransition = AnyTransition.onboardingScanPagePush(direction: .forward)
}

// MARK: - Layout onboarding (immersif vs questionnaire)

struct OnboardingStepLayoutModifier: ViewModifier {
    let immersive: Bool

    func body(content: Content) -> some View {
        if immersive {
            content.ignoresSafeArea()
        } else {
            content
                .ignoresSafeArea(.all)
                .regularWidthContainer(maxWidth: AdaptiveScreenLayout.onboardingChatMaxWidth)
        }
    }
}

// MARK: - Shake horizontal (feedback erreur)

struct OnboardingHorizontalShakeEffect: GeometryEffect {
    var shakes: CGFloat
    var amount: CGFloat = 10
    var shakesPerUnit: CGFloat = 3

    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(
                translationX: amount * sin(shakes * .pi * shakesPerUnit),
                y: 0
            )
        )
    }
}
