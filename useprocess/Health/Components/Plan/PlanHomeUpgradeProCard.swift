import SwiftUI

/// Carte « Upgrade to Bevel Pro » — Accueil, sous le scan.
struct PlanHomeUpgradeProCard: View {
    @ObservedObject private var subscriptionService = SubscriptionService.shared
    @Bindable private var tutorialStore = PlanHomeTutorialStore.shared
    @Bindable private var dismissal = PlanHomeUpgradeProCardStore.shared
    @State private var showReferralProgram = false

    var body: some View {
        Group {
            if isVisible {
                stackedCards
                    .padding(.top, 18)
                    .transition(sideDismissal)
            }
        }
        .fullScreenCover(isPresented: $showReferralProgram) {
            ProcessReferralProgramView()
                .environmentObject(UnifiedProfileService.shared)
        }
    }

    private var isVisible: Bool {
        !tutorialStore.constrainsHomeLayout
            && !dismissal.isStackDismissed
    }

    private var stackedCards: some View {
        ZStack(alignment: .top) {
            if !dismissal.isStackDismissed {
                upgradeCard(for: .referral)
                    .id("upgrade-back")
                    .scaleEffect(x: dismissal.isFrontDismissed ? 1 : 0.945, y: 1, anchor: .top)
                    .offset(y: dismissal.isFrontDismissed ? 0 : Layout.stackPeek)
                    .opacity(dismissal.isFrontDismissed ? 1 : 0.72)
                    .allowsHitTesting(dismissal.isFrontDismissed)
                    .zIndex(1)
            }

            if !dismissal.isFrontDismissed {
                upgradeCard(for: .welcome)
                    .id("upgrade-front")
                    .zIndex(2)
                    .transition(sideDismissal)
            }
        }
        .padding(.bottom, dismissal.isFrontDismissed ? 0 : Layout.stackPeek)
        .animation(deckAnimation, value: dismissal.isFrontDismissed)
        .animation(deckAnimation, value: dismissal.isStackDismissed)
        .onAppear {
            dismissal.reload()
        }
    }

    private var sideDismissal: AnyTransition {
        .asymmetric(
            insertion: .identity,
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    private var deckAnimation: Animation {
        .spring(response: 0.38, dampingFraction: 0.88)
    }

    private func upgradeCard(for kind: CardKind) -> some View {
        let isReferral = kind == .referral
        return ZStack(alignment: .topLeading) {
            Button(action: { handleCardTap(kind) }) {
                ZStack(alignment: .topLeading) {
                    PlanHomeUpgradeProCardBackdrop()

                    fadedMark(for: kind)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)

                    VStack(alignment: .leading, spacing: isReferral ? 7 : 5) {
                        Text(title(for: kind))
                            .font(.system(size: isReferral ? 21 : 17, weight: .bold))
                            .tracking(isReferral ? -0.36 : -0.28)
                            .foregroundStyle(Color.white)
                            .lineLimit(isReferral ? 2 : 1)
                            .minimumScaleFactor(0.82)

                        Text(subtitle(for: kind))
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Color(red: 0.82, green: 0.82, blue: 0.84))
                            .lineSpacing(1.2)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.leading, 16)
                    .padding(.trailing, isReferral ? 92 : 44)
                    .padding(.top, 16)
                    .padding(.bottom, 14)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel(title(for: kind))
            .accessibilityHint(
                isReferral
                    ? AppCopy.t("Ouvre le parrainage", en: "Opens the referral program")
                    : AppCopy.t("Touche pour masquer", en: "Tap to dismiss")
            )

            closeButton
                .zIndex(2)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 10)
                .padding(.trailing, 10)
        }
        .frame(height: Layout.height)
        .clipShape(cardShape)
        .overlay {
            cardShape
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.6)
        }
        .shadow(color: Color.black.opacity(0.22), radius: 8, y: 3)
        .contentShape(cardShape)
        .accessibilityElement(children: .contain)
    }

    private var closeButton: some View {
        Button(action: dismissTopCard) {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.94))
                .frame(width: 30, height: 30)
                .background {
                    Circle()
                        .fill(Color.black.opacity(0.42))
                        .overlay {
                            Circle()
                                .strokeBorder(Color.white.opacity(0.28), lineWidth: 0.7)
                        }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(AppCopy.close)
    }

    @ViewBuilder
    private func fadedMark(for kind: CardKind) -> some View {
        switch kind {
        case .welcome:
            fadedImageMark(
                name: "ProcessAppIcon",
                blendMode: .plusLighter,
                opacity: 0.88
            )
        case .referral:
            fadedImageMark(
                name: "PlanHomeUpgradeDollar",
                blendMode: .normal,
                opacity: 0.92
            )
        }
    }

