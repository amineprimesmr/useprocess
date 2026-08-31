//
//  OnboardingWelcomeExplainerSteps.swift
//  Process
//
//  Bienvenue post-paiement + 3 explications (bodyfat, rétention d'eau, lymphe)
//  avant Sign in with Apple.
//

import SwiftUI

/// Contenu d'une page — icône, titre, texte, accent.
private struct OnboardingExplainerContent {
    let symbol: String
    let accent: Color
    let eyebrow: String
    let title: String
    let body: String
}

/// Une page plein écran — icône, titre, texte, CTA continuer. Réutilisée par les 4 étapes.
private struct OnboardingExplainerStepView: View {
    @Environment(\.colorScheme) private var colorScheme

    let content: OnboardingExplainerContent
    let onComplete: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: 22) {
                iconBadge

                VStack(spacing: 10) {
                    Text(content.eyebrow.uppercased())
                        .font(.system(size: 13, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(content.accent)

                    Text(content.title)
                        .font(.system(size: 27, weight: .bold))
                        .foregroundStyle(OnboardingTheme.primaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(content.body)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(OnboardingTheme.bodyText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 8)
                }
            }
            .padding(.horizontal, 32)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 14)

            Spacer(minLength: 0)

            continueButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OnboardingTheme.screenBackground.ignoresSafeArea())
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                appeared = true
            }
        }
    }

    private var iconBadge: some View {
        ZStack {
            Circle()
                .fill(content.accent.opacity(colorScheme == .dark ? 0.18 : 0.12))
                .frame(width: 96, height: 96)

            Image(systemName: content.symbol)
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(content.accent)
        }
    }

    private var continueButton: some View {
        Button {
            HapticManager.shared.impact(.medium)
            onComplete()
        } label: {
            Text(OnboardingCopy.continueCTAUpper)
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(OnboardingTheme.onboardingPrimaryActionText(for: colorScheme))
                .frame(maxWidth: .infinity)
                .frame(height: 58)
        }
        .onboardingPrimaryActionStyle()
        .padding(.horizontal, 34)
        .padding(.top, 8)
        .padding(.bottom, 50)
    }
}

// MARK: - 1. Bienvenue

struct OnboardingPostPaymentWelcomeStepView: View {
    let onComplete: () -> Void

    var body: some View {
        OnboardingExplainerStepView(
            content: OnboardingExplainerContent(
                symbol: "sparkles",
                accent: OnboardingTheme.accentHighlight,
                eyebrow: OnboardingCopy.t("Bienvenue", en: "Welcome"),
                title: OnboardingCopy.t("Bienvenue dans Process", en: "Welcome to Process"),
                body: OnboardingCopy.t(
                    "Avant de commencer, voici les 3 leviers qui débloquent un visage affiné et bien défini.",
                    en: "Before we start, here are the 3 levers that unlock a lean, well-defined face."
                )
            ),
            onComplete: onComplete
        )
    }
}

// MARK: - 2. Faible taux de graisse

struct OnboardingExplainerBodyFatStepView: View {
    let onComplete: () -> Void

    var body: some View {
        OnboardingExplainerStepView(
            content: OnboardingExplainerContent(
                symbol: "flame.fill",
                accent: Color(red: 1.0, green: 0.42, blue: 0.32),
                eyebrow: OnboardingCopy.t("Levier 1 / 3", en: "Lever 1 / 3"),
                title: OnboardingCopy.t("Un faible taux de graisse", en: "A low body fat percentage"),
                body: OnboardingCopy.t(
                    "En dessous de 15%, la graisse qui masque tes traits (joues, mâchoire) disparaît et ta définition faciale ressort naturellement.",
                    en: "Below 15%, the fat that hides your features (cheeks, jawline) fades away and your facial definition comes through naturally."
                )
            ),
            onComplete: onComplete
        )
    }
}

// MARK: - 3. Rétention d'eau

struct OnboardingExplainerWaterRetentionStepView: View {
    let onComplete: () -> Void

    var body: some View {
        OnboardingExplainerStepView(
            content: OnboardingExplainerContent(
                symbol: "drop.fill",
                accent: Color(red: 0.35, green: 0.68, blue: 1.0),
                eyebrow: OnboardingCopy.t("Levier 2 / 3", en: "Lever 2 / 3"),
                title: OnboardingCopy.t("Élimine la rétention d'eau", en: "Eliminate water retention"),
                body: OnboardingCopy.t(
                    "Une alimentation moins salée et une hydratation régulière dégonflent le visage en quelques jours — c'est le levier le plus rapide.",
                    en: "Eating less sodium and staying steadily hydrated debloats your face within days — it's the fastest lever."
                )
            ),
            onComplete: onComplete
        )
    }
}

// MARK: - 4. Circulation lymphatique

struct OnboardingExplainerLymphDrainageStepView: View {
    let onComplete: () -> Void

    var body: some View {
        OnboardingExplainerStepView(
            content: OnboardingExplainerContent(
                symbol: "arrow.triangle.2.circlepath",
                accent: Color(red: 0.42, green: 0.82, blue: 0.6),
                eyebrow: OnboardingCopy.t("Levier 3 / 3", en: "Lever 3 / 3"),
                title: OnboardingCopy.t("Fais circuler la lymphe", en: "Get your lymph moving"),
                body: OnboardingCopy.t(
                    "Le mouvement et le drainage manuel évacuent les fluides stagnants du visage — mâchoire et contours plus nets, gonflement en moins.",
                    en: "Movement and manual drainage clear stagnant fluid from your face — sharper jawline and contours, less puffiness."
                )
            ),
            onComplete: onComplete
        )
    }
}
