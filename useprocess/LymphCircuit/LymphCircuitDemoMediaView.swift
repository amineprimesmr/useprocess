import SwiftUI

/// Média démo circuit — remplit le conteneur parent (PiP ou plein écran).
struct LymphCircuitDemoMediaView: View {
    let step: FaceMorningRoutineCatalog.Step
    var isPlaybackActive: Bool = true
    var isPip: Bool = true

    var body: some View {
        ZStack {
            if let url = LymphCircuitVideoCatalog.demoURL(for: step) {
                FaceScanSilentVideoLoopView(url: url, isPlaybackActive: isPlaybackActive)
            } else if let assetName = step.assetName {
                Image(assetName)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color.black.opacity(0.55)
                    Image(systemName: step.fallbackIcon)
                        .font(isPip ? .title2.weight(.semibold) : .largeTitle.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .accessibilityLabel(step.shortTitle)
    }
}
