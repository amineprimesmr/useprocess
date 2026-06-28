import SwiftUI

enum ProfileTopChromeMetrics {
    static let barHeight: CGFloat = 40
    static let horizontalPadding: CGFloat = 16
    static let topPadding: CGFloat = 8
}

struct ProfileTopChromeActionButton: View {
    let systemName: String
    let accessibilityLabel: String
    let action: () -> Void

    private let barShape = Capsule()

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.primary)
                .frame(width: ProfileTopChromeMetrics.barHeight, height: ProfileTopChromeMetrics.barHeight)
                .contentShape(barShape)
        }
        .buttonStyle(ProcessGlassPressStyle())
        .processGlassEffect(in: barShape, interactive: true)
        .accessibilityLabel(accessibilityLabel)
    }
}
