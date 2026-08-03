//
//  TickPicker.swift
//  useprocess
//
//  Picker horizontal à graduations.
//  `scrollPosition` seul est trop fragile au montage — on force via ScrollViewReader.
//

import SwiftUI

struct TickConfig {
    var tickWidth: CGFloat = 3
    var tickHeight: CGFloat = 30
    var tickHPadding: CGFloat = 3
    var inActiveHeightProgress: CGFloat = 0.55
    var interactionHeight: CGFloat = 60
    var activeTint: Color = .yellow
    var inActiveTint: Color = .primary
    var alignment: Alignment = .bottom
    var animation: Animation = .interpolatingSpring(duration: 0.3, bounce: 0, initialVelocity: 0)

    enum Alignment: String, CaseIterable {
        case top = "Top"
        case bottom = "Bottom"
        case center = "Center"

        var value: SwiftUI.Alignment {
            switch self {
            case .top: return .top
            case .bottom: return .bottom
            case .center: return .center
            }
        }
    }
}

struct TickPicker: View {
    var count: Int
    var config: TickConfig = .init()
    @Binding var selection: Int

    @State private var centeredIndex: Int
    @State private var animationRange: ClosedRange<Int>
    @State private var scrollPhase: ScrollPhase = .idle
    @State private var isReady = false
    @State private var isProgrammaticScroll = false

    init(count: Int, config: TickConfig = .init(), selection: Binding<Int>) {
        self.count = count
        self.config = config
        self._selection = selection
        let safe = Self.clamped(selection.wrappedValue, count: count)
        _centeredIndex = State(initialValue: safe)
        _animationRange = State(initialValue: safe...safe)
    }

    var body: some View {
        GeometryReader { geometry in
            let sidePad = max(0, (geometry.size.width - tickSlotWidth) / 2)

            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    // HStack (pas Lazy) : tous les ticks existent pour que scrollTo marche au 1er frame.
                    HStack(spacing: 0) {
                        ForEach(0...count, id: \.self) { index in
                            tickView(index)
                                .id(index)
                        }
                    }
                    .frame(height: config.tickHeight)
                    .frame(maxHeight: .infinity)
                    .contentShape(.rect)
                    .scrollTargetLayout()
                }
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne))
                .safeAreaPadding(.horizontal, sidePad)
                .onScrollGeometryChange(for: CGFloat.self) {
                    $0.contentOffset.x + $0.contentInsets.leading
                } action: { _, newValue in
                    guard isReady, !isProgrammaticScroll else { return }
                    guard scrollPhase != .idle else { return }

                    let index = Self.clamped(
                        Int((newValue / tickSlotWidth).rounded()),
                        count: count
                    )
                    let previous = centeredIndex
                    guard index != previous else { return }

                    centeredIndex = index
                    let lo = min(previous, index)
                    let hi = max(previous, index)
                    animationRange = lo...hi

                    if selection != index {
                        selection = index
                    }
                }
                .onScrollPhaseChange { _, newPhase in
                    scrollPhase = newPhase
                    if newPhase == .idle {
                        animationRange = centeredIndex...centeredIndex
                        // Snap final au centre si besoin.
                        if isReady, !isProgrammaticScroll {
                            snap(to: centeredIndex, proxy: proxy, animated: true)
                        }
                    }
                }
                .task {
                    await settleInitialScroll(proxy: proxy)
                }
                .onChange(of: selection) { _, newValue in
                    let safe = Self.clamped(newValue, count: count)
                    guard isReady, safe != centeredIndex else { return }
                    snap(to: safe, proxy: proxy, animated: true)
                }
            }
        }
        .frame(height: config.interactionHeight)
    }

    @ViewBuilder
    private func tickView(_ index: Int) -> some View {
        let isInside = animationRange.contains(index)
        let isActive = centeredIndex == index
        let fillColor = isActive
            ? config.activeTint
            : config.inActiveTint.opacity(isInside ? 1 : 0.4)

        Rectangle()
            .fill(fillColor)
            .frame(
                width: config.tickWidth,
                height: config.tickHeight * (isInside || isActive ? 1 : config.inActiveHeightProgress)
            )
            .frame(width: tickSlotWidth, height: config.tickHeight, alignment: config.alignment.value)
            .clipped()
            .animation(isReady ? config.animation : nil, value: isInside)
            .animation(isReady ? config.animation : nil, value: isActive)
    }

    @MainActor
    private func settleInitialScroll(proxy: ScrollViewProxy) async {
        isProgrammaticScroll = true
        let target = Self.clamped(selection, count: count)

        // Plusieurs passes : le layout horizontal n’est pas fiable au 1er frame.
        for delayMs in [0, 16, 48, 120] as [UInt64] {
            if delayMs > 0 {
                try? await Task.sleep(for: .milliseconds(delayMs))
            }
            snap(to: target, proxy: proxy, animated: false)
            await Task.yield()
        }

        centeredIndex = target
        animationRange = target...target
        isReady = true
        isProgrammaticScroll = false
    }

    @MainActor
    private func snap(to index: Int, proxy: ScrollViewProxy, animated: Bool) {
        let safe = Self.clamped(index, count: count)
        isProgrammaticScroll = true
        centeredIndex = safe
        animationRange = safe...safe

        if animated {
            withAnimation(config.animation) {
                proxy.scrollTo(safe, anchor: .center)
            }
        } else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                proxy.scrollTo(safe, anchor: .center)
            }
        }

        if selection != safe {
            selection = safe
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(animated ? 280 : 30))
            isProgrammaticScroll = false
        }
    }

    private var tickSlotWidth: CGFloat {
        config.tickWidth + (config.tickHPadding * 2)
    }

    private static func clamped(_ value: Int, count: Int) -> Int {
        max(0, min(value, count))
    }
}
