import SwiftUI
import UIKit

extension View {
    /// Scroll sous le menu sticky (MainAppView) — blur + hide/show via overlay.
    func processMainScrollableChrome<ScrollContent: View>(
        selectedSection: Binding<ProcessMainSection>,
        pageSection: ProcessMainSection,
        dismissesKeyboard: ScrollDismissesKeyboardMode? = nil,
        scrollDisabled: Bool = false,
        @ViewBuilder content: @escaping () -> ScrollContent
    ) -> some View {
        Group {
            if let dismissesKeyboard {
                ScrollView {
                    content()
                }
                .scrollDisabled(scrollDisabled)
                .scrollDismissesKeyboard(dismissesKeyboard)
            } else {
                ScrollView {
                    content()
                }
                .scrollDisabled(scrollDisabled)
            }
        }
        .scrollIndicators(.hidden)
        .processMainVerticalScrollHook()
        .scrollableHeader(
            dismissDistance: ProcessMainChromeMetrics.dismissDistance,
            topBlur: false,
            pageSection: pageSection,
            usesExternalStickyChrome: true
        ) {
            EmptyView()
        }
    }

    /// Profil : hero edge-to-edge derrière le menu sticky + status bar.
    func processProfileScrollableChrome<ScrollContent: View>(
        selectedSection: Binding<ProcessMainSection>,
        @ViewBuilder content: @escaping () -> ScrollContent
    ) -> some View {
        processMainScrollableChrome(
            selectedSection: selectedSection,
            pageSection: .profile
        ) {
            content()
        }
        .scrollContentBackground(.hidden)
        .scrollClipDisabled()
        .contentMargins(.horizontal, 0, for: .scrollContent)
    }

    @ViewBuilder
    func scrollableHeader<Header: View>(
        dismissDistance: CGFloat,
        topBlur: Bool = false,
        isPinned: Bool = false,
        extendsIntoTopSafeArea: Bool = false,
        pageSection: ProcessMainSection? = nil,
        usesExternalStickyChrome: Bool = false,
        @ViewBuilder header: @escaping () -> Header
    ) -> some View {
        modifier(
            ScrollableHeaderModifier(
                dismissDistance: dismissDistance,
                topBlur: topBlur,
                isPinned: isPinned,
                extendsIntoTopSafeArea: extendsIntoTopSafeArea,
                pageSection: pageSection,
                usesExternalStickyChrome: usesExternalStickyChrome,
                header: header
            )
        )
    }
}

private struct ScrollHeaderHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct ScrollHeaderMetrics: Equatable {
    var offset: CGFloat
    var isNearBottom: Bool
}

private struct ScrollHeaderPreferenceReporter: View {
    let section: ProcessMainSection
    let headerProgress: CGFloat
    let headerVisibility: CGFloat

    var body: some View {
        Color.clear
            .preference(
                key: ProcessMainScrollHeaderPreferenceKey.self,
                value: ProcessMainScrollHeaderPreference(
                    section: section,
                    headerProgress: headerProgress,
                    headerVisibility: headerVisibility
                )
            )
    }
}

private struct ScrollableHeaderModifier<Header: View>: ViewModifier {
    let dismissDistance: CGFloat
    var topBlur: Bool
    var isPinned: Bool
    var extendsIntoTopSafeArea: Bool
    var pageSection: ProcessMainSection?
    var usesExternalStickyChrome: Bool
    @ViewBuilder var header: () -> Header

    @State private var scrollOffset: CGFloat = 0
    @State private var scrollMetrics = ScrollHeaderMetrics(offset: 0, isNearBottom: true)
    @State private var scrollPhase: ScrollPhase = .idle
    @State private var scrollDirection: ScrollDirection?
    @State private var shiftScrollOffset: CGFloat = 0
    @State private var headerProgress: CGFloat = 0
    @State private var measuredHeaderHeight: CGFloat = 112
    @State private var reportedProgress: CGFloat = 0
    @State private var reportedVisibility: CGFloat = 1

    private var bottomRevealThreshold: CGFloat { dismissDistance * 0.85 }
    private var headerVisibility: CGFloat { isPinned ? 1 : (1 - headerProgress) }
    private var topSafeInset: CGFloat { UIApplication.safeAreaTop }

