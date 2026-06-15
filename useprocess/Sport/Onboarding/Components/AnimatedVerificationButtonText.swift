//
//  AnimatedVerificationButtonText.swift
//  Process
//
//  Libellé du bouton « Continuer » sur l’étape prénom : état vérification / disponible.
//

import SwiftUI

struct AnimatedVerificationButtonText: View {
    var isAvailable: Bool

    var body: some View {
        Text(isAvailable ? "DISPONIBLE" : "VÉRIFICATION…")
            .font(.system(size: 20, weight: .black))
            .foregroundStyle(isAvailable ? Color.green.opacity(0.95) : Color.orange.opacity(0.95))
            .animation(.easeInOut(duration: 0.35), value: isAvailable)
    }
}
