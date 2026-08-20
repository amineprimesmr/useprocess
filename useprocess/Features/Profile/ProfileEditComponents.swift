import SwiftUI
import UIKit
import UIKit

enum AccountConfirmation: Identifiable {
    case logout
    case deleteAccount

    var id: Self { self }

    @MainActor
    var title: String {
        switch self {
        case .logout: return AppCopy.t("Se déconnecter ?", en: "Log Out?")
        case .deleteAccount: return AppCopy.t("Supprimer le compte ?", en: "Delete Account?")
        }
    }

    @MainActor
    var message: String {
        switch self {
        case .logout:
            return AppCopy.t("Tu pourras te reconnecter à tout moment.", en: "You can log back in at any time.")
        case .deleteAccount:
            return AppCopy.t(
                "Cette action est définitive. Toutes tes données seront effacées, la liaison Se connecter avec Apple sera révoquée, et tu reviendras au début de Process. Ton abonnement App Store, s'il est actif, n'est pas annulé automatiquement.",
                en: "This action is permanent. All your data will be erased, your Sign in with Apple link will be revoked, and you'll return to the beginning of Process. Your App Store subscription, if active, is not cancelled automatically."
            )
        }
    }

    @MainActor
    var confirmTitle: String {
        switch self {
        case .logout: return AppCopy.t("Se déconnecter", en: "Log Out")
        case .deleteAccount: return AppCopy.t("Supprimer le compte", en: "Delete Account")
        }
    }
}

enum ProfileEditTheme {
    static let background = ProcessColors.background
    static let chipBackground = ProcessColors.secondaryBackground
    static let chipSelected = Color(.tertiarySystemBackground)
    static let headerButton = ProcessColors.secondaryBackground
    static let savePill = Color.primary.opacity(0.1)
    static let textSecondary = ProcessColors.textSecondary
    static let placeholder = Color(.placeholderText)
    static let separator = ProcessColors.border

    static let spring = Animation.spring(response: 0.34, dampingFraction: 0.86)
}

struct ProfileEditorHeader: View {
    let title: String
    var showsSave: Bool = false
    var saveDisabled: Bool = false
    let onDismiss: () -> Void
    var onSave: (() -> Void)?

    var body: some View {
        ZStack {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.primary)

            HStack {
                ProcessGlassIconButton(systemName: "chevron.left", size: 40, iconSize: 16, action: onDismiss)

                Spacer()

                if showsSave, let onSave {
                    Button(action: onSave) {
                        Text(AppCopy.save)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(saveDisabled ? Color(.tertiaryLabel) : Color.primary)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                    }
                    .processGlassButton(in: Capsule())
                    .disabled(saveDisabled)
                    .opacity(saveDisabled ? 0.72 : 1)
                } else {
                    Color.clear.frame(width: 40, height: 40)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 12)
    }
}

struct ProfileEditorHero: View {
    let headline: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 14) {
            Text(headline)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.primary)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.system(size: 15))
                .foregroundStyle(ProfileEditTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 28)
    }
}

struct ProfileEditorBottomSaveButton: View {
    let title: String
    var disabled: Bool = false
    let action: () -> Void

    private let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(disabled ? Color(.tertiaryLabel) : Color.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
        }
        .processGlassButton(in: shape)
        .disabled(disabled)
        .opacity(disabled ? 0.72 : 1)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(ProfileEditTheme.background)
    }
}

struct ProfileInterestChip: View {
    let interest: ProfileInterest
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(interest.label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isSelected ? ProfileEditTheme.chipSelected : ProfileEditTheme.chipBackground)
                .clipShape(Capsule())
                .contentShape(Capsule())
                .overlay {
                    if isSelected {
                        Capsule()
                            .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.processPlain)
        .animation(ProfileEditTheme.spring, value: isSelected)
    }
}

struct ProfileInterestFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

