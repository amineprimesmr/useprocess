//
//  AgeWheelPicker.swift
//  Process
//
//  Roulette d'âge verticale. Tout le défilement est natif : aimantation par
//  `scrollTargetBehavior(.viewAligned)`, sélection par `scrollPosition(id:)`,
//  et l'effet de profondeur passe par `visualEffect` — calculé au rendu, sans
//  jamais écrire dans du `@State` pendant le scroll.
//

import SwiftUI

struct AgeWheelPicker: View {
    @Binding var selectedAge: Int
    let minAge: Int
    let maxAge: Int
    let onAgeChanged: ((Int) -> Void)?

    /// Âge centré, piloté par le ScrollView lui-même.
    @State private var centeredAge: Int?

    private let itemHeight: CGFloat = 92
    private let visibleItems: Int = 5 // impair : un item au centre

    private var wheelHeight: CGFloat { CGFloat(visibleItems) * itemHeight }

    init(
        selectedAge: Binding<Int>,
        minAge: Int,
        maxAge: Int,
        onAgeChanged: ((Int) -> Void)? = nil
    ) {
        _selectedAge = selectedAge
        self.minAge = minAge
        self.maxAge = maxAge
        self.onAgeChanged = onAgeChanged
        _centeredAge = State(initialValue: min(max(selectedAge.wrappedValue, minAge), maxAge))
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(minAge...maxAge, id: \.self) { age in
                    AgeItem(age: age, itemHeight: itemHeight)
                        .id(age)
                        .onTapGesture {
                            withAnimation(.snappy(duration: 0.3)) { centeredAge = age }
                        }
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $centeredAge, anchor: .center)
        // Marges = le premier et le dernier âge peuvent atteindre le centre.
        .contentMargins(.vertical, (wheelHeight - itemHeight) / 2, for: .scrollContent)
        .scrollDismissesKeyboard(.never)
        .frame(height: wheelHeight)
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.20),
                    .init(color: .black, location: 0.80),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .onChange(of: centeredAge) { _, newValue in
            guard let newValue, newValue != selectedAge else { return }
            selectedAge = newValue
            HapticManager.shared.selection()
            onAgeChanged?(newValue)
        }
        .onChange(of: selectedAge) { _, newValue in
            // Changement venu de l'extérieur (valeur restaurée, etc.).
            let clamped = min(max(newValue, minAge), maxAge)
            guard clamped != centeredAge else { return }
            centeredAge = clamped
        }
        .accessibilityElement()
        .accessibilityLabel(OnboardingCopy.t("Âge", en: "Age"))
        .accessibilityValue("\(selectedAge)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: selectedAge = min(selectedAge + 1, maxAge)
            case .decrement: selectedAge = max(selectedAge - 1, minAge)
            @unknown default: break
            }
        }
    }
}

// MARK: - Item d'âge individuel avec effet de distance
private struct AgeItem: View {
    let age: Int
    let itemHeight: CGFloat

    var body: some View {
        Text("\(age)")
            // Taille fixe : seule une transformation GPU varie au scroll,
            // jamais la mise en page du texte.
            .font(.system(size: 88, weight: .bold))
            // Pas de `monospacedDigit` : il écarte les chiffres (« 2 0 »). Tracking serré.
            .tracking(-3)
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        OnboardingTheme.primaryText,
                        OnboardingTheme.primaryText.opacity(0.95),
                        Color.gray.opacity(0.6)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .fixedSize()
            .frame(maxWidth: .infinity)
            .frame(height: itemHeight)
            .contentShape(Rectangle())
            .visualEffect { [itemHeight] content, proxy in
                let viewport = proxy.bounds(of: .scrollView(axis: .vertical)) ?? .zero
                let midY = proxy.frame(in: .scrollView(axis: .vertical)).midY
                // 0 au centre, 1 à un item de distance, plafonné à 2,5 items.
                let distance = abs(midY - viewport.height / 2) / itemHeight
                let near = min(distance, 1)
                let far = min(max(distance - 1, 0), 1.5) / 1.5

                return content
                    .scaleEffect(1 - near * 0.44 - far * 0.16)
                    .opacity(1 - near * 0.5 - far * 0.3)
            }
    }
}
