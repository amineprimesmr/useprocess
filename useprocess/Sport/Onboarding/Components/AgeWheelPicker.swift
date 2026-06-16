//
//  AgeWheelPicker.swift
//  Process
//
//  Roulette personnalisée ultra fluide pour la sélection d'âge
//  Scroll vertical avec animations incroyables
//

import SwiftUI

// MARK: - PreferenceKey pour les positions des items
struct ItemPositionPreferenceKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]

    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

/// Offset vertical du contenu du `ScrollView` (coordonnées nommées `"scroll"`).
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct AgeWheelPicker: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedAge: Int
    let minAge: Int
    let maxAge: Int
    let onAgeChanged: ((Int) -> Void)?

    @State private var scrollOffset: CGFloat = 0
    @State private var isScrolling: Bool = false
    @State private var dragVelocity: CGFloat = 0
    @State private var lastDragTime: Date = Date()
    @State private var scrollTask: Task<Void, Never>?
    @State private var itemPositions: [Int: CGFloat] = [:] // Stocker les positions Y de chaque âge
    @State private var lastVibratedAge: Int? // Pour éviter les vibrations répétées
    @State private var hasInitialized: Bool = false // ✅ Pour éviter les changements automatiques au démarrage

    // Constantes pour le design
    private let itemHeight: CGFloat = 80
    private let visibleItems: Int = 5 // Nombre d'items visibles (impair pour avoir un centre)

    var body: some View {
        GeometryReader { geometry in
            let centerY = geometry.size.height / 2

            ZStack {
                // Masques de dégradé en haut et en bas pour effet fade
                VStack {
                    LinearGradient(
                        colors: OnboardingTheme.wheelFadeGradient(from: colorScheme, reversed: false),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: itemHeight * 2)
                    .allowsHitTesting(false)

                    Spacer()

                    LinearGradient(
                        colors: OnboardingTheme.wheelFadeGradient(from: colorScheme, reversed: true),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: itemHeight * 2)
                    .allowsHitTesting(false)
                }

                // ScrollView avec les âges
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            // Espace en haut pour centrer le premier item
                            Spacer()
                                .frame(height: centerY - itemHeight / 2)

                            // Items d'âge
                            ForEach(minAge...maxAge, id: \.self) { age in
                                AgeItem(
                                    age: age,
                                    isSelected: age == selectedAge,
                                    itemHeight: itemHeight,
                                    centerY: centerY,
                                    scrollOffset: scrollOffset
                                )
                                .id(age)
                            }

                            // Espace en bas pour centrer le dernier item
                            Spacer()
                                .frame(height: centerY - itemHeight / 2)
                        }
                        .background(
                            GeometryReader { scrollGeometry in
                                Color.clear
                                    .preference(
                                        key: ScrollOffsetPreferenceKey.self,
                                        value: scrollGeometry.frame(in: .named("scroll")).minY
                                    )
                            }
                        )
                    }
                    .coordinateSpace(name: "scroll")
                    .scrollDismissesKeyboard(.never)
                    .onPreferenceChange(ItemPositionPreferenceKey.self) { positions in
                        // Mettre à jour toutes les positions
                        // Les positions sont dans le coordinate space "scroll"
                        // Le centre du ScrollView dans ce coordinate space est aussi à centerY
                        itemPositions = positions
                        // Mettre à jour l'âge sélectionné
                        updateSelectedAgeFromPositions(centerY: centerY)
                    }
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                        let now = Date()
                        let timeDelta = now.timeIntervalSince(lastDragTime)
                        if timeDelta > 0 {
                            dragVelocity = (value - scrollOffset) / CGFloat(timeDelta)
                        }
                        scrollOffset = value
                        lastDragTime = now

                        // Annuler la tâche précédente de snap
                        scrollTask?.cancel()

                        // Mettre à jour l'âge sélectionné en temps réel basé sur les positions
                        updateSelectedAgeFromPositions(centerY: centerY)

                        // Si la vitesse est très faible, snap immédiatement
                        if abs(dragVelocity) < 50 {
                            // Snap immédiat si on bouge très lentement
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                snapToNearestAge(proxy: proxy, centerY: centerY)
                            }
                        } else {
                            // Programmer un snap après l'arrêt du scroll
                            scrollTask = Task {
                                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms après l'arrêt
                                if !Task.isCancelled {
                                    snapToNearestAge(proxy: proxy, centerY: centerY)
                                }
                            }
                        }
                    }
                    .onAppear {
                        let initialAge = min(max(selectedAge, minAge), maxAge)

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            scrollToAge(initialAge, proxy: proxy, animated: false)

                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                hasInitialized = true
                            }
                        }
                    }
                    .onChange(of: selectedAge) { _, newValue in
                        if !isScrolling {
                            scrollToAge(newValue, proxy: proxy, animated: true)
                        }
                    }
                }
            }
        }
        .frame(height: CGFloat(visibleItems) * itemHeight)
    }

    private func scrollToAge(_ age: Int, proxy: ScrollViewProxy, animated: Bool) {
        if animated {
            withAnimation(.onboardingTransition) {
                proxy.scrollTo(age, anchor: .center)
            }
        } else {
            proxy.scrollTo(age, anchor: .center)
        }
    }

    private func updateSelectedAgeFromPositions(centerY: CGFloat) {
        // ✅ IGNORER les changements automatiques avant l'initialisation complète
        if !hasInitialized {
            return
        }

        // Trouver l'âge le plus proche du centre en utilisant les positions réelles
        var nearestAge: Int?
        var minDistance: CGFloat = .infinity

        for (age, position) in itemPositions {
            let distance = abs(position - centerY)
            if distance < minDistance {
                minDistance = distance
                nearestAge = age
            }
        }

        guard let age = nearestAge, age >= minAge && age <= maxAge else { return }

        // ✅ PROTECTION: Ne JAMAIS remplacer 25 par des valeurs suspectes
        let invalidDefaultAges: Set<Int> = [minAge, 13, 16, 21]
        if selectedAge == 25 && invalidDefaultAges.contains(age) {
            // Si on est à 25 et que le scroll détecte une valeur par défaut, ignorer complètement
            return
        }

        if age != selectedAge {
            isScrolling = true
            selectedAge = age

            // Vibration incroyable quand on scroll et qu'un nouvel âge est sélectionné
            if lastVibratedAge != age {
                HapticManager.shared.selection()
                lastVibratedAge = age
            }

            onAgeChanged?(age)

            // Réinitialiser le flag après un court délai
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isScrolling = false
            }
        }
    }

    private func snapToNearestAge(proxy: ScrollViewProxy, centerY: CGFloat) {
        // Trouver l'âge le plus proche du centre
        var nearestAge: Int?
        var minDistance: CGFloat = .infinity

        for (age, position) in itemPositions {
            let distance = abs(position - centerY)
            if distance < minDistance {
                minDistance = distance
                nearestAge = age
            }
        }

        guard let age = nearestAge, age >= minAge && age <= maxAge else {
            // Si pas de positions, utiliser scrollToAge directement avec l'âge actuel
            scrollToAge(selectedAge, proxy: proxy, animated: true)
            return
        }

        // TOUJOURS snap vers l'âge le plus proche, même si c'est déjà sélectionné
        // Cela garantit que la roulette est toujours parfaitement centrée sur un chiffre
        // Ne pas mettre à jour selectedAge si c'est déjà le bon pour éviter les boucles
        if age != selectedAge {
            isScrolling = true
            selectedAge = age
            onAgeChanged?(age)
        }

        // TOUJOURS faire le scroll pour centrer parfaitement, même si l'âge est déjà sélectionné
        scrollToAge(age, proxy: proxy, animated: true)

        // Réinitialiser le flag après l'animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isScrolling = false
        }
    }
}

