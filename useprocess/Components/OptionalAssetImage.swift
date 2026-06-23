import SwiftUI

/// Image asset avec repli SF Symbol si l'asset a été retiré du catalogue.
struct OptionalAssetImage: View {
    let name: String
    var systemName: String = "photo"
    var contentMode: ContentMode = .fit
    var width: CGFloat?
    var height: CGFloat?
    var maxWidth: CGFloat? = .infinity
    var maxHeight: CGFloat?
    var foregroundStyle: Color = .white.opacity(0.9)

    var body: some View {
        Group {
            if ProcessAssetCatalog.contains(name) {
                Image(name)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Image(systemName: systemName)
                    .font(.system(size: min(height ?? width ?? 48, 64)))
                    .foregroundStyle(foregroundStyle)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: width, height: height)
        .frame(maxWidth: maxWidth, maxHeight: maxHeight)
    }
}
