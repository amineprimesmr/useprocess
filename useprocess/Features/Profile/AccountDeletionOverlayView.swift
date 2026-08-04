import SwiftUI

/// Overlay plein écran pendant la suppression de compte.
struct AccountDeletionOverlayView: View {
    @Environment(\.colorScheme) private var colorScheme

    let statusMessage: String

    @State private var ringRotation: Double = 0
    @State private var pulseScale: CGFloat = 0.92
    @State private var appeared = false

    private var accentGradient: LinearGradient {
        colorScheme == .dark
            ? LinearGradient(
                colors: [
                    Color(red: 0.52, green: 0.88, blue: 1.0),
                    Color(red: 0.20, green: 0.56, blue: 0.98)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            : LinearGradient(
                colors: [
                    Color(red: 0.28, green: 0.66, blue: 1.0),
                    Color(red: 0.08, green: 0.38, blue: 0.90)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
    }

    var body: some View {
        ZStack {
            Color.black.opacity(colorScheme == .dark ? 0.62 : 0.48)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .stroke(accentGradient.opacity(0.22), lineWidth: 10)
                        .frame(width: 74, height: 74)
                        .scaleEffect(pulseScale)

                    Circle()
                        .trim(from: 0.08, to: 0.72)
                        .stroke(
                            accentGradient,
                            style: StrokeStyle(lineWidth: 4.5, lineCap: .round)
                        )
                        .frame(width: 74, height: 74)
                        .rotationEffect(.degrees(ringRotation))

                    Image(systemName: "person.crop.circle.badge.minus")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(accentGradient)
                        .symbolRenderingMode(.hierarchical)
                }

                VStack(spacing: 8) {
                    Text("Suppression du compte")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(statusMessage)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .contentTransition(.opacity)
                        .animation(.easeInOut(duration: 0.28), value: statusMessage)

                    Text("Ne ferme pas l’application")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                }
                .padding(.horizontal, 8)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 34)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.18), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 28, y: 14)
            .scaleEffect(appeared ? 1 : 0.94)
            .opacity(appeared ? 1 : 0)
        }
        .contentShape(Rectangle())
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                appeared = true
            }
            withAnimation(.linear(duration: 1.15).repeatForever(autoreverses: false)) {
                ringRotation = 360
            }
            withAnimation(.easeInOut(duration: 1.05).repeatForever(autoreverses: true)) {
                pulseScale = 1.06
            }
        }
    }
}
