//
//  AnimatedVerificationButtonText.swift
//  Process
//
//  Libellé du bouton « Continuer » sur l’étape prénom : état vérification / disponible.
//

import SwiftUI

struct AnimatedVerificationButtonText: View {
    var isAvailable: Bool
    @State private var animateDots = false

    var body: some View {
        HStack(spacing: 8) {
            if isAvailable {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .black))
                Text("DISPONIBLE")
            } else {
                ProgressView()
                    .controlSize(.small)
                    .tint(Color.orange.opacity(0.95))
                Text("VÉRIFICATION")
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(Color.orange.opacity(0.95))
                            .frame(width: 4, height: 4)
                            .scaleEffect(animateDots ? 1.25 : 0.55)
                            .opacity(animateDots ? 1.0 : 0.35)
                            .animation(
                                .easeInOut(duration: 0.45)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.14),
                                value: animateDots
                            )
                    }
                }
            }
        }
        .font(.system(size: 20, weight: .black))
        .foregroundStyle(isAvailable ? Color.green.opacity(0.95) : Color.orange.opacity(0.95))
        .animation(.easeInOut(duration: 0.35), value: isAvailable)
        .onAppear {
            animateDots = true
        }
    }
}
