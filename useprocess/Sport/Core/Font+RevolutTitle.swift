//
//  Font+RevolutTitle.swift
//  Process
//
//  Style titre type Revolut (Paywall et overlays).
//

import SwiftUI

extension Font {
    static func revolutTitle(size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
}
