//
//  PaywallView.swift
//  Process
//
//  Vue paywall pour vendre l'abonnement annuel
//
//  Voir aussi : PaywallParticleEffect ; PaywallView+Content ; PaywallView+TimelineAndSlider ; PaywallView+PurchaseActions.
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @ObservedObject var subscriptionService = SubscriptionService.shared
    @Environment(\.dismiss) var dismiss
    @Environment(\.scenePhase) var scenePhase

    let onComplete: (() -> Void)?
    let onBack: (() -> Void)?

    @State var isPurchasing = false
    @State var isRestoring = false
    @State var errorMessage: String?
    @State var showError = false
    @State var hasScheduledExitNotification = false
    @State var isFreeTrialEnabled = true
    @State var priceScale: CGFloat = 1.0
    @State var buttonTextScale: CGFloat = 1.0
    @State var billingDate: Date?

    @State var sliderProgress: CGFloat = 0.0
    @State var isSliderUnlocked = true
    @State var showUnlockAnimation = false
    @State var titleScale: CGFloat = 1.0
    @State var titleOpacity: Double = 1.0
    @State var currentTitle = "Débloque ton accès illimité à \(AppBranding.name)"

    @State var reflectionOffset: CGFloat = -200
    @State var reflectionOpacity: Double = 0
    @State var buttonScale: CGFloat = 1.0
    @State var buttonOffsetY: CGFloat = 0
    @State var buttonOpacity: Double = 1.0
    @State var buttonGlow: CGFloat = 0
    @State var textGlow: CGFloat = 0
    @State var isAnimating = false

    @State var sliderTransformScale: CGFloat = 1.0
    @State var sliderTransformOpacity: Double = 1.0
    @State var sliderRotation: Double = 0
    @State var sliderBlur: CGFloat = 0
    @State var sliderGlowIntensity: CGFloat = 0
    @State var morphProgress: CGFloat = 0

    @State var iconScale: [CGFloat] = [0.5, 0.5, 0.5]
    @State var iconOpacity: [Double] = [0, 0, 0]
    @State var lineOpacity: [Double] = [0, 0]
    @State var textOpacity: [Double] = [0, 0, 0, 0]
    @State var textOffset: [CGFloat] = [-20, -20, -20, -20]

    let termsURL: URL = {
        guard let url = URL(string: "https://useprocess.framer.website/terms") else {
            fatalError("Invalid terms URL - vérifier la configuration")
        }
        return url
    }()

    let privacyURL: URL = {
        guard let url = URL(string: "https://useprocess.framer.website/privacy") else {
            fatalError("Invalid privacy URL - vérifier la configuration")
        }
        return url
    }()

    init(onComplete: (() -> Void)? = nil, onBack: (() -> Void)? = nil) {
        self.onComplete = onComplete
        self.onBack = onBack
    }

    var body: some View {
        ZStack {
            backgroundView
            mainContentView
            overlayViews
            fixedButtonsView
            loadingIndicatorView
        }
        .onChange(of: subscriptionService.subscriptionStatus) { oldValue, newValue in
            if newValue.isActive && !oldValue.isActive {
                isPurchasing = false
                completePaywallFlow()
            }
        }
        .alert("Erreur", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "Une erreur est survenue lors du traitement de votre demande. Veuillez réessayer.")
        }
        .task {
            await subscriptionService.loadSubscriptions()
            billingDate = Calendar.current.date(byAdding: .day, value: 3, to: Date())
            await subscriptionService.checkSubscriptionStatus()

            if subscriptionService.subscriptionStatus.isActive {
                completePaywallFlow()
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if oldPhase == .active && (newPhase == .background || newPhase == .inactive) {
                scheduleExitNotificationIfNeeded()
            }
        }
        .onDisappear {
            scheduleExitNotificationIfNeeded()
        }
        .onChange(of: isFreeTrialEnabled) { _, _ in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85, blendDuration: 0.3)) {
                buttonTextScale = 1.08
                priceScale = 1.08
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.4)) {
                    buttonTextScale = 1.0
                    priceScale = 1.0
                }
            }
        }
        .onChange(of: isSliderUnlocked) { _, newValue in
            if newValue {
                animateTimelineEntry()
            }
        }
    }

    func completePaywallFlow() {
        if let onComplete {
            onComplete()
        } else {
            dismiss()
        }
    }
}