struct ProfileEditListRow: View {
    let label: String
    let value: String?
    let placeholder: String
    var showsAccentDot: Bool = false
    var showsChevron: Bool = true
    var valueIsMuted: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                if showsAccentDot {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 7, height: 7)
                }
                Text(label)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.primary)
            }

            Spacer(minLength: 8)

            Text(value?.isEmpty == false ? value! : placeholder)
                .font(.system(size: 16))
                .foregroundStyle(valueForeground)
                .lineLimit(2)
                .multilineTextAlignment(.trailing)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ProfileEditTheme.textSecondary.opacity(0.55))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
    }

    private var valueForeground: Color {
        guard value?.isEmpty == false else { return ProfileEditTheme.placeholder }
        if valueIsMuted { return ProfileEditTheme.textSecondary.opacity(0.85) }
        return Color.primary
    }
}

// MARK: - Account details (Détails du compte)

enum AccountDetailsTheme {
    static let pageBackground = ProfileTheme.background
    static let linkText = ProfileTheme.textSecondary
    static let rowCornerRadius: CGFloat = 16
    static let actionCornerRadius: CGFloat = 14
    static let rowSpacing: CGFloat = 10
    static let horizontalPadding: CGFloat = 16
}

struct AccountDetailsGlassReliefModifier: ViewModifier {
    var cornerRadius: CGFloat = AccountDetailsTheme.rowCornerRadius
    var destructiveTint: Bool = false

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .processGlassEffect(in: shape, interactive: false)
            .overlay {
                if destructiveTint {
                    shape.fill(Color.red.opacity(0.07))
                }
            }
    }
}

extension View {
    func accountDetailsGlassRelief(
        cornerRadius: CGFloat = AccountDetailsTheme.rowCornerRadius,
        destructiveTint: Bool = false
    ) -> some View {
        modifier(AccountDetailsGlassReliefModifier(cornerRadius: cornerRadius, destructiveTint: destructiveTint))
    }
}

struct AccountDetailsGlassHeader: View {
    var title: String? = nil
    let onBack: () -> Void
    var onSave: (() -> Void)? = nil
    var saveDisabled: Bool = true
    var showsSave: Bool = true

    var body: some View {
        ZStack {
            if let title {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.primary)
            }

            HStack {
                if showsSave {
                    Color.clear.frame(width: 40, height: 40)
                    Spacer()
                    if let onSave {
                        Button(action: onSave) {
                            Text(AppCopy.save)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(saveDisabled ? Color(.tertiaryLabel) : Color.primary)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                        }
                        .processGlassButton(in: Capsule())
                        .disabled(saveDisabled)
                        .opacity(saveDisabled ? 0.72 : 1)
                    }
                } else {
                    Color.clear.frame(width: 40, height: 40)
                    Spacer()
                    ProcessGlassIconButton(systemName: "xmark", size: 40, iconSize: 13, action: onBack)
                        .accessibilityLabel(AppCopy.close)
                }
            }
        }
        .padding(.horizontal, AccountDetailsTheme.horizontalPadding)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
}

struct AccountDetailsCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: AccountDetailsTheme.rowSpacing) {
            content
        }
    }
}

struct AccountDetailsGlassRow<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .accountDetailsGlassRelief()
    }
}

struct AccountDetailsDivider: View {
    var body: some View {
        EmptyView()
    }
}

struct AccountDetailsActionButton: View {
    let title: String
    var destructive: Bool = false
    let action: () -> Void

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: AccountDetailsTheme.actionCornerRadius, style: .continuous)
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(destructive ? Color.red : Color.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .contentShape(shape)
        }
        .processGlassButton(in: shape)
        .overlay {
            if destructive {
                shape.fill(Color.red.opacity(0.07))
            }
        }
    }
}

private struct ProfileAccountDeletionHandlerKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    var profileAccountDeletionHandler: (() -> Void)? {
        get { self[ProfileAccountDeletionHandlerKey.self] }
        set { self[ProfileAccountDeletionHandlerKey.self] = newValue }
    }
}

struct AccountDeleteAnimatedButton: View {
    let onConfirm: () -> Void

    @State private var showsConfirmation = false
    @State private var sliderResetToggle = false