    private func fadedImageMark(name: String, blendMode: BlendMode, opacity: Double) -> some View {
        Image(name)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: Layout.markSize, height: Layout.markSize)
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .white.opacity(0.12), location: 0.22),
                        .init(color: .white.opacity(0.55), location: 0.48),
                        .init(color: .white.opacity(0.92), location: 0.72),
                        .init(color: .white.opacity(0.55), location: 1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.35), location: 0),
                        .init(color: .white, location: 0.28),
                        .init(color: .white.opacity(0.82), location: 0.62),
                        .init(color: .white.opacity(0.08), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .blendMode(blendMode)
            .opacity(opacity)
            .offset(x: 22, y: 6)
            .accessibilityHidden(true)
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
    }

    private func handleCardTap(_ kind: CardKind) {
        HapticManager.shared.impact(.medium)
        switch kind {
        case .welcome:
            withAnimation(deckAnimation) {
                dismissal.dismissTop()
            }
        case .referral:
            showReferralProgram = true
        }
    }

    private func dismissTopCard() {
        HapticManager.shared.impact(.medium)
        withAnimation(deckAnimation) {
            dismissal.dismissTop()
        }
    }

    private func title(for kind: CardKind) -> String {
        switch kind {
        case .welcome:
            return AppCopy.t("Bienvenue dans Process", en: "Welcome to Process")
        case .referral:
            return AppCopy.t("🎁 40 % à vie", en: "🎁 40% for life")
        }
    }

    private func subtitle(for kind: CardKind) -> String {
        switch kind {
        case .welcome:
            return AppCopy.t(
                "Ton plan est prêt. Scanne, suis le programme et avance chaque jour.",
                en: "Your plan is ready. Scan, follow the program, and move forward every day."
            )
        case .referral:
            return AppCopy.t(
                "Partage ton lien. Tu touches 40 % du net à chaque paiement de tes amis.",
                en: "Share your link. You earn 40% of net on every payment from friends."
            )
        }
    }

    private enum CardKind {
        case welcome
        case referral
    }

    private enum Layout {
        static let height: CGFloat = 148
        static let cornerRadius: CGFloat = 24
        static let markSize: CGFloat = 148
        static let stackPeek: CGFloat = 11
    }
}

// MARK: - Fond étoiles / nébuleuse

private struct PlanHomeUpgradeProCardBackdrop: View {
    var body: some View {
        ZStack {
            Color(red: 0.055, green: 0.063, blue: 0.086)

            Image("PlanHomeUpgradeNebula")
                .resizable()
                .scaledToFill()
                .opacity(0.94)
                .clipped()

            RadialGradient(
                colors: [
                    Color(red: 0.62, green: 0.66, blue: 0.74).opacity(0.16),
                    Color.clear
                ],
                center: UnitPoint(x: 0.14, y: 0.92),
                startRadius: 4,
                endRadius: 220
            )

            LinearGradient(
                colors: [
                    Color(red: 0.55, green: 0.60, blue: 0.70).opacity(0.10),
                    Color.clear,
                    Color.white.opacity(0.04)
                ],
                startPoint: UnitPoint(x: 0.0, y: 1.0),
                endPoint: UnitPoint(x: 0.92, y: 0.08)
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .allowsHitTesting(false)
    }
}

// MARK: - Persistance fermeture

@MainActor
@Observable
final class PlanHomeUpgradeProCardStore {
    static let shared = PlanHomeUpgradeProCardStore()

    private static let stackKey = "plan.home.upgrade_pro.dismissed"
    private static let frontKey = "plan.home.upgrade_pro.front_dismissed"

    private(set) var isFrontDismissed = false
    private(set) var isStackDismissed = false

    private init() {
        reload()
    }

    func reload() {
        isStackDismissed = UserDefaults.standard.bool(
            forKey: UserScopedStorage.key(Self.stackKey)
        )
        isFrontDismissed = isStackDismissed || UserDefaults.standard.bool(
            forKey: UserScopedStorage.key(Self.frontKey)
        )
    }

    func dismissTop() {
        if !isFrontDismissed {
            isFrontDismissed = true
            UserDefaults.standard.set(true, forKey: UserScopedStorage.key(Self.frontKey))
            return
        }
        isStackDismissed = true
        UserDefaults.standard.set(true, forKey: UserScopedStorage.key(Self.stackKey))
    }
}
