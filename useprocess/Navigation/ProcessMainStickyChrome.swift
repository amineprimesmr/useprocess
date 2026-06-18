import SwiftUI
import UIKit

enum ProcessMainChromeMetrics {
    static var filterBarHeight: CGFloat { LayoutConstants.isIPad ? 72 : 58 }
    static let dismissDistance: CGFloat = 100

    static var topSafeInset: CGFloat { UIApplication.safeAreaTop }

    /// Espace réservé sous le menu sticky pour le contenu scrollable.
    static var scrollTopInset: CGFloat { topSafeInset + filterBarHeight + 4 }

    static var blurHeight: CGFloat { topSafeInset + filterBarHeight + 10 }
}

struct CoachSidebarOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Progression du panneau latéral coach (0 = fermé, 1 = ouvert).
struct CoachSidebarProgressKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct ProfileSubrouteActiveKey: PreferenceKey {
    static var defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

extension View {
    /// Masque le menu sticky principal (ex. écran « Modifier le profil »).
    func reportsProfileSubrouteActive(_ isActive: Bool) -> some View {
        preference(key: ProfileSubrouteActiveKey.self, value: isActive)
    }
}

struct ProcessMainScrollHeaderPreference: Equatable {
    var section: ProcessMainSection
    var headerProgress: CGFloat
    var headerVisibility: CGFloat
}

struct ProcessMainScrollHeaderPreferenceKey: PreferenceKey {
    static var defaultValue: ProcessMainScrollHeaderPreference?

    static func reduce(value: inout ProcessMainScrollHeaderPreference?, nextValue: () -> ProcessMainScrollHeaderPreference?) {
        if let next = nextValue() {
            value = next
        }
    }
}

/// Menu + blur sticky au-dessus des pages principales (une seule instance).
struct ProcessMainStickyChromeOverlay: View {
    @Binding var selection: ProcessMainSection
    var lockedSections: Set<ProcessMainSection> = []
    let headerProgress: CGFloat
    let headerVisibility: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                ProcessMainTopScrollBlur(
                    visibility: headerVisibility,
                    height: ProcessMainChromeMetrics.blurHeight
                )
                .allowsHitTesting(false)

                ProcessMainFilterBar(selection: $selection, lockedSections: lockedSections)
                    .padding(.top, ProcessMainChromeMetrics.topSafeInset)
                    .offset(y: headerProgress * -ProcessMainChromeMetrics.dismissDistance)
                    .opacity(Double(headerVisibility))
            }
            .frame(height: ProcessMainChromeMetrics.scrollTopInset, alignment: .top)

            Spacer(minLength: 0)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(edges: .top)
    }
}

/// Couche sticky isolée — seule cette vue observe la progression sidebar.
struct CoachMainStickyChromeLayer: View {
    @Binding var selection: ProcessMainSection
    var lockedSections: Set<ProcessMainSection> = []
    var profileSubrouteActive: Bool
    let headerProgress: CGFloat
    let headerVisibility: CGFloat

    @Bindable private var sidebar = CoachSidebarPresentation.shared

    private var opacity: Double {
        if selection == .profile && profileSubrouteActive { return 0 }
        if selection == .coach { return Double(1 - sidebar.progress) }
        return 1
    }

    var body: some View {
        ProcessMainStickyChromeOverlay(
            selection: $selection,
            lockedSections: lockedSections,
            headerProgress: headerProgress,
            headerVisibility: headerVisibility
        )
        .opacity(opacity)
        .allowsHitTesting(opacity > 0.05)
        .animation(.none, value: sidebar.progress)
    }
}

struct ProcessMainTopScrollBlur: View {
    let visibility: CGFloat
    let height: CGFloat

    var body: some View {
        VariableBlurView(
            maxBlurRadius: 10,
            direction: .blurredTopClearBottom,
            startOffset: -0.06
        )
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .opacity(Double(visibility))
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
    }
}

extension View {
    func reportsProcessMainScrollHeader(
        section: ProcessMainSection,
        headerProgress: CGFloat,
        headerVisibility: CGFloat
    ) -> some View {
        preference(
            key: ProcessMainScrollHeaderPreferenceKey.self,
            value: ProcessMainScrollHeaderPreference(
                section: section,
                headerProgress: headerProgress,
                headerVisibility: headerVisibility
            )
        )
    }
}