    var body: some View {
        ProcessSettingsOpalDestructiveButton(
            title: AppCopy.t("Supprimer mon compte", en: "Delete My Account"),
            icon: "trash"
        ) {
            HapticManager.shared.impact(.light)
            showsConfirmation = true
        }
        .sheet(isPresented: $showsConfirmation) {
            AccountDeleteConfirmationSheet(
                onConfirm: {
                    showsConfirmation = false
                    onConfirm()
                },
                sliderResetToggle: $sliderResetToggle
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }
}

private struct AccountDeleteConfirmationSheet: View {
    let onConfirm: () -> Void
    @Binding var sliderResetToggle: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.red)

            Text(AppCopy.t("Supprimer le compte ?", en: "Delete Account?"))
                .font(.title2.bold())
                .foregroundStyle(theme.primaryText)

            Text(AppCopy.t(
                "Cette action est définitive. Toutes tes données seront effacées, la liaison Se connecter avec Apple sera révoquée, et tu reviendras au début de Process. Ton abonnement App Store, s'il est actif, n'est pas annulé automatiquement — gère-le dans Réglages iPhone → Abonnements.",
                en: "This action is permanent. All your data will be erased, your Sign in with Apple link will be revoked, and you'll return to the beginning of Process. Your App Store subscription, if active, is not cancelled automatically — manage it in iPhone Settings → Subscriptions."
            ))
            .font(.subheadline)
            .foregroundStyle(theme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)

            ProcessLiquidGlassConfirmSlider(
                text: AppCopy.t("Glisser pour supprimer", en: "Slide to delete"),
                symbol: "trash.fill",
                config: .init(
                    tint: .red,
                    height: 64,
                    textFont: .subheadline.weight(.semibold),
                    symbolFont: .title3.weight(.semibold),
                    isSymbolPulsing: true,
                    resetToggle: sliderResetToggle
                ),
                onProgressChange: { _ in },
                onFinish: { isCompleted in
                    guard isCompleted else {
                        sliderResetToggle.toggle()
                        return
                    }
                    HapticManager.shared.notification(.warning)
                    dismiss()
                    onConfirm()
                }
            )
            .padding(.top, 4)

            Button {
                sliderResetToggle.toggle()
                dismiss()
            } label: {
                Text(AppCopy.cancel)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.primaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }
            .buttonStyle(.processPlain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onDisappear {
            sliderResetToggle.toggle()
        }
    }
}

struct ProfileSummarySectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(ProfileEditTheme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 22)
            .padding(.bottom, 6)
    }
}

struct ProfileSummaryInfoRow: View {
    let item: ProfileSummaryItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(item.label)
                .font(.system(size: 16))
                .foregroundStyle(Color.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(item.displayValue)
                .font(.system(size: 16))
                .foregroundStyle(item.isPlaceholder ? ProfileEditTheme.placeholder : ProfileEditTheme.textSecondary)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
}

// MARK: - Opal-style Settings (Process)

enum ProcessSettingsOpalTheme {
    static let cardCornerRadius: CGFloat = 28
    static let fieldCornerRadius: CGFloat = 14
    static let horizontalPadding: CGFloat = 16
    static let sectionHeaderTop: CGFloat = 18
    static let sectionHeaderBottom: CGFloat = 10
    static let rowVerticalPadding: CGFloat = 9
    static let rowMinHeight: CGFloat = 46
    static let accountRowMinHeight: CGFloat = 50
    static let iconColumnWidth: CGFloat = 26
    static let dividerLeadingInset: CGFloat = horizontalPadding + iconColumnWidth + 12
    static let cardSpacing: CGFloat = 12
    static let headerVerticalPadding: CGFloat = 8
    static let headerControlSize: CGFloat = 40
    static let spring = Animation.spring(response: 0.28, dampingFraction: 0.9, blendDuration: 0.06)

    /// Cartes légèrement relevées — fond un peu moins noir, bordure discrète.
    static let cardFillDark = Color.white.opacity(0.062)
    static let cardBorderDark = Color.white.opacity(0.096)
    static let fieldFillDark = Color.white.opacity(0.05)
    static let fieldStrokeDark = Color.white.opacity(0.09)
    static let iconTint = Color.white.opacity(0.82)
    static let valueTint = Color.white.opacity(0.48)
    static let chevronTint = Color.white.opacity(0.32)
    static let sectionTitleTint = Color.white.opacity(0.92)