    private var blurHeight: CGFloat {
        measuredHeaderHeight + 56
    }

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: ScrollHeaderMetrics.self) { geometry in
                let maxHeight = max(geometry.contentSize.height - geometry.containerSize.height, 0)
                let offset = geometry.contentOffset.y + geometry.contentInsets.top
                let clampedOffset = min(max(offset, 0), maxHeight)
                let distanceFromBottom = maxHeight - clampedOffset
                let isNearBottom = maxHeight <= 4 || distanceFromBottom <= bottomRevealThreshold
                return ScrollHeaderMetrics(offset: clampedOffset, isNearBottom: isNearBottom)
            } action: { oldValue, newValue in
                scrollMetrics = newValue
                scrollOffset = newValue.offset
                guard !isPinned else { return }

                if newValue.isNearBottom {
                    revealHeader(animated: headerProgress != 0)
                    return
                }

                scrollDirection = (scrollPhase == .interacting)
                    ? (newValue.offset > oldValue.offset ? .up : .down)
                    : nil

                if scrollDirection != nil {
                    let offset = newValue.offset.rounded() - shiftScrollOffset
                    let progress = max(min(offset / dismissDistance, 1), 0)
                    let quantized = (progress * 20).rounded() / 20
                    if abs(quantized - headerProgress) > 0.001 {
                        headerProgress = quantized
                    }
                }
            }
            .onScrollPhaseChange { _, newPhase in
                scrollPhase = newPhase

                if usesExternalStickyChrome {
                    ProcessMainPagingCoordinator.shared.setVerticalDragActive(newPhase == .interacting)
                }

                if isPinned {
                    headerProgress = 0
                    return
                }

                if newPhase != .interacting {
                    scrollDirection = nil
                    withAnimation(animation) {
                        if scrollMetrics.isNearBottom {
                            headerProgress = 0
                        } else if headerProgress > 0.5 && scrollOffset > dismissDistance {
                            headerProgress = 1
                        } else {
                            headerProgress = 0
                        }
                    }
                    shiftScrollOffset = max(scrollOffset - (headerProgress * dismissDistance), 0)
                }
            }
            .overlay(alignment: .top) {
                if topBlur, !usesExternalStickyChrome {
                    ProcessMainTopScrollBlur(
                        visibility: headerVisibility,
                        height: blurHeight
                    )
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if usesExternalStickyChrome {
                    Color.clear
                        .frame(height: ProcessMainChromeMetrics.scrollTopInset)
                } else {
                    headerChrome
                        .background {
                            GeometryReader { proxy in
                                Color.clear
                                    .preference(key: ScrollHeaderHeightKey.self, value: proxy.size.height)
                            }
                        }
                        .offset(y: headerOffset)
                        .opacity(headerVisibility)
                }
            }
            .background {
                if usesExternalStickyChrome, let pageSection {
                    ScrollHeaderPreferenceReporter(
                        section: pageSection,
                        headerProgress: reportedProgress,
                        headerVisibility: reportedVisibility
                    )
                    .onChange(of: headerProgress) { _, _ in syncReportedHeaderPreference() }
                    .onChange(of: headerVisibility) { _, _ in syncReportedHeaderPreference() }
                    .onAppear { syncReportedHeaderPreference(force: true) }
                }
            }
            .onPreferenceChange(ScrollHeaderHeightKey.self) { height in
                guard height > 0 else { return }
                measuredHeaderHeight = height
            }
            .onChange(of: scrollDirection) { _, newValue in
                guard !isPinned else { return }
                guard newValue != nil else { return }
                shiftScrollOffset = max(scrollOffset - (headerProgress * dismissDistance), 0)
            }
            .onChange(of: isPinned) { _, pinned in
                if pinned {
                    headerProgress = 0
                }
            }
    }

    @ViewBuilder
    private var headerChrome: some View {
        if extendsIntoTopSafeArea {
            header()
                .padding(.bottom, -topSafeInset)
        } else {
            header()
        }
    }

    private var headerOffset: CGFloat {
        let collapseOffset = headerProgress * -dismissDistance
        let bleedOffset = extendsIntoTopSafeArea ? -topSafeInset : 0
        return collapseOffset + bleedOffset
    }

    private func syncReportedHeaderPreference(force: Bool = false) {
        let progressChanged = abs(headerProgress - reportedProgress) > 0.04
        let visibilityChanged = abs(headerVisibility - reportedVisibility) > 0.04
        guard force || progressChanged || visibilityChanged else { return }
        reportedProgress = headerProgress
        reportedVisibility = headerVisibility
    }

    private func revealHeader(animated: Bool) {
        let apply = {
            headerProgress = 0
            shiftScrollOffset = scrollOffset
        }
        if animated {
            withAnimation(animation) { apply() }
        } else {
            apply()
        }
    }

    private enum ScrollDirection {
        case up
        case down
    }

    private var animation: Animation {
        .interpolatingSpring(duration: 0.3, bounce: 0, initialVelocity: 0)
    }
}
