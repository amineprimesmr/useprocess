import SwiftUI

extension View {
    /// Tutoriel accueil — onglet Série uniquement (sections = inline sur Plan).
    func planHomeTutorial(selectedSection: Binding<ProcessMainSection>) -> some View {
        planHomeTutorial(store: PlanHomeTutorialStore.shared, selectedSection: selectedSection)
    }

    func planHomeTutorial(
        store: PlanHomeTutorialStore,
        selectedSection: Binding<ProcessMainSection>
    ) -> some View {
        modifier(PlanHomeTutorialModifier(store: store, selectedSection: selectedSection))
    }
}

private struct PlanHomeTutorialModifier: ViewModifier {
    @Bindable var store: PlanHomeTutorialStore
    @Bindable private var planStore = WelcomePlanStore.shared
    @Binding var selectedSection: ProcessMainSection
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if store.isActive, store.currentStep.isTabStep {
                    PlanHomeTutorialTabStepFooter(store: store)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(900)
                }
            }
            .onAppear {
                bootstrapTutorial()
            }
            .onChange(of: planStore.plan?.id) { _, _ in
                requestTutorial(preferImmediate: true)
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active:
                    store.reload()
                    requestTutorial(preferImmediate: true)
                case .background:
                    store.cancelScheduledPresentation()
                default:
                    break
                }
            }
            .onChange(of: store.requestedMainSection) { _, section in
                guard store.isActive else { return }
                if selectedSection != section {
                    withAnimation(ProcessGlass.spring) {
                        selectedSection = section
                    }
                }
            }
            .onChange(of: store.isActive) { _, active in
                // Ne ramener sur Plan qu'au démarrage du tutoriel. Le forcer aussi
                // à la sortie empêchait toute navigation manuelle.
                if active, selectedSection != .plan {
                    withAnimation(ProcessGlass.spring) {
                        selectedSection = .plan
                    }
                }
            }
            .onChange(of: selectedSection) { _, section in
                // L'utilisateur change d'onglet lui-même pendant le tutoriel :
                // c'est un abandon volontaire, on le termine au lieu de le rejouer.
                guard store.isActive, section != store.requestedMainSection else { return }
                store.skip()
            }
    }

    private func bootstrapTutorial() {
        store.reload()
        requestTutorial(preferImmediate: true)
    }

    private func requestTutorial(preferImmediate: Bool) {
        store.schedulePresentationIfNeeded(
            planAvailable: planStore.plan != nil,
            preferImmediate: preferImmediate
        )
    }
}

/// Footer flottant — uniquement étapes onglet (hors scroll Plan).
private struct PlanHomeTutorialTabStepFooter: View {
    @Bindable var store: PlanHomeTutorialStore

    var body: some View {
        VStack(spacing: 0) {
            PlanHomeTutorialCaption(step: store.currentStep)
                .environment(\.colorScheme, .dark)
                .padding(.horizontal, 22)
                .padding(.bottom, 18)

            PlanHomeTutorialTabStepControls(store: store)
                .padding(.horizontal, 22)
                .padding(.bottom, UIApplication.safeAreaBottom + 16)
        }
        .background {
            LinearGradient(
                colors: [
                    Color.black.opacity(0),
                    Color.black.opacity(0.55),
                    Color.black.opacity(0.72)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
            .allowsHitTesting(false)
        }
    }
}

private struct PlanHomeTutorialTabStepControls: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var store: PlanHomeTutorialStore

    var body: some View {
        VStack(spacing: 14) {
            Button {
                store.advance()
            } label: {
                Text(store.currentStepIndex + 1 >= store.steps.count
                     ? AppCopy.t("C'est parti", en: "Let's go")
                     : AppCopy.t("Continuer", en: "Continue"))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(
                        PlanHomeTutorialChromeStyle.continueButtonForeground(for: colorScheme)
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        Capsule(style: .continuous)
                            .fill(PlanHomeTutorialChromeStyle.continueButtonBackground(for: colorScheme))
                    )
            }
            .buttonStyle(.processPlain)

            PlanHomeTutorialSkipButton {
                store.skip()
            }
            .environment(\.colorScheme, .dark)
        }
    }
}