    static var scrollTopInset: CGFloat {
        headerControlSize + (headerVerticalPadding * 2) + 4
    }

    static func pageBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .black : Color(UIColor.systemGroupedBackground)
    }

    static func cardFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? cardFillDark : Color(UIColor.secondarySystemGroupedBackground)
    }

    static func separatorOpacity(_ scheme: ColorScheme) -> Double {
        scheme == .dark ? 0.10 : 0.28
    }

    static var glowGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.42, green: 0.94, blue: 0.52),
                Color(red: 0.98, green: 0.90, blue: 0.32),
                Color(red: 0.98, green: 0.55, blue: 0.72),
                Color(red: 0.48, green: 0.82, blue: 0.98)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Settings change feedback (langue, apparence, enregistrer…)

@MainActor
enum ProcessSettingsChangeFeedback {
    private static let highlightClearMs: UInt64 = 280
    private static let saveLeadMs: UInt64 = 100

    static func play() {
        HapticManager.shared.notification(.success)
        ProcessSoundPlayer.playSettingsChange()
    }

    static func playSelection() {
        HapticManager.shared.selection()
        ProcessSoundPlayer.playSettingsChange()
    }

    /// Sélection immédiate d’une row (langue, apparence…).
    static func performRowSelection<T: Equatable>(
        highlight: Binding<T?>,
        value: T,
        isSameValue: Bool,
        apply: () -> Void
    ) {
        guard !isSameValue else { return }

        play()

        withAnimation(ProcessSettingsOpalTheme.spring) {
            highlight.wrappedValue = value
            apply()
        }

        Task {
            try? await Task.sleep(for: .milliseconds(highlightClearMs))
            await MainActor.run {
                withAnimation(ProcessSettingsOpalTheme.spring) {
                    if highlight.wrappedValue == value {
                        highlight.wrappedValue = nil
                    }
                }
            }
        }
    }

    static func performSave(_ action: @escaping () async -> Void) async {
        play()
        try? await Task.sleep(for: .milliseconds(saveLeadMs))
        await action()
    }

    static func performSaveSync(_ action: @escaping () -> Void) {
        play()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            action()
        }
    }
}

extension View {
    func processSettingsSelectionHighlight(isHighlighted: Bool, isActive: Bool = false) -> some View {
        scaleEffect(isHighlighted ? 1.018 : 1)
            .opacity(isHighlighted ? 1 : (isActive ? 1 : 0.94))
            .animation(ProcessSettingsOpalTheme.spring, value: isHighlighted)
    }
}

struct ProcessSettingsSaveToolbarButton: View {
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(AppCopy.save) {
            guard !disabled else { return }
            action()
        }
        .font(.callout.weight(.semibold))
        .buttonStyle(.borderless)
        .disabled(disabled)
    }
}

struct ProcessSettingsOpalPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.68 : 1)
            .scaleEffect(configuration.isPressed ? 0.988 : 1, anchor: .center)
            .animation(ProcessSettingsOpalTheme.spring, value: configuration.isPressed)
    }
}

extension View {
    func processSettingsOpalRowButton() -> some View {
        buttonStyle(ProcessSettingsOpalPressStyle())
    }
}

struct ProcessSettingsOpalPageBackground: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ProcessSettingsOpalTheme.pageBackground(colorScheme).ignoresSafeArea())
            .preferredColorScheme(.dark)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

extension View {
    func processSettingsOpalPage() -> some View {
        modifier(ProcessSettingsOpalPageBackground())
    }
}

struct ProcessSettingsOpalHeader: View {
    let title: String
    let onBack: () -> Void
    var trailing: AnyView?

    init(title: String, onBack: @escaping () -> Void, @ViewBuilder trailing: () -> some View = { EmptyView() }) {
        self.title = title
        self.onBack = onBack
        self.trailing = AnyView(trailing())
    }

