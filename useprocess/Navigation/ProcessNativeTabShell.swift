import SwiftUI

// MARK: - Tab bar système iOS 26+ (Liquid Glass + bouton épinglé à droite)

@available(iOS 26.0, *)
struct ProcessNativeTabShell<Plan: View, Statistics: View, Coach: View, Profile: View>: View {
    @Binding var selectedSection: ProcessMainSection
    var onMealScan: () -> Void

    @ViewBuilder var planTab: () -> Plan
    @ViewBuilder var statisticsTab: () -> Statistics
    @ViewBuilder var coachTab: () -> Coach
    @ViewBuilder var profileTab: () -> Profile

    @State private var nativeSelection: NativeTab = .plan
    @State private var profileSubrouteActive = false

    private enum NativeTab: Hashable {
        case plan
        case statistics
        case coach
        case profile
        case mealScan

        init?(_ section: ProcessMainSection) {
            switch section {
            case .plan: self = .plan
            case .routine: return nil
            case .statistics: self = .statistics
            case .coach: self = .coach
            case .profile: self = .profile
            }
        }

        var section: ProcessMainSection? {
            switch self {
            case .plan: return .plan
            case .statistics: return .statistics
            case .coach: return .coach
            case .profile: return .profile
            case .mealScan: return nil
            }
        }
    }

    private var hidesSystemTabBar: Bool {
        selectedSection == .coach || profileSubrouteActive
    }

    var body: some View {
        TabView(selection: $nativeSelection) {
            Tab(
                ProcessMainSection.plan.label,
                systemImage: ProcessMainSection.plan.icon,
                value: NativeTab.plan
            ) {
                planTab()
            }

            Tab(
                ProcessMainSection.statistics.label,
                systemImage: ProcessMainSection.statistics.icon,
                value: NativeTab.statistics
            ) {
                statisticsTab()
            }

            Tab(
                ProcessMainSection.coach.label,
                systemImage: ProcessMainSection.coach.icon,
                value: NativeTab.coach
            ) {
                coachTab()
            }

            Tab(
                ProcessMainSection.profile.label,
                systemImage: ProcessMainSection.profile.icon,
                value: NativeTab.profile
            ) {
                profileTab()
            }

            Tab(AppCopy.meals, systemImage: "fork.knife", value: NativeTab.mealScan, role: .search) {
                Color.clear
                    .accessibilityHidden(true)
            }
            .accessibilityLabel(AppCopy.t("Scanner un repas", en: "Scan a meal"))
            .accessibilityHint(AppCopy.t(
                "Ouvre la caméra ou la pellicule pour analyser ton repas",
                en: "Opens the camera or photo library to analyze your meal"
            ))
        }
        .tabBarMinimizeBehavior(.never)
        .toolbar(hidesSystemTabBar ? .hidden : .visible, for: .tabBar)
        .onPreferenceChange(ProfileSubrouteActiveKey.self) { active in
            guard selectedSection == .profile else {
                if profileSubrouteActive {
                    withAnimation(ProcessGlass.spring) {
                        profileSubrouteActive = false
                    }
                }
                return
            }
            guard profileSubrouteActive != active else { return }
            withAnimation(ProcessGlass.spring) {
                profileSubrouteActive = active
            }
        }
        .onChange(of: nativeSelection) { previous, next in
            handleNativeSelectionChange(from: previous, to: next)
        }
        .onChange(of: selectedSection) { _, section in
            guard let mapped = NativeTab(section), mapped != nativeSelection, mapped != .mealScan else { return }
            nativeSelection = mapped
        }
        .onAppear {
            if let mapped = NativeTab(selectedSection) {
                nativeSelection = mapped
            }
        }
    }

    private func handleNativeSelectionChange(from previous: NativeTab, to next: NativeTab) {
        if next == .mealScan {
            HapticManager.shared.impact(.medium)
            onMealScan()
            nativeSelection = previous == .mealScan ? .plan : previous
            return
        }

        guard let section = next.section else { return }
        guard selectedSection != section else { return }
        HapticManager.shared.impact(.light)
        selectedSection = section
    }
}

/// Enveloppe les racines d’onglets pour le `TabView` système (iOS 26+).
@available(iOS 26.0, *)
struct ProcessNativeTabShellContainer<Plan: View, Statistics: View, Coach: View, Profile: View>: View {
    @Binding var selectedSection: ProcessMainSection
    var onMealScan: () -> Void

    @ViewBuilder var planTab: () -> Plan
    @ViewBuilder var statisticsTab: () -> Statistics
    @ViewBuilder var coachTab: () -> Coach
    @ViewBuilder var profileTab: () -> Profile

    var body: some View {
        ProcessNativeTabShell(
            selectedSection: $selectedSection,
            onMealScan: onMealScan,
            planTab: planTab,
            statisticsTab: statisticsTab,
            coachTab: coachTab,
            profileTab: profileTab
        )
    }
}
