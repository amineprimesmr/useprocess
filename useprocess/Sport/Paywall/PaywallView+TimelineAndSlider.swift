//
//  PaywallView+TimelineAndSlider.swift
//  Process
//
//  Timeline post-déblocage, fond, navigation, menu, feuille code promo, slider de déblocage.
//  Voir PaywallView+Content (layout principal) et PaywallView+PurchaseActions (achat / restore).
//

import SwiftUI
import StoreKit
import UIKit

extension PaywallView {

    // MARK: - Subviews

    // ✅ Timeline avec design moderne (icônes dans cercles + traits fins)
    var timelineView: some View {
        HStack(alignment: .top, spacing: LayoutConstants.isIPad ? 24 : 10) {
            // ✅ Grande image paywall alignée à gauche (remplace les trois icônes)
            if let paywallImage = UIImage(named: "paywall") {
                Image(uiImage: paywallImage)
                    .resizable()
                    .renderingMode(.original)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: LayoutConstants.isIPad ? 200 : 160, height: LayoutConstants.isIPad ? 600 : 480)
                    .opacity(iconOpacity[0])
                    .scaleEffect(iconScale[0])
                    .animation(
                        .spring(response: 0.6, dampingFraction: 0.7)
                        .delay(0.15),
                        value: iconScale[0]
                    )
            } else {
                // Fallback si l'image n'existe pas
                VStack(spacing: 50) {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1.2)
                        .frame(width: 44, height: 44)
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1.2)
                        .frame(width: 44, height: 44)
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1.2)
                        .frame(width: 64, height: 64)
                }
                .frame(width: LayoutConstants.isIPad ? 150 : 120)
            }

            // ✅ Texte à droite de l'image
            VStack(alignment: .leading, spacing: LayoutConstants.isIPad ? 64 : 52) {
                // Jour 1
                VStack(alignment: .leading, spacing: 4) {
                    Text("Jour 1")
                        .font(.system(size: LayoutConstants.isIPad ? LayoutConstants.Typography.bodySize + 2 : 18, weight: .semibold, design: .default))
                        .foregroundColor(.white)
                        .strikethrough(true, color: .white)
                        .opacity(textOpacity[0])
                        .offset(x: textOffset[0])
                        .animation(
                            .spring(response: 0.6, dampingFraction: 0.7)
                            .delay(0.15 + 0.2),
                            value: textOpacity[0]
                        )

                    Text("Télécharger l'application \(AppBranding.name)")
                        .font(.system(size: LayoutConstants.isIPad ? 15 : 13, weight: .regular, design: .default))
                        .foregroundColor(.gray)
                        .strikethrough(true, color: .gray.opacity(0.5))
                        .opacity(textOpacity[0])
                        .offset(x: textOffset[0])
                        .animation(
                            .spring(response: 0.6, dampingFraction: 0.7)
                            .delay(0.15 + 0.3),
                            value: textOpacity[0]
                        )
                }

                // Accès
                timelineTextItem(
                    title: "Accès",
                    description: "Obtiens toutes les fonctionnalités",
                    index: 1
                )

                // Jour 2
                timelineTextItem(
                    title: "Jour 2",
                    description: "Nous t'enverrons un rappel de fin d'essai",
                    index: 2
                )

                // Accès illimité
                timelineTextItem(
                    title: "Accès illimité",
                    description: "Facturation le \(billingDateFormatted), annulable à tout moment",
                    index: 3
                )
            }
            .padding(.top, LayoutConstants.isIPad ? 98 : 78)
            .offset(x: LayoutConstants.isIPad ? 0 : -50)
        }
    }

    // ✅ Item de texte pour la timeline (sans icône)
    func timelineTextItem(
        title: String,
        description: String,
        index: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: LayoutConstants.isIPad ? LayoutConstants.Typography.bodySize + 2 : 18, weight: .semibold, design: .default))
                .foregroundColor(.white)
                .opacity(textOpacity[index])
                .offset(x: textOffset[index])
                .animation(
                    .spring(response: 0.6, dampingFraction: 0.7)
                    .delay(Double(index) * 0.15 + 0.2),
                    value: textOpacity[index]
                )

            Text(description)
                .font(.system(size: LayoutConstants.isIPad ? 15 : 13, weight: .regular, design: .default))
                .foregroundColor(.gray)
                .opacity(textOpacity[index])
                .offset(x: textOffset[index])
                .animation(
                    .spring(response: 0.6, dampingFraction: 0.7)
                    .delay(Double(index) * 0.15 + 0.3),
                    value: textOpacity[index]
                )
        }
    }

    // ✅ Item de timeline avec icône dans cercle
    func timelineItem(
        iconImage: String,
        iconColor: Color,
        title: String,
        description: String,
        subtitle: String?,
        subtitleDescription: String?,
        showLine: Bool,
        lineHeight: CGFloat,
        index: Int,
        isLarge: Bool = false
    ) -> some View {
        let circleSize: CGFloat = isLarge ? 64 : 44 // Cercles réduits
        let imageSize: CGFloat = isLarge ? 60 : 32 // Images réduites

        return HStack(alignment: .top, spacing: 12) {
            // ✅ Icône dans cercle avec trait de connexion
            VStack(spacing: 0) {
                // Cercle avec icône - Sans fond coloré (sauf pour acces qui n'a pas de cercle)
                Group {
                    if isLarge {
                        // Pour acces : pas de cercle, juste l'image, mais alignée avec les cercles
                        Group {
                            if UIImage(named: iconImage) != nil {
                                Image(iconImage)
                                    .resizable()
                                    .renderingMode(.original)
                                    .scaledToFit()
                                    .frame(width: imageSize, height: imageSize)
                            } else {
                                Image(systemName: iconImage)
                                    .font(.system(size: imageSize * 0.7, weight: .semibold))
                                    .frame(width: imageSize, height: imageSize)
                                    .foregroundColor(iconColor)
                            }
                        }
                        .frame(width: circleSize, height: circleSize, alignment: .leading) // Même largeur que les cercles, aligné à gauche comme les autres
                        .offset(x: -2) // Légèrement décalé vers la gauche
                    } else {
                        // Pour les autres : cercle avec image
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1.2)
                                .frame(width: circleSize, height: circleSize)

                            // Essayer d'abord comme image Asset, sinon comme SF Symbol
                            Group {
                                if UIImage(named: iconImage) != nil {
                                    Image(iconImage)
                                        .resizable()
                                        .renderingMode(.original) // Mode original pour afficher l'image telle quelle
                                        .scaledToFit()
                                        .frame(width: imageSize, height: imageSize)
                                } else {
                                    Image(systemName: iconImage)
                                        .font(.system(size: imageSize * 0.7, weight: .semibold))
                                        .frame(width: imageSize, height: imageSize)
                                        .foregroundColor(iconColor)
                                }
                            }
                        }
                    }
                }
                .scaleEffect(iconScale[index])
                .opacity(iconOpacity[index])
                .animation(
                    .spring(response: 0.6, dampingFraction: 0.7)
                    .delay(Double(index) * 0.15),
                    value: iconScale[index]
                )

                // ✅ Couloir très épais et très foncé de connexion
                if showLine {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.9), // ✅ Beaucoup plus foncé
                                    Color.white.opacity(0.85),
                                    Color.white.opacity(0.8),
                                    Color.white.opacity(0.75)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 16, height: lineHeight) // ✅ Encore plus épais (de 10 à 16)
                        .opacity(lineOpacity[index])
                        .animation(
                            .easeInOut(duration: 0.8)
                            .delay(Double(index) * 0.15 + 0.3),
                            value: lineOpacity[index]
                        )
                }
            }
            .frame(width: isLarge ? imageSize : circleSize)

            // Texte
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .default))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.white,
                                Color.white.opacity(0.95),
                                Color.gray.opacity(0.6)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                    .opacity(textOpacity[index])
                    .offset(x: textOffset[index])
                    .animation(
                        .spring(response: 0.6, dampingFraction: 0.7)
                        .delay(Double(index) * 0.15 + 0.2),
                        value: textOpacity[index]
                    )

                Text(description)
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundColor(.gray)
                    .opacity(textOpacity[index])
                    .offset(x: textOffset[index])
                    .animation(
                        .spring(response: 0.6, dampingFraction: 0.7)
                        .delay(Double(index) * 0.15 + 0.3),
                        value: textOpacity[index]
                    )

                if let subtitle = subtitle, let subtitleDesc = subtitleDescription {
                    Text(subtitle)
                        .font(.system(size: 14, weight: .semibold, design: .default))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.white,
                                    Color.white.opacity(0.95),
                                    Color.gray.opacity(0.6)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                        .padding(.top, 2)
                        .opacity(textOpacity[index])
                        .offset(x: textOffset[index])
                        .animation(
                            .spring(response: 0.6, dampingFraction: 0.7)
                            .delay(Double(index) * 0.15 + 0.4),
                            value: textOpacity[index]
                        )

                    Text(subtitleDesc)
                        .font(.system(size: 12, weight: .regular, design: .default))
                        .foregroundColor(.gray)
                        .opacity(textOpacity[index])
                        .offset(x: textOffset[index])
                        .animation(
                            .spring(response: 0.6, dampingFraction: 0.7)
                            .delay(Double(index) * 0.15 + 0.5),
                            value: textOpacity[index]
                        )
                }
            }
            .padding(.leading, index == 2 ? -4 : 4) // Pour "Accès illimité" (index 2), décalé vers la gauche
        }
    }

    var backgroundView: some View {
        ZStack {
            Color.black

            // Image de fond paypage
            if let paypageImage = UIImage(named: "paypage") {
                Image(uiImage: paypageImage)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea(.all)
            } else {
                // Fallback si l'image n'existe pas
                RadialGradient(
                    colors: [
                        // Centre en haut - mauve pâle très clair avec plus de bleu clair
                        Color(red: 0.85, green: 0.78, blue: 0.98).opacity(0.5),
                        // Milieu - mauve pâle moyen avec plus de bleu
                        Color(red: 0.70, green: 0.63, blue: 0.92).opacity(0.35),
                        // Extérieur - mauve pâle foncé avec plus de bleu
                        Color(red: 0.50, green: 0.43, blue: 0.78).opacity(0.25),
                        // Bords - plus sombre pour effet circulaire
                        Color(red: 0.20, green: 0.15, blue: 0.30).opacity(0.15),
                        // Bords extérieurs - presque transparent
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.5, y: -0.2),
                    startRadius: 0,
                    endRadius: 700
                )
            }
        }
        .ignoresSafeArea(.all)
    }

    var backButtonView: some View {
        VStack {
            HStack {
                Button(action: {
                    HapticManager.shared.impact(.light)
                    if let onBack = onBack {
                        onBack()
                    } else {
                        dismiss()
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 34, height: 34)
                }
                .glassStyle()
                .buttonBorderShape(.circle)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 50)

            Spacer()
        }
    }

    // ✅ Bouton menu avec 3 points en haut à droite
    // ✅ Bouton menu avec 3 points en haut à droite - MENU NATIF iOS
    var menuButtonView: some View {
        VStack {
            HStack {
                Spacer()

                // ✅ Menu natif iOS avec les mêmes fonctions
                Menu {
                    // Option Restaurer
                    Button(action: {
                        HapticManager.shared.impact(.light)
                        Task {
                            await restorePurchases()
                        }
                    }) {
                        Label("Restaurer", systemImage: "arrow.clockwise")
                    }
                    .disabled(isRestoring || isPurchasing)

                    Divider()

                    // Option J'ai un code
                    Button(action: {
                        HapticManager.shared.impact(.light)
                        presentCodeRedemption()
                    }) {
                        Label("J'ai un code", systemImage: "giftcard")
                    }

                } label: {
                    // Bouton avec 3 points
                    HStack(spacing: 3) {
                        Circle()
                            .fill(Color.white.opacity(0.8))
                            .frame(width: 3, height: 3)
                        Circle()
                            .fill(Color.white.opacity(0.8))
                            .frame(width: 3, height: 3)
                        Circle()
                            .fill(Color.white.opacity(0.8))
                            .frame(width: 3, height: 3)
                    }
                    .frame(width: 34, height: 34)
                }
                .glassStyle()
                .buttonBorderShape(.circle)
                .padding(.horizontal, 20)
                .padding(.top, 50)
            }

            Spacer()
        }
    }

    // ✅ Présenter la feuille de code promo
    @MainActor
    func presentCodeRedemption() {
        Task {
            // StoreKit 2 - Présenter la feuille de code promo
            do {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    try await AppStore.presentOfferCodeRedeemSheet(in: windowScene)
                } else {
                    errorMessage = "Impossible d'ouvrir la page de code promo. Veuillez réessayer."
                    showError = true
                }
            } catch {
                errorMessage = "Impossible d'ouvrir la page de code promo. Veuillez réessayer."
                showError = true
            }
        }
    }

    // ✅ Vue du slider interactif - EXACTEMENT COMME LE BOUTON (LiquidGlass)
    var unlockSliderView: some View {
        GeometryReader { geometry in
            let sliderWidth = geometry.size.width

            ZStack(alignment: .leading) {
                // ✅ BOUTON LIQUIDGLASS COMME FOND (exactement comme le bouton final)
                let sliderHeight: CGFloat = 40 // Épaisseur du bouton liquidglass (NE PAS MODIFIER)
                let progressHeight: CGFloat = 60 // Épaisseur de la barre blanche et du rond (plus épais)

                Button(action: {}) {
                    Text("Obtenir un essai gratuit")
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.gray,
                                    Color(white: 0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: sliderHeight)
                }
                .glassStyle()
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .allowsHitTesting(false) // Désactiver le clic, on utilise le drag

                // Barre de progression (blanc éclatant) - Plus épaisse que le bouton
                Capsule()
                    .fill(Color.white)
                    .frame(width: max(0, sliderProgress * sliderWidth))
                    .frame(height: progressHeight)
                    .opacity(1.0)

                // Indicateur de slide (rond avec flèche) - Plus épais, visible au début
                if sliderProgress < 0.1 {
                    HStack(spacing: 0) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: progressHeight, height: progressHeight)
                    .overlay(
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.black)
                            )
                    }
                    .offset(x: 0)
                    .opacity(1.0)
                }

                // Zone de gesture invisible sur tout le slider
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: sliderWidth, height: sliderHeight)
                    .contentShape(Rectangle())
                    .safeHorizontalDragGesture(
                        onChanged: { value in
                            let newProgress = max(0, min(1, value.location.x / sliderWidth))
                            sliderProgress = newProgress

                            if newProgress > 0.1 && newProgress < 0.95 {
                                HapticManager.shared.impact(.light)
                            }
                        },
                        onEnded: { _ in
                            if sliderProgress >= 0.95 && !isSliderUnlocked {
                                HapticManager.shared.notification(.success)

                                withAnimation(.easeInOut(duration: 0.5)) {
                                    titleOpacity = 0
                                }

                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                    currentTitle = "Débloque ton accès illimité à \(AppBranding.name)"
                                    withAnimation(.easeInOut(duration: 0.5)) {
                                        titleOpacity = 1.0
                                    }
                                }

                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.2)) {
                                        isSliderUnlocked = true
                                        buttonScale = 1.0
                                        buttonOffsetY = 0
                                        buttonOpacity = 1.0
                                        morphProgress = 1.0
                                        sliderTransformOpacity = 0
                                    }
                                }
                            } else if sliderProgress < 0.95 {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    sliderProgress = 0
                                }
                                HapticManager.shared.impact(.light)
                            }
                        }
                    )
            }
        }
        .frame(height: 40) // Épaisseur du bouton liquidglass
    }
}