    var body: some View {
        ZStack {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)

            HStack {
                ProcessSettingsOpalBackButton(action: onBack)

                Spacer()

                if let trailing {
                    trailing
                } else {
                    Color.clear.frame(width: ProcessSettingsOpalTheme.headerControlSize, height: ProcessSettingsOpalTheme.headerControlSize)
                }
            }
        }
        .padding(.horizontal, ProcessSettingsOpalTheme.horizontalPadding)
        .padding(.vertical, ProcessSettingsOpalTheme.headerVerticalPadding)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay {
                    Rectangle()
                        .fill(Color.black.opacity(0.55))
                }
                .ignoresSafeArea(edges: .top)
        }
    }
}

/// Sous-page Réglages — header glass flottant, scroll derrière, tab bar visible.
struct ProcessSettingsOpalScrollPage<Content: View>: View {
    let title: String
    var onBack: (() -> Void)?
    @ViewBuilder let content: () -> Content

    @Environment(\.dismiss) private var dismiss

    init(title: String, onBack: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.onBack = onBack
        self.content = content
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                content()
            }
            .padding(.bottom, ProcessIGTabMetrics.tabBarOverlayClearance + 16)
        }
        .scrollIndicators(.hidden)
        .processAdoptForIGTabBar()
        .processSettingsStandardToolbar(title: title) {
            if let onBack {
                onBack()
            } else {
                dismiss()
            }
        }
        .processSettingsOpalPage()
    }
}

struct ProcessSettingsOpalBackButton: View {
    let action: () -> Void

    var body: some View {
        ProcessGlassIconButton(
            systemName: "chevron.left",
            size: ProcessSettingsOpalTheme.headerControlSize,
            iconSize: 15,
            action: action
        )
        .accessibilityLabel(AppCopy.t("Retour", en: "Back"))
    }
}

struct ProcessSettingsOpalCloseButton: View {
    let action: () -> Void

    var body: some View {
        ProcessGlassIconButton(
            systemName: "xmark",
            size: ProcessSettingsOpalTheme.headerControlSize,
            iconSize: 13,
            action: action
        )
        .accessibilityLabel(AppCopy.close)
    }
}

struct ProcessSettingsOpalSectionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 16.5, weight: .bold))
            .foregroundStyle(ProcessSettingsOpalTheme.sectionTitleTint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, ProcessSettingsOpalTheme.horizontalPadding + 4)
            .padding(.top, ProcessSettingsOpalTheme.sectionHeaderTop)
            .padding(.bottom, ProcessSettingsOpalTheme.sectionHeaderBottom)
    }
}

struct ProcessSettingsOpalCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @ViewBuilder let content: () -> Content

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: ProcessSettingsOpalTheme.cardCornerRadius, style: .continuous)
    }

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .background {
            shape
                .fill(ProcessSettingsOpalTheme.cardFill(colorScheme))
                .overlay {
                    shape.strokeBorder(ProcessSettingsOpalTheme.cardBorderDark, lineWidth: 0.5)
                }
        }
        .clipShape(shape)
    }
}

struct ProcessSettingsOpalRowDivider: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: ProcessSettingsOpalTheme.dividerLeadingInset)
            Rectangle()
                .fill(Color.primary.opacity(ProcessSettingsOpalTheme.separatorOpacity(colorScheme)))
                .frame(height: 1 / UIScreen.main.scale)
        }
    }
}

struct ProcessSettingsOpalRow: View {
    let icon: String?
    let title: String
    var subtitle: String?
    var value: String?
    var trailingIcon: ProcessSettingsOpalTrailing = .chevron
    var showsDivider: Bool = false
    private let customLeading: AnyView?

    init(
        icon: String? = nil,
        title: String,
        subtitle: String? = nil,
        value: String? = nil,
        trailingIcon: ProcessSettingsOpalTrailing = .chevron,
        showsDivider: Bool = false
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.trailingIcon = trailingIcon
        self.showsDivider = showsDivider
        self.customLeading = nil
    }

