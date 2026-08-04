//
//  PaywallTrialRetentionView.swift
//  useprocess
//
//  Quick Action rétention — même page offre que après la roue winback.
//

import SwiftUI

struct PaywallTrialRetentionView: View {
    let source: ProcessHomeScreenQuickActionKind
    let onDismiss: () -> Void
    let onSubscribed: () -> Void

    var body: some View {
        PaywallSpinWinbackView(
            presentation: .offerOnly,
            analyticsSource: source.analyticsSource,
            onClaimed: onSubscribed
        )
    }
}
