import SwiftUI

/// Indicateur de carousel : page active en tiret rempli, les autres en point plein.
struct ProcessCarouselPageMark: View {
    let isSelected: Bool
    var activeColor: Color
    var inactiveColor: Color

    private let height: CGFloat = 7
    private let dashWidth: CGFloat = 20

    var body: some View {
        Capsule(style: .continuous)
            .fill(isSelected ? activeColor : inactiveColor)
            .frame(width: isSelected ? dashWidth : height, height: height)
            .animation(.easeInOut(duration: 0.22), value: isSelected)
    }
}