    init(
        title: String,
        subtitle: String? = nil,
        value: String? = nil,
        trailingIcon: ProcessSettingsOpalTrailing = .chevron,
        showsDivider: Bool = false,
        @ViewBuilder leading: () -> some View
    ) {
        self.icon = nil
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.trailingIcon = trailingIcon
        self.showsDivider = showsDivider
        self.customLeading = AnyView(leading())
    }

    enum ProcessSettingsOpalTrailing {
        case chevron
        case external
        case none
        case status(String)
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsDivider { ProcessSettingsOpalRowDivider() }

            HStack(alignment: .center, spacing: 12) {
                if let customLeading {
                    customLeading
                        .frame(width: ProcessSettingsOpalTheme.iconColumnWidth, height: ProcessSettingsOpalTheme.iconColumnWidth)
                } else if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(ProcessSettingsOpalTheme.iconTint)
                        .frame(width: ProcessSettingsOpalTheme.iconColumnWidth, alignment: .center)
                }

                VStack(alignment: .leading, spacing: subtitle == nil ? 0 : 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(.white)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 15))
                            .foregroundStyle(ProcessSettingsOpalTheme.valueTint)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                trailingView
            }
            .frame(minHeight: ProcessSettingsOpalTheme.rowMinHeight, alignment: .center)
            .padding(.horizontal, ProcessSettingsOpalTheme.horizontalPadding)
            .padding(.vertical, ProcessSettingsOpalTheme.rowVerticalPadding)
            .contentShape(Rectangle())
        }
    }

    @ViewBuilder
    private var trailingView: some View {
        switch trailingIcon {
        case .chevron:
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ProcessSettingsOpalTheme.chevronTint)
        case .external:
            Image(systemName: "arrow.up.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(ProcessSettingsOpalTheme.chevronTint)
        case .none:
            if let value, !value.isEmpty {
                Text(value)
                    .font(.system(size: 17))
                    .foregroundStyle(ProcessSettingsOpalTheme.valueTint)
                    .multilineTextAlignment(.trailing)
            }
        case .status(let text):
            Text(text)
                .font(.system(size: 17))
                .foregroundStyle(ProcessSettingsOpalTheme.valueTint)
        }
    }
}

struct ProcessSettingsInlineLanguageRows: View {
    @EnvironmentObject private var profileService: UnifiedProfileService
    @Bindable private var appLanguage = ProcessAppLanguage.shared
    @State private var highlightedLanguage: ProcessAppLanguage.Code?

    var body: some View {
        ForEach(Array(ProcessAppLanguage.Code.allCases.enumerated()), id: \.element.id) { index, language in
            if index > 0 { ProcessSettingsOpalRowDivider() }

            Button {
                selectLanguage(language)
            } label: {
                ProcessSettingsOpalRow(
                    icon: "globe.americas.fill",
                    title: "\(language.flag) \(language.displayName)",
                    trailingIcon: appLanguage.code == language
                        ? .status(AppCopy.t("Actif", en: "Active"))
                        : .none,
                    showsDivider: false
                )
                .processSettingsSelectionHighlight(
                    isHighlighted: highlightedLanguage == language,
                    isActive: appLanguage.code == language
                )
            }
            .processSettingsOpalRowButton()
        }
    }

    private func selectLanguage(_ language: ProcessAppLanguage.Code) {
        ProcessSettingsChangeFeedback.performRowSelection(
            highlight: $highlightedLanguage,
            value: language,
            isSameValue: language == appLanguage.code
        ) {
            appLanguage.setLanguage(language)
        }

        Task {
            if let profile = profileService.currentProfile {
                var preferences = profile.preferences
                preferences.language = language.rawValue
                try? await profileService.updatePreferences(preferences)
            }
        }
    }
}

/// Avatar Réglages — boucle vidéo du dernier scan visage (repli initiales).
struct ProcessSettingsLatestScanAvatar: View {
    var size: CGFloat = 44
    var initials: String = "?"
    var isPlaybackActive: Bool = true

    @Bindable private var scanStore = FaceScanHistoryStore.shared

