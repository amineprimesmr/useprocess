import SwiftUI
import UIKit

/// Diagnostic d'affichage envoyé à l'ouverture de l'app.
///
/// Sert à identifier, sans dépendre de captures d'écran relayées, les sessions
/// où l'interface devient illisible : texte de la même couleur que le fond,
/// ou surcouche plein écran restée ouverte qui absorbe tous les taps.
@MainActor
enum ProcessRenderDiagnostics {

    /// En dessous de ce ratio WCAG, le texte est illisible sur son fond.
    private static let unreadableContrastRatio: Double = 2.0

    static func captureAppOpenSnapshot(colorScheme: ColorScheme, theme: AppTheme) {
        var props: [String: Any] = [:]

        // MARK: Sources d'apparence — c'est leur divergence qu'on traque
        let swiftUIIsDark = colorScheme == .dark
        props["scheme_swiftui"] = swiftUIIsDark ? "dark" : "light"
        props["scheme_theme_resolved"] = theme.isDark ? "dark" : "light"
        props["appearance_setting"] = AppSession.shared.appearance.rawValue

        let window = keyWindow
        let traits = window?.traitCollection ?? UITraitCollection.current
        props["scheme_window_traits"] = styleName(traits.userInterfaceStyle)
        props["scheme_uikit_current"] = styleName(UITraitCollection.current.userInterfaceStyle)
        if let window {
            props["window_override_style"] = styleName(window.overrideUserInterfaceStyle)
        }

        let traitsAreDark = traits.userInterfaceStyle == .dark
        props["scheme_diverges"] = traitsAreDark != swiftUIIsDark
        props["theme_diverges_from_swiftui"] = theme.isDark != swiftUIIsDark

        // MARK: La mesure qui compte — le texte est-il lisible sur le fond peint ?
        let paintedBackground = ProcessBackgroundPalette.uiColor(for: theme.isDark ? .dark : .light)

        // Couleur système, telle que la résolvent les écrans encore sur Color(.label).
        let systemLabel = UIColor.label.resolvedColor(with: traits)
        let systemRatio = contrastRatio(systemLabel, paintedBackground)
        props["system_label_contrast"] = rounded(systemRatio)
        props["system_label_unreadable"] = systemRatio < unreadableContrastRatio

        // Couleur du thème après unification des sources.
        let themeLabel: UIColor = theme.isDark ? .white : .black
        let themeRatio = contrastRatio(themeLabel, paintedBackground)
        props["theme_label_contrast"] = rounded(themeRatio)
        props["theme_label_unreadable"] = themeRatio < unreadableContrastRatio

        // MARK: Surcouches capables de bloquer toute l'app
        let tutorial = PlanHomeTutorialStore.shared
        props["tutorial_active"] = tutorial.isActive
        props["tutorial_completed"] = tutorial.hasCompleted
        props["tutorial_step"] = tutorial.currentStep.rawValue
        props["scan_toast_presented"] = ScanCompletionToastPresenter.shared.isPresented
        props["screen_flash_active"] = FaceScanScreenFlash.shared.isActive
        props["account_wipe_in_progress"] = AppSession.shared.isAccountWipeInProgress
        props["has_plan"] = WelcomePlanStore.shared.plan != nil

        if let overlay = window?.windowScene?.windows.first(where: { $0.tag == 1009 }) {
            props["island_window_interactive"] = overlay.isUserInteractionEnabled
        }

        // MARK: Environnement
        props["ios_version"] = UIDevice.current.systemVersion
        props["device_model"] = hardwareModel
        props["low_power_mode"] = ProcessInfo.processInfo.isLowPowerModeEnabled
        props["screen_brightness"] = rounded(Double(UIScreen.main.brightness))
        props["a11y_reduce_transparency"] = UIAccessibility.isReduceTransparencyEnabled
        props["a11y_invert_colors"] = UIAccessibility.isInvertColorsEnabled
        props["a11y_darker_colors"] = UIAccessibility.isDarkerSystemColorsEnabled
        props["a11y_reduce_motion"] = UIAccessibility.isReduceMotionEnabled

        ProcessAnalytics.capture("app_render_diagnostics", properties: props)
    }

    // MARK: - Outils

    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
    }

    private static func styleName(_ style: UIUserInterfaceStyle) -> String {
        switch style {
        case .dark: "dark"
        case .light: "light"
        default: "unspecified"
        }
    }

    private static func rounded(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }

    /// Ratio de contraste WCAG entre deux couleurs opaques.
    private static func contrastRatio(_ lhs: UIColor, _ rhs: UIColor) -> Double {
        let a = relativeLuminance(lhs)
        let b = relativeLuminance(rhs)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    private static func relativeLuminance(_ color: UIColor) -> Double {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            var white: CGFloat = 0
            color.getWhite(&white, alpha: &alpha)
            red = white; green = white; blue = white
        }
        func linear(_ channel: CGFloat) -> Double {
            let value = Double(channel)
            return value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    private static var hardwareModel: String {
        var info = utsname()
        uname(&info)
        return withUnsafePointer(to: &info.machine) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
    }
}
