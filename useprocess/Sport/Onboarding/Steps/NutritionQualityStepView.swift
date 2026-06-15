//
//  NutritionQualityStepView.swift
//  Process
//
//  Vue pour évaluer la qualité de l'alimentation actuelle
//

import SwiftUI

struct NutritionQualityStepView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedQuality: NutritionQuality?
    var onValidationChanged: ((Bool) -> Void)?
    
    @State private var sliderValue: Double = 1.0  // Position par défaut : Améliorable (index 1)
    @State private var isDragging = false
    @State private var showImages = false
    @State private var imageScale: [CGFloat] = [0.0, 0.0, 0.0]
    @State private var imageRotation: [Double] = [0.0, 0.0, 0.0]
    @State private var imageOpacity: [Double] = [0.0, 0.0, 0.0]
    @State private var imagePulse: [CGFloat] = [1.0, 1.0, 1.0]
    @State private var currentQualityIndex: Int = 1  // Pour suivre la qualité actuelle
    @State private var didInitialize = false
    
    // ✅ 3 positions fixes : 0, 1, 2
    private let minValue: Double = 0.0
    private let maxValue: Double = 2.0
    
    // ✅ Les 3 qualités nutritionnelles
    private let nutritionQualities: [NutritionQuality] = [
        .poor,      // 0 : Mauvaise
        .average,   // 1 : Améliorable
        .excellent  // 2 : Excellente
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: OnboardingConstants.titleAreaHeight)

                    Spacer()
                        .frame(height: OnboardingConstants.titleToContentSpacing + geometry.size.height * 0.10)

                    VStack(spacing: 0) {
                        VStack(spacing: 30) {
                            // ✅ Affichage simple de la qualité sélectionnée avec description
                            if let quality = selectedQuality {
                                VStack(spacing: 12) {
                                    Text(OnboardingCopy.choiceLabel(
                                        index: nutritionQualities.firstIndex(of: quality) ?? 0,
                                        sport: quality.comment
                                    ))
                                        .font(.system(size: 38, weight: .bold))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: gradientColors(for: quality),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .id(quality.comment) // Force la réanimation lors du changement
                                    
                                    Text(OnboardingCopy.text(quality.description, blank: "Description à personnaliser"))
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundStyle(OnboardingTheme.footnoteText)
                                        .multilineTextAlignment(.center)
                                        .lineSpacing(6)
                                        .padding(.horizontal, 40)
                                        .id(quality.description) // Force la réanimation lors du changement
                                }
                                .padding(.vertical, 20)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.9)).combined(with: .move(edge: .bottom)),
                                    removal: .opacity.combined(with: .scale(scale: 0.9)).combined(with: .move(edge: .top))
                                ))
                            }
                            
                            // ✅ Slider épais horizontal avec 3 positions (style comme vitesse de perte de poids)
                            GeometryReader { geometry in
                                let sliderWidth = max(0, geometry.size.width - 80)
                                let sliderHeight: CGFloat = 50
                                let qualityProgress = max(0, min(1, sliderValue / maxValue))
                                
                            VStack(spacing: 0) {
                                    // Slider épais horizontal
                                    ZStack(alignment: .leading) {
                                        // Barre de fond (gris foncé)
                                        RoundedRectangle(cornerRadius: 25, style: .continuous)
                                            .fill(OnboardingTheme.segmentTrack(for: colorScheme))
                                            .frame(width: sliderWidth, height: sliderHeight)
                                        
                                        // Barre de progression avec dégradé dynamique selon la qualité
                                        if let quality = selectedQuality {
                                            RoundedRectangle(cornerRadius: 25, style: .continuous)
                                                .fill(
                                                    LinearGradient(
                                                        colors: gradientColors(for: quality),
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    )
                                                )
                                                .frame(width: max(0, sliderWidth * qualityProgress), height: sliderHeight)
                                                .animation(.easeInOut(duration: 0.4), value: selectedQuality)
                                        } else {
                                            RoundedRectangle(cornerRadius: 25, style: .continuous)
                                                .fill(
                                                    LinearGradient(
                                                        colors: [
                                                            Color(red: 0.13, green: 0.98, blue: 0.47),
                                                            Color(red: 0.65, green: 1.0, blue: 0.95)
                                                        ],
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    )
                                                )
                                                .frame(width: max(0, sliderWidth * qualityProgress), height: sliderHeight)
                                        }
                                        
                                        // Zones cliquables pour les 3 positions
                                        HStack(spacing: 0) {
                                            // Zone gauche (Mauvaise)
                                            Rectangle()
                                                .fill(Color.clear)
                                                .frame(width: max(0, sliderWidth / 3))
                                                .contentShape(Rectangle())
                                                .onTapGesture {
                                                    currentQualityIndex = 0
                                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                                        sliderValue = 0.0
                                                    }
                                                    updateQualitySmoothly(to: 0)
                                                    HapticManager.shared.selection()
                                                }
                                            
                                            // Zone centre (Améliorable)
                                            Rectangle()
                                                .fill(Color.clear)
                                                .frame(width: max(0, sliderWidth / 3))
                                                .contentShape(Rectangle())
                                                .onTapGesture {
                                                    currentQualityIndex = 1
                                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                                        sliderValue = 1.0
                                                    }
                                                    updateQualitySmoothly(to: 1)
                                                    HapticManager.shared.selection()
                                                }
                                            
                                            // Zone droite (Excellente)
                                            Rectangle()
                                                .fill(Color.clear)
                                                .frame(width: max(0, sliderWidth / 3))
                                                .contentShape(Rectangle())
                                                .onTapGesture {
                                                    currentQualityIndex = 2
                                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                                        sliderValue = 2.0
                                                    }
                                                    updateQualitySmoothly(to: 2)
                                                    HapticManager.shared.selection()
                                                }
                                        }
                                        .frame(width: sliderWidth, height: sliderHeight)
                                    }
                                    .frame(width: sliderWidth, height: sliderHeight)
                                    .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
                                    .padding(.horizontal, 40)
                                    .safeHorizontalDragGesture(
                                        onChanged: { value in
                                                if !isDragging {
                                                    isDragging = true
                                                    HapticManager.shared.impact(.light)
                                                }
                                                
                                                let location = value.location.x - 40
                                                let normalizedProgress = sliderWidth > 0
                                                    ? max(0, min(1, location / sliderWidth))
                                                    : 0
                                                
                                                // Snap direct aux 3 positions (0, 1, 2) - plus réactif
                                                let snappedIndex: Int
                                                if normalizedProgress < 0.33 {
                                                    snappedIndex = 0
                                                } else if normalizedProgress < 0.67 {
                                                    snappedIndex = 1
                                                } else {
                                                    snappedIndex = 2
                                                }
                                                
                                                // Mise à jour IMMÉDIATE et ultra fluide pendant le slide
                                                if currentQualityIndex != snappedIndex {
                                                    currentQualityIndex = snappedIndex
                                                    
                                                    // Animation ultra fluide et rapide pour le slider - snap direct
                                                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                                        sliderValue = Double(snappedIndex)
                                                    }
                                                    
                                                    // Mise à jour INSTANTANÉE de la qualité avec animation ultra fluide
                                                    // Pas de délai - tout change en temps réel pendant le slide
                                                    updateQualitySmoothly(to: snappedIndex)
                                                    HapticManager.shared.selection()
                                                }
                                        },
                                        onEnded: { _ in
                                            isDragging = false
                                            HapticManager.shared.impact(.light)
                                        }
                                    )
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .frame(height: 60)
                        }
                        .padding(.horizontal, 0)
                        
                        Spacer()
                    }
                }
                
                // ✅ Titre en OVERLAY - Position ABSOLUE depuis le haut de l'écran
                VStack {
                    OnboardingTitleView("Comment décrirais-tu", "ton alimentation ?")
                        .padding(.top, OnboardingConstants.titleTopPadding)
                    Spacer()
                }
                
                // ✅ Images animées dispersées dans tout l'écran selon la qualité
                if let quality = selectedQuality {
                    GeometryReader { geo in
                        ZStack {
                            // ========== MAUVAISE (Poor) ==========
                            // Pizza2 - plus proche du texte, haut gauche
                            if quality == .poor {
                                NutritionDecorIcon(name: "pizza2", systemName: "takeoutbag.and.cup.and.straw.fill", size: 65)
                                    .scaleEffect(imageScale[0] * imagePulse[0])
                                    .rotationEffect(.degrees(imageRotation[0]))
                                    .opacity(imageOpacity[0] * 0.75)
                                    .shadow(color: decorShadowColor(.orange), radius: decorShadowRadius, x: 3, y: 8)
                                    .position(
                                        x: geo.size.width * 0.25,
                                        y: geo.size.height * 0.38
                                    )
                                    .transition(.scale.combined(with: .opacity))
                            }
                            
                            // Coca - plus proche du texte, droite
                            if quality == .poor {
                                NutritionDecorIcon(name: "coca", systemName: "cup.and.saucer.fill", size: 58)
                                    .scaleEffect(imageScale[1] * imagePulse[1])
                                    .rotationEffect(.degrees(imageRotation[1]))
                                    .opacity(imageOpacity[1] * 0.75)
                                    .shadow(color: decorShadowColor(.red), radius: decorShadowRadius, x: -3, y: 8)
                                    .position(
                                        x: geo.size.width * 0.82,
                                        y: geo.size.height * 0.40
                                    )
                                    .transition(.scale.combined(with: .opacity))
                            }
                            
                            // Nutella - plus proche du slider, bas gauche
                            if quality == .poor {
                                NutritionDecorIcon(name: "nutella", systemName: "archivebox.fill", size: 62)
                                    .scaleEffect(imageScale[2] * imagePulse[2])
                                    .rotationEffect(.degrees(imageRotation[2]))
                                    .opacity(imageOpacity[2] * 0.75)
                                    .shadow(color: decorShadowColor(.brown), radius: decorShadowRadius, x: 4, y: -5)
                                    .position(
                                        x: geo.size.width * 0.28,
                                        y: geo.size.height * 0.68
                                    )
                                    .transition(.scale.combined(with: .opacity))
                            }
                            
                            // ========== AMÉLIORABLE (Average) ==========
                            // Pate2 - plus proche du texte, haut droite
                            if quality == .average {
                                NutritionDecorIcon(name: "pate2", systemName: "fork.knife", size: 63)
                                    .scaleEffect(imageScale[0] * imagePulse[0])
                                    .rotationEffect(.degrees(imageRotation[0]))
                                    .opacity(imageOpacity[0] * 0.75)
                                    .shadow(color: decorShadowColor(.yellow), radius: decorShadowRadius, x: -2, y: 6)
                                    .position(
                                        x: geo.size.width * 0.72,
                                        y: geo.size.height * 0.32
                                    )
                                    .transition(.scale.combined(with: .opacity))
                            }
                            
                            // Croissant - plus proche du texte, gauche
                            if quality == .average {
                                NutritionDecorIcon(name: "croissant", systemName: "birthday.cake.fill", size: 60)
                                    .scaleEffect(imageScale[1] * imagePulse[1])
                                    .rotationEffect(.degrees(imageRotation[1]))
                                    .opacity(imageOpacity[1] * 0.75)
                                    .shadow(color: decorShadowColor(.orange), radius: decorShadowRadius, x: 2, y: 7)
                                    .position(
                                        x: geo.size.width * 0.18,
                                        y: geo.size.height * 0.42
                                    )
                                    .transition(.scale.combined(with: .opacity))
                            }
                            
                            // Pouletcuisse - plus proche du slider, bas droite
                            if quality == .average {
                                NutritionDecorIcon(name: "pouletcuisse", systemName: "fork.knife.circle.fill", size: 64)
                                    .scaleEffect(imageScale[2] * imagePulse[2])
                                    .rotationEffect(.degrees(imageRotation[2]))
                                    .opacity(imageOpacity[2] * 0.75)
                                    .shadow(color: decorShadowColor(.brown), radius: decorShadowRadius, x: -4, y: -6)
                                    .position(
                                        x: geo.size.width * 0.70,
                                        y: geo.size.height * 0.67
                                    )
                                    .transition(.scale.combined(with: .opacity))
                            }
                            
                            // ========== EXCELLENTE (Excellent) ==========
                            // Viandeplato - plus proche du texte, gauche
                            if quality == .excellent {
                                NutritionDecorIcon(name: "viandeplato", systemName: "flame.fill", size: 66)
                                    .scaleEffect(imageScale[0] * imagePulse[0])
                                    .rotationEffect(.degrees(imageRotation[0]))
                                    .opacity(imageOpacity[0] * 0.75)
                                    .shadow(color: decorShadowColor(.green), radius: decorShadowRadius, x: 3, y: 5)
                                    .position(
                                        x: geo.size.width * 0.20,
                                        y: geo.size.height * 0.32
                                    )
                                    .transition(.scale.combined(with: .opacity))
                            }
                            
                            // Brocoli - plus proche du slider, droite
                            if quality == .excellent {
                                NutritionDecorIcon(name: "brocoli", systemName: "leaf.fill", size: 61)
                                    .scaleEffect(imageScale[1] * imagePulse[1])
                                    .rotationEffect(.degrees(imageRotation[1]))
                                    .opacity(imageOpacity[1] * 0.75)
                                    .shadow(color: decorShadowColor(.green), radius: decorShadowRadius, x: -3, y: -4)
                                    .position(
                                        x: geo.size.width * 0.74,
                                        y: geo.size.height * 0.70
                                    )
                                    .transition(.scale.combined(with: .opacity))
                            }
                            
                            // Banane - plus proche du texte, droite
                            if quality == .excellent {
                                NutritionDecorIcon(name: "banane", systemName: "carrot.fill", size: 59)
                                    .scaleEffect(imageScale[2] * imagePulse[2])
                                    .rotationEffect(.degrees(imageRotation[2]))
                                    .opacity(imageOpacity[2] * 0.75)
                                    .shadow(color: decorShadowColor(.yellow), radius: decorShadowRadius, x: 2, y: 9)
                                    .position(
                                        x: geo.size.width * 0.68,
                                        y: geo.size.height * 0.36
                                    )
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
        }
        .onAppear {
            guard !didInitialize else { return }
            didInitialize = true

            DispatchQueue.main.async {
                initializeSelectedQualityIfNeeded()
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showImages = true
            }
        }
    }

    private var decorShadowRadius: CGFloat {
        colorScheme == .dark ? 20 : 8
    }

    private func decorShadowColor(_ color: Color) -> Color {
        color.opacity(colorScheme == .dark ? 0.6 : 0.12)
    }

    private func sliderIndex(for quality: NutritionQuality) -> Int {
        switch quality {
        case .veryPoor, .poor:
            return 0
        case .average:
            return 1
        case .good, .veryGood, .excellent:
            return 2
        }
    }
    
    private func initializeSelectedQualityIfNeeded() {
        let selectedIndex: Int
        if let quality = selectedQuality {
            selectedIndex = sliderIndex(for: quality)
        } else {
            selectedIndex = 1
        }

        sliderValue = Double(selectedIndex)
        currentQualityIndex = selectedIndex
        syncSliderUI(to: selectedIndex, animated: false)
    }

    // ✅ Couleurs du dégradé selon la qualité
    private func gradientColors(for quality: NutritionQuality) -> [Color] {
        switch quality {
        case .poor:
            // Dégradé rouge-orange
            return [
                Color(red: 1.0, green: 0.3, blue: 0.2),      // Rouge pétant
                Color(red: 1.0, green: 0.5, blue: 0.0),      // Orange vif
                Color(red: 1.0, green: 0.65, blue: 0.2)     // Orange clair
            ]
        case .average:
            // Dégradé vert pétant clair (comme le slider)
            return [
                Color(red: 0.13, green: 0.98, blue: 0.47),   // Vert Process
                Color(red: 0.65, green: 1.0, blue: 0.95),    // Turquoise clair
                Color(red: 0.4, green: 1.0, blue: 0.7)       // Vert clair
            ]
        case .excellent:
            // Dégradé violet pétant presque rose (comme la carte nutrition)
            return [
                Color(red: 0.7, green: 0.4, blue: 0.94),     // Violet pétant
                Color(red: 0.94, green: 0.7, blue: 1.0),    // Rose-violet
                Color(red: 0.85, green: 0.5, blue: 0.98)     // Violet-rose
            ]
        default:
            return [.white]
        }
    }
    
    // ✅ Mapper la valeur du slider (0-2) aux 3 qualités nutritionnelles
    private func updateQuality(from value: Double) {
        let index = Int(value.clamped(to: 0...2))
        updateQualitySmoothly(to: index)
    }
    
    // ✅ Mise à jour ultra fluide de la qualité avec animations synchronisées
    private func updateQualitySmoothly(to index: Int) {
        syncSliderUI(to: index, animated: true)
    }

    private func syncSliderUI(to index: Int, animated: Bool) {
        let quality = nutritionQualities[index]

        // Binding hors animation — évite la perte de @Published pendant withAnimation
        selectedQuality = quality

        if animated {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                sliderValue = Double(index)
                currentQualityIndex = index
            }
        } else {
            sliderValue = Double(index)
            currentQualityIndex = index
        }

        withAnimation(.easeOut(duration: animated ? 0.15 : 0)) {
            imageScale = [0.0, 0.0, 0.0]
            imageOpacity = [0.0, 0.0, 0.0]
            imagePulse = [1.0, 1.0, 1.0]
            imageRotation = [0.0, 0.0, 0.0]
        }

        animateImages(for: quality)

        onValidationChanged?(true)
    }
    
    // ✅ Animation ultra fluide des images selon la qualité - INSTANTANÉE
    private func animateImages(for quality: NutritionQuality) {
        let baseDelay: Double = 0.05  // Délai minimal pour fluidité
        
        switch quality {
        case .poor:
            // Toutes les 3 images apparaissent pour "Mauvaise" avec animation en cascade ultra fluide
            // Pizza2 - apparaît immédiatement
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8).delay(baseDelay)) {
                imageScale[0] = 1.0
                imageOpacity[0] = 1.0
            }
            
            withAnimation(.easeOut(duration: 0.5).delay(baseDelay)) {
                imageRotation[0] = 360.0
            }
            
            // Pulsation continue pour pizza2
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(baseDelay + 0.3)) {
                imagePulse[0] = 1.08
            }
            
            // Coca - apparaît presque immédiatement après
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8).delay(baseDelay + 0.08)) {
                imageScale[1] = 1.0
                imageOpacity[1] = 1.0
            }
            
            withAnimation(.easeOut(duration: 0.5).delay(baseDelay + 0.08)) {
                imageRotation[1] = -360.0
            }
            
            // Pulsation continue pour coca
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(baseDelay + 0.38)) {
                imagePulse[1] = 1.08
            }
            
            // Nutella - apparaît presque immédiatement après
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8).delay(baseDelay + 0.15)) {
                imageScale[2] = 1.0
                imageOpacity[2] = 1.0
            }
            
            withAnimation(.easeOut(duration: 0.5).delay(baseDelay + 0.15)) {
                imageRotation[2] = 360.0
            }
            
            // Pulsation continue pour nutella
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(baseDelay + 0.45)) {
                imagePulse[2] = 1.08
            }
            
        case .average:
            // 3 images pour "Améliorable" : pate2, croissant, pouletcuisse
            // Pate2 - apparaît immédiatement
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8).delay(baseDelay)) {
                imageScale[0] = 1.0
                imageOpacity[0] = 1.0
            }
            
            withAnimation(.easeOut(duration: 0.5).delay(baseDelay)) {
                imageRotation[0] = 360.0
            }
            
            // Pulsation douce pour pate2
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(baseDelay + 0.3)) {
                imagePulse[0] = 1.05
            }
            
            // Croissant - apparaît presque immédiatement après
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8).delay(baseDelay + 0.08)) {
                imageScale[1] = 1.0
                imageOpacity[1] = 1.0
            }
            
            withAnimation(.easeOut(duration: 0.5).delay(baseDelay + 0.08)) {
                imageRotation[1] = -360.0
            }
            
            // Pulsation douce pour croissant
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(baseDelay + 0.38)) {
                imagePulse[1] = 1.05
            }
            
            // Pouletcuisse - apparaît presque immédiatement après
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8).delay(baseDelay + 0.15)) {
                imageScale[2] = 1.0
                imageOpacity[2] = 1.0
            }
            
            withAnimation(.easeOut(duration: 0.5).delay(baseDelay + 0.15)) {
                imageRotation[2] = 360.0
            }
            
            // Pulsation douce pour pouletcuisse
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(baseDelay + 0.45)) {
                imagePulse[2] = 1.05
            }
            
        case .excellent:
            // 3 images pour "Excellente" : viandeplato, brocoli, banane
            // Viandeplato - apparaît immédiatement
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8).delay(baseDelay)) {
                imageScale[0] = 1.0
                imageOpacity[0] = 1.0
            }
            
            withAnimation(.easeOut(duration: 0.5).delay(baseDelay)) {
                imageRotation[0] = 360.0
            }
            
            // Pulsation douce pour viandeplato
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(baseDelay + 0.3)) {
                imagePulse[0] = 1.05
            }
            
            // Brocoli - apparaît presque immédiatement après
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8).delay(baseDelay + 0.08)) {
                imageScale[1] = 1.0
                imageOpacity[1] = 1.0
            }
            
            withAnimation(.easeOut(duration: 0.5).delay(baseDelay + 0.08)) {
                imageRotation[1] = -360.0
            }
            
            // Pulsation douce pour brocoli
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(baseDelay + 0.38)) {
                imagePulse[1] = 1.05
            }
            
            // Banane - apparaît presque immédiatement après
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8).delay(baseDelay + 0.15)) {
                imageScale[2] = 1.0
                imageOpacity[2] = 1.0
            }
            
            withAnimation(.easeOut(duration: 0.5).delay(baseDelay + 0.15)) {
                imageRotation[2] = 360.0
            }
            
            // Pulsation douce pour banane
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(baseDelay + 0.45)) {
                imagePulse[2] = 1.05
            }
            
        default:
            break
        }
    }
}

// ✅ Extension pour clamp
extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}