    var body: some View {
        Group {
            if let scan = scanStore.latestResult {
                FaceScanRecordingMediaView(
                    result: scan,
                    height: size,
                    displayMode: .sidePanel,
                    isPlaybackActive: isPlaybackActive
                )
            } else {
                ZStack {
                    Circle().fill(ProfileTheme.avatarAccent)
                    Text(String(initials.prefix(1)).uppercased())
                        .font(.system(size: size * 0.46, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle()
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5)
        }
        .accessibilityLabel(AppCopy.t("Dernier scan visage", en: "Latest face scan"))
    }
}

struct ProcessSettingsOpalAccountRow: View {
    let icon: String
    let title: String
    let value: String?
    var placeholder: String = "—"
    var trailingIcon: ProcessSettingsOpalRow.ProcessSettingsOpalTrailing = .chevron
    var showsDivider: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            if showsDivider { ProcessSettingsOpalRowDivider() }

            HStack(alignment: .center, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(ProcessSettingsOpalTheme.iconTint)
                    .frame(width: ProcessSettingsOpalTheme.iconColumnWidth, alignment: .center)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(.white)

                    Text(displayValue)
                        .font(.system(size: 15))
                        .foregroundStyle(
                            value?.isEmpty == false
                                ? ProcessSettingsOpalTheme.valueTint
                                : ProcessSettingsOpalTheme.valueTint.opacity(0.75)
                        )
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                switch trailingIcon {
                case .chevron:
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ProcessSettingsOpalTheme.chevronTint)
                case .external:
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ProcessSettingsOpalTheme.chevronTint)
                case .none:
                    EmptyView()
                case .status(let text):
                    Text(text)
                        .font(.system(size: 15))
                        .foregroundStyle(ProcessSettingsOpalTheme.valueTint)
                }
            }
            .frame(minHeight: ProcessSettingsOpalTheme.accountRowMinHeight, alignment: .center)
            .padding(.horizontal, ProcessSettingsOpalTheme.horizontalPadding)
            .padding(.vertical, ProcessSettingsOpalTheme.rowVerticalPadding)
            .contentShape(Rectangle())
        }
    }

    private var displayValue: String {
        guard let value, !value.isEmpty else { return placeholder }
        return value
    }
}

struct ProcessSettingsOpalToggleRow: View {
    let icon: String
    let title: String
    var subtitle: String?
    @Binding var isOn: Bool
    var showsDivider: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            if showsDivider { ProcessSettingsOpalRowDivider() }

            HStack(alignment: subtitle == nil ? .center : .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(ProcessSettingsOpalTheme.iconTint)
                    .frame(width: ProcessSettingsOpalTheme.iconColumnWidth, alignment: .center)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(.white)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(ProcessSettingsOpalTheme.valueTint)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Toggle("", isOn: $isOn)
                    .labelsHidden()
            }
            .frame(minHeight: ProcessSettingsOpalTheme.rowMinHeight, alignment: .center)
            .padding(.horizontal, ProcessSettingsOpalTheme.horizontalPadding)
            .padding(.vertical, ProcessSettingsOpalTheme.rowVerticalPadding)
            .animation(ProcessSettingsOpalTheme.spring, value: isOn)
        }
    }
}

struct ProcessSettingsOpalActionRow: View {
    let icon: String
    let title: String
    var destructive: Bool = false
    var showsDivider: Bool = false
    let action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if showsDivider { ProcessSettingsOpalRowDivider() }

            Button(action: action) {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(destructive ? Color.red : ProcessSettingsOpalTheme.iconTint)
                        .frame(width: ProcessSettingsOpalTheme.iconColumnWidth, alignment: .center)

                    Text(title)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(destructive ? Color.red : .white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: ProcessSettingsOpalTheme.rowMinHeight, alignment: .center)
                .padding(.horizontal, ProcessSettingsOpalTheme.horizontalPadding)
                .padding(.vertical, ProcessSettingsOpalTheme.rowVerticalPadding)
                .contentShape(Rectangle())
            }
            .buttonStyle(ProcessSettingsOpalPressStyle())
        }
    }
}

struct ProcessSettingsOpalDestructiveButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: ProcessSettingsOpalTheme.cardCornerRadius, style: .continuous)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(Color.red)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background {
                shape
                    .strokeBorder(Color.red.opacity(0.55), lineWidth: 1)
                    .background(shape.fill(Color.red.opacity(0.10)))
            }
            .contentShape(shape)
        }
        .buttonStyle(ProcessSettingsOpalPressStyle())
        .padding(.horizontal, ProcessSettingsOpalTheme.horizontalPadding)
    }
}

struct ProcessSettingsOpalGlowButton: View {
    let title: String
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .processGlassButton(in: Capsule(style: .continuous))
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
        .padding(.horizontal, ProcessSettingsOpalTheme.horizontalPadding)
    }
}

struct ProcessSettingsOpalField: View {
    @Binding var text: String
    var placeholder: String
    var textAlignment: TextAlignment = .leading
    var axis: Axis = .horizontal
    var isSecure: Bool = false

    private var capsule: Capsule { Capsule(style: .continuous) }

    var body: some View {
        Group {
            if isSecure {
                SecureField("", text: $text, prompt: prompt)
            } else if axis == .vertical {
                TextField("", text: $text, prompt: prompt, axis: .vertical)
                    .lineLimit(3...8)
            } else {
                TextField("", text: $text, prompt: prompt)
            }
        }
        .font(.system(size: 17, weight: .medium))
        .foregroundStyle(.white)
        .multilineTextAlignment(textAlignment)
        .padding(.horizontal, 22)
        .padding(.vertical, axis == .vertical ? 20 : 16)
        .frame(maxWidth: .infinity, alignment: alignment)
        .processGlassEffect(in: capsule, interactive: false)
        .padding(.horizontal, ProcessSettingsOpalTheme.horizontalPadding)
    }

    private var alignment: Alignment {
        switch textAlignment {
        case .center: return .center
        case .trailing: return .trailing
        default: return .leading
        }
    }

    private var prompt: Text {
        Text(placeholder)
            .foregroundStyle(ProcessSettingsOpalTheme.valueTint)
            .font(.system(size: 17, weight: .medium))
    }
}

struct ProcessSettingsOpalOTPInput: View {
    @Binding var code: String
    var length: Int = ProcessReferralCode.length
    @FocusState.Binding var isFocused: Bool

    var body: some View {
        ZStack {
            TextField("", text: $code)
                .focused($isFocused)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .opacity(0.015)
                .frame(width: 1, height: 1)

            HStack(spacing: 14) {
                ForEach(0..<length, id: \.self) { index in
                    otpCircle(at: index)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
        .onChange(of: code) { _, newValue in
            let filtered = newValue.uppercased().filter { $0.isLetter || $0.isNumber }
            code = String(filtered.prefix(length))
        }
        .padding(.horizontal, ProcessSettingsOpalTheme.horizontalPadding)
    }

    private func otpCircle(at index: Int) -> some View {
        let character = character(at: index)
        let isActive = isFocused && index == code.count

        return ZStack {
            Circle()
                .fill(ProcessSettingsOpalTheme.fieldFillDark)
                .overlay {
                    Circle()
                        .strokeBorder(
                            isActive ? Color.white.opacity(0.45) : ProcessSettingsOpalTheme.fieldStrokeDark,
                            lineWidth: isActive ? 1.5 : 1
                        )
                }
                .frame(width: 52, height: 52)

            if let character {
                Text(String(character))
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .animation(ProcessSettingsOpalTheme.spring, value: code)
        .animation(ProcessSettingsOpalTheme.spring, value: isFocused)
    }

    private func character(at index: Int) -> Character? {
        guard index < code.count else { return nil }
        let stringIndex = code.index(code.startIndex, offsetBy: index)
        return code[stringIndex]
    }
}

struct ProcessSettingsOpalVersionFooter: View {
    var body: some View {
        Text(appVersionLine)
            .font(.system(size: 13))
            .foregroundStyle(ProcessSettingsOpalTheme.valueTint.opacity(0.85))
            .frame(maxWidth: .infinity)
            .padding(.top, 24)
            .padding(.bottom, 8)
    }

    private var appVersionLine: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "v\(version) (\(build))"
    }
}
