//
//  PaywallView+PurchaseActions.swift
//  Process
//
//  Achat StoreKit, restauration, mode dev (DEBUG), notification de sortie paywall.
//

import SwiftUI
import StoreKit

extension PaywallView {

    @MainActor
    func purchaseSubscription() async {
        if subscriptionService.annualProduct == nil {
            await subscriptionService.loadSubscriptions()

            guard subscriptionService.canPurchase else {
                errorMessage = "Les offres ne sont pas encore chargées. Veuillez réessayer dans quelques instants."
                showError = true
                return
            }
        }

        isPurchasing = true
        errorMessage = nil

        do {
            try await subscriptionService.purchase()
            await subscriptionService.checkSubscriptionStatus()

            if subscriptionService.subscriptionStatus.isActive {
                isPurchasing = false
                completePaywallFlow()
            }
        } catch {
            if let subscriptionError = error as? SubscriptionError {
                switch subscriptionError {
                case .userCancelled:
                    break
                case .productNotFound:
                    errorMessage = "Le produit d'abonnement est introuvable. Veuillez réessayer plus tard."
                    showError = true
                case .userNotAuthenticated:
                    errorMessage = "Vous devez être connecté pour acheter un abonnement."
                    showError = true
                case .pending:
                    errorMessage = "Votre achat est en attente de validation. Vous serez notifié une fois qu'il sera confirmé."
                    showError = true
                default:
                    errorMessage = subscriptionError.localizedDescription
                    showError = true
                }
            } else {
                errorMessage = "Une erreur est survenue lors de l'achat. Veuillez réessayer."
                showError = true
            }
        }

        isPurchasing = false
    }

    @MainActor
    func restorePurchases() async {
        isRestoring = true
        errorMessage = nil

        do {
            try await subscriptionService.restorePurchases()

            if subscriptionService.subscriptionStatus.isActive {
                completePaywallFlow()
            } else {
                errorMessage = "Aucun abonnement actif trouvé. Si vous avez déjà acheté un abonnement, assurez-vous d'être connecté avec le même compte Apple."
                showError = true
            }
        } catch {
            if let subscriptionError = error as? SubscriptionError {
                errorMessage = subscriptionError.localizedDescription
            } else {
                errorMessage = "Une erreur est survenue lors de la restauration. Veuillez réessayer."
            }
            showError = true
        }

        isRestoring = false
    }

    #if DEBUG
    @MainActor
    func enableDevMode() {
        subscriptionService.forcePremiumForDevelopment()
        completePaywallFlow()
    }

    @MainActor
    func disableDevMode() {
        subscriptionService.disableDevMode()
    }
    #endif

    func scheduleExitNotificationIfNeeded() {
        guard !hasScheduledExitNotification else { return }
        guard !subscriptionService.subscriptionStatus.isActive else { return }

        hasScheduledExitNotification = true

        Task {
            await PaywallExitNotificationService.shared.scheduleExitNotification(hasPurchased: false)
        }
    }
}
