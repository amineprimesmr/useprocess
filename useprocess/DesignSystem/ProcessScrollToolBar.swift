import SwiftUI

extension View {
    /// Toolbar native iOS — titre / sous-titre compacts au scroll (ScrollToolBarEffect).
    @ViewBuilder
    func processScrollToolBar<Leading: View, Trailing: View, PrimaryAction: View>(
        isPrimaryActionVisible: Bool = false,
        navBackButtonHidden: Bool = true,
        title: String?,
        subtitle: String? = nil,
        @ViewBuilder leading: @escaping () -> Leading = { EmptyView() },
        @ViewBuilder trailing: @escaping () -> Trailing,
        @ViewBuilder primaryAction: @escaping () -> PrimaryAction = { EmptyView() }
    ) -> some View {
        modifier(
            ProcessScrollToolBarModifier(
                isPrimaryActionVisible: isPrimaryActionVisible,
                navBackButtonHidden: navBackButtonHidden,
                title: title,
                subtitle: subtitle,
                leading: leading,
                trailing: trailing,
                primaryAction: primaryAction
            )
        )
    }
}

private enum ProcessScrollToolBarMetrics {
    static let toolbarTitleSpacer = String(repeating: " ", count: 50)
}

private struct ProcessScrollToolBarModifier<Leading: View, Trailing: View, PrimaryAction: View>: ViewModifier {
    var isPrimaryActionVisible: Bool
    var navBackButtonHidden: Bool
    var title: String?
    var subtitle: String?
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing
    @ViewBuilder var primaryAction: PrimaryAction

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    leading
                }

                ToolbarItem(placement: .title) {
                    Text(ProcessScrollToolBarMetrics.toolbarTitleSpacer)
                        .overlay(alignment: .leading) {
                            VStack(alignment: .leading, spacing: subtitle == nil ? 0 : 2) {
                                if let title {
                                    Text(title)
                                        .font(.callout)
                                        .fontWeight(.semibold)
                                        .modifier(ProcessScrollToolBarTitleTransition())
                                }

                                ZStack {
                                    if let subtitle {
                                        Text(subtitle)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .contentTransition(.numericText())
                                    }
                                }
                                .opacity(subtitle == nil ? 0 : 1)
                            }
                            .compositingGroup()
                            .geometryGroup()
                        }
                        .lineLimit(1)
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
            .navigationBarBackButtonHidden(navBackButtonHidden)
            .animation(.bouncy(duration: 0.3, extraBounce: 0), value: isPrimaryActionVisible)
    }
}

extension View {
    func processScrollSoftTopEdgeEffect() -> some View {
        modifier(ProcessScrollSoftTopEdgeEffectModifier())
    }
}

private struct ProcessScrollSoftTopEdgeEffectModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            content
        }
    }
}

private struct ProcessScrollToolBarTitleTransition: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.transition(.offset(y: 10).combined(with: .blurReplace))
        } else {
            content.transition(.offset(y: 10).combined(with: .opacity))
        }
    }
}
