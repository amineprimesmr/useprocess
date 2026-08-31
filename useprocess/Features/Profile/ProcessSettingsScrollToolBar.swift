import SwiftUI

// MARK: - Scroll-collapsing toolbar (Réglages)

extension View {
    @ViewBuilder
    func processSettingsScrollToolBar<Trailing: View, PrimaryAction: View>(
        isPrimaryActionVisible: Bool = false,
        title: String?,
        subtitle: String? = nil,
        titleAlignment: HorizontalAlignment = .leading,
        titleColor: Color = .white,
        appliesDarkToolbarColorScheme: Bool = true,
        showsBackButton: Bool = true,
        onBack: @escaping () -> Void,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() },
        @ViewBuilder primaryAction: @escaping () -> PrimaryAction = { EmptyView() }
    ) -> some View {
        modifier(
            ProcessSettingsScrollToolBarModifier(
                isPrimaryActionVisible: isPrimaryActionVisible,
                title: title,
                subtitle: subtitle,
                titleAlignment: titleAlignment,
                titleColor: titleColor,
                appliesDarkToolbarColorScheme: appliesDarkToolbarColorScheme,
                showsBackButton: showsBackButton,
                onBack: onBack,
                trailing: trailing,
                primaryAction: primaryAction
            )
        )
    }

    /// Sous-page Réglages — titre fixe centré, fond transparent.
    func processSettingsStandardToolbar(
        title: String,
        onBack: @escaping () -> Void
    ) -> some View {
        processSettingsScrollToolBar(
            title: title,
            subtitle: nil,
            titleAlignment: .center,
            onBack: onBack
        )
    }

    /// Sous-page poussée depuis Réglages — toolbar standard + retour via `dismiss`.
    func processSettingsSubpageToolbar(title: String) -> some View {
        modifier(ProcessSettingsSubpageToolbarModifier(title: title))
    }

    /// Onglet principal (Profil, Série, Routine…) — toolbar transparente sans retour.
    func processMainTabScrollToolBar<Trailing: View>(
        title: String?,
        titleColor: Color,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) -> some View {
        processSettingsScrollToolBar(
            title: title,
            titleColor: titleColor,
            appliesDarkToolbarColorScheme: false,
            showsBackButton: false,
            onBack: {},
            trailing: trailing
        )
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

private struct ProcessSettingsSubpageToolbarModifier: ViewModifier {
    let title: String
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
            .processSettingsStandardToolbar(title: title, onBack: { dismiss() })
    }
}

/// Scroll interne Réglages (ex. légal → scores) avec la même top bar.
struct ProcessSettingsNestedScrollPage<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            content()
                .padding(.bottom, ProcessIGTabMetrics.tabBarOverlayClearance + 16)
        }
        .scrollIndicators(.hidden)
        .processAdoptForIGTabBar()
        .processSettingsStandardToolbar(title: title, onBack: { dismiss() })
        .processSettingsOpalPage()
    }
}

private struct ProcessSettingsScrollToolBarModifier<Trailing: View, PrimaryAction: View>: ViewModifier {
    var isPrimaryActionVisible: Bool
    var title: String?
    var subtitle: String?
    var titleAlignment: HorizontalAlignment
    var titleColor: Color
    var appliesDarkToolbarColorScheme: Bool
    var showsBackButton: Bool
    var onBack: () -> Void
    @ViewBuilder var trailing: Trailing
    @ViewBuilder var primaryAction: PrimaryAction

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if showsBackButton {
                        ProcessSettingsToolbarBackButton(action: onBack)
                    }
                }

                ToolbarItem(placement: .principal) {
                    VStack(alignment: titleAlignment, spacing: subtitle == nil ? 0 : 2) {
                        if let title {
                            Text(title)
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(titleColor)
                                .lineLimit(1)
                                .transition(.offset(y: 10).combined(with: .blurReplace))
                        }

                        if let subtitle {
                            Text(subtitle)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(ProcessSettingsOpalTheme.valueTint)
                                .contentTransition(.numericText())
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: Alignment(horizontal: titleAlignment, vertical: .center))
                    .animation(.easeInOut(duration: 0.3), value: title)
                    .animation(.easeInOut(duration: 0.3), value: subtitle)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    trailing
                }

                if isPrimaryActionVisible {
                    ToolbarItem(placement: .topBarTrailing) {
                        primaryAction
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbarBackground(.hidden, for: .navigationBar)
            .modifier(ProcessSettingsToolbarColorSchemeModifier(enabled: appliesDarkToolbarColorScheme))
            .animation(.bouncy(duration: 0.3, extraBounce: 0), value: isPrimaryActionVisible)
    }
}

private struct ProcessSettingsToolbarColorSchemeModifier: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.toolbarColorScheme(.dark, for: .navigationBar)
        } else {
            content
        }
    }
}

struct ProcessSettingsToolbarBackButton: View {
    let action: () -> Void
    var foregroundColor: Color = .white

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: ProcessAppHeaderControlMetrics.iconSize, weight: .semibold))
                .foregroundStyle(foregroundColor)
                .offset(x: 0.5)
                .frame(
                    width: ProcessAppHeaderControlMetrics.size,
                    height: ProcessAppHeaderControlMetrics.size
                )
        }
        .processGlassIconButtonStyle()
        .accessibilityLabel(AppCopy.t("Retour", en: "Back"))
    }
}


// MARK: - Scroll section subtitle tracking

struct ProcessSettingsScrollSectionReporter: View {
    let title: String
    let index: Int
    let effectsActive: Bool
    @Binding var activeIndex: Int?

    var body: some View {
        ProcessSettingsOpalSectionTitle(title: title)
            .animation(.smooth(duration: 0.35, extraBounce: 0)) { content in
                content.opacity(activeIndex == index ? 0 : 1)
            }
            .onGeometryChange(for: Bool.self) {
                guard effectsActive else { return false }
                let offset = $0.frame(in: .scrollView).minY
                return -offset > 25
            } action: { crossed in
                let previous = index - 1
                activeIndex = crossed ? index : (previous < 0 ? nil : previous)
            }
    }
}

/// Grand titre in-scroll — se replie dans la toolbar au scroll (hub Paramètres, Profil…).