// MARK: - Item d'âge individuel avec effet de distance
struct AgeItem: View {
    let age: Int
    let isSelected: Bool
    let itemHeight: CGFloat
    let centerY: CGFloat
    let scrollOffset: CGFloat

    // Calculer la distance depuis le centre pour l'effet de perspective
    // On utilise GeometryReader pour obtenir la position réelle
    var body: some View {
        GeometryReader { geometry in
            let itemCenter = geometry.frame(in: .named("scroll")).midY
            let distanceFromCenter = abs(itemCenter - centerY)
            let maxDistance = itemHeight * 2.5
            let normalizedDistance = min(1.0, distanceFromCenter / maxDistance)

            let scale = 1.0 - (normalizedDistance * 0.35) // Réduire jusqu'à 65% de la taille
            let opacity = 1.0 - (normalizedDistance * 0.7) // Réduire jusqu'à 30% d'opacité

            Text("\(age)")
                .font(.system(size: isSelected ? 100 : 56, weight: .bold, design: .default))
                .foregroundStyle(
                    isSelected ?
                    LinearGradient(
                        colors: [
                            OnboardingTheme.primaryText,
                            OnboardingTheme.primaryText.opacity(0.95),
                            Color.gray.opacity(0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ) :
                    LinearGradient(
                        colors: [
                            OnboardingTheme.primaryText.opacity(0.6),
                            OnboardingTheme.primaryText.opacity(0.5),
                            Color.gray.opacity(0.4)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(scale)
                .opacity(opacity)
                .frame(maxWidth: .infinity)
                .frame(height: itemHeight)
                .contentShape(Rectangle())
                .animation(.onboardingTransition, value: isSelected)
                .background(
                    GeometryReader { itemGeometry in
                        Color.clear
                            .preference(
                                key: ItemPositionPreferenceKey.self,
                                value: [age: itemGeometry.frame(in: .named("scroll")).midY]
                            )
                    }
                )
        }
        .frame(height: itemHeight)
    }
}
