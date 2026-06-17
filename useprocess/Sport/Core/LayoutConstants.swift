//
//  LayoutConstants.swift
//  Process
//
//  Created by ENNASRI Amine on 22/09/2025.
//

import SwiftUI
import UIKit

// MARK: - Layout Constants Adaptatifs
struct LayoutConstants {

    // MARK: - Screen Info
    // Computed — jamais `static let` + UIApplication au chargement (crash 0x0 au lancement).
    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
    }

    static var screenWidth: CGFloat { keyWindow?.bounds.width ?? 393 }
    static var screenHeight: CGFloat { keyWindow?.bounds.height ?? 852 }
    static var safeAreaTop: CGFloat { keyWindow?.safeAreaInsets.top ?? 44 }
    static var safeAreaBottom: CGFloat { keyWindow?.safeAreaInsets.bottom ?? 34 }

    // MARK: - Device Detection (iPad + iPhone)
    /// Détecte si l'appareil est un iPad
    static var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    /// Détecte si c'est un iPad Pro (grand écran)
    static var isIPadPro: Bool {
        isIPad && screenWidth >= 1024
    }

    /// Largeur maximale du contenu sur iPad (centré avec marges)
    static var maxContentWidth: CGFloat {
        if isIPad {
            // Sur iPad : limiter à 800pt max, centré avec marges de 40pt de chaque côté
            return min(800, screenWidth - 80)
        } else {
            // Sur iPhone : utiliser toute la largeur disponible
            return screenWidth
        }
    }

    // MARK: - Device Types (iPhone uniquement)
    static var isSmallDevice: Bool {
        !isIPad && screenHeight <= 667 // iPhone SE, 8
    }
    static var isMediumDevice: Bool {
        !isIPad && screenHeight > 667 && screenHeight <= 812 // iPhone 12 mini, X
    }
    static var isLargeDevice: Bool {
        !isIPad && screenHeight > 812 // iPhone 12 Pro Max, etc.
    }

    // MARK: - Adaptive Spacing
    struct Spacing {
        // Top Bar
        static var topBarTop: CGFloat {
            if isIPad {
                return safeAreaTop + 30 // Plus d'espace sur iPad
            }
            return safeAreaTop + (isSmallDevice ? 10 : isLargeDevice ? 20 : 15)
        }

        static var topBarBottom: CGFloat {
            if isIPad {
                return 30 // Plus d'espace sur iPad
            }
            return isSmallDevice ? 15 : isLargeDevice ? 25 : 20
        }

        // Content Spacing
        static var contentTop: CGFloat {
            if isIPad {
                return topBarTop + 100 + topBarBottom // Top bar height + spacing augmenté pour iPad
            }
            return topBarTop + 80 + topBarBottom // Top bar height + spacing augmenté
        }

        static var contentBottom: CGFloat {
            if isIPad {
                return safeAreaBottom + 80 + 50 // Tab bar + spacing augmenté pour iPad
            }
            return safeAreaBottom + 60 + (isSmallDevice ? 20 : isLargeDevice ? 40 : 30) // Tab bar + spacing
        }

        // Horizontal Margins
        static var horizontal: CGFloat {
            if isIPad {
                return 40 // Marges plus larges sur iPad pour centrer le contenu
            }
            return isSmallDevice ? 16 : isLargeDevice ? 24 : 20
        }

        // Espacement entre éléments
        static var betweenElements: CGFloat {
            if isIPad {
                return 32 // Plus d'espace entre les éléments sur iPad
            }
            return 20
        }

        // Espacement dans les VStack
        static var verticalStack: CGFloat {
            if isIPad {
                return 32 // Plus d'espace vertical sur iPad
            }
            return 20
        }

        // Sync Button
        static var syncButtonBottom: CGFloat {
            if isIPad {
                return 30 // Plus d'espace sur iPad
            }
            return isSmallDevice ? 15 : isLargeDevice ? 25 : 20
        }

        // Page Indicator
        static var pageIndicatorTop: CGFloat {
            if isIPad {
                return 50 // Plus d'espace sur iPad
            }
            return isSmallDevice ? 20 : isLargeDevice ? 40 : 30
        }

        static var pageIndicatorBottom: CGFloat {
            if isIPad {
                return 30 // Plus d'espace sur iPad
            }
            return isSmallDevice ? 15 : isLargeDevice ? 25 : 20
        }
    }

    // MARK: - Content Heights
    struct Heights {
        static var minContentHeight: CGFloat {
            return screenHeight - Spacing.contentTop - Spacing.contentBottom
        }

        static var tabBarSpace: CGFloat {
            return safeAreaBottom + 60 // Tab bar height + margin
        }
    }

    // MARK: - Card Sizing
    struct Cards {
        static var maxWidth: CGFloat {
            if isIPad {
                // Sur iPad : cartes plus larges mais limitées
                return min(350, maxContentWidth - (Spacing.horizontal * 2))
            }
            return min(250, screenWidth - (Spacing.horizontal * 2))
        }

        static var buttonPadding: (horizontal: CGFloat, vertical: CGFloat) {
            if isIPad {
                // Sur iPad : boutons plus grands avec plus de padding
                return (
                    horizontal: 32, // Plus de padding horizontal sur iPad
                    vertical: 120 // Plus de hauteur sur iPad
                )
            }
            return (
                horizontal: isSmallDevice ? 16 : isLargeDevice ? 20 : 18,
                vertical: isSmallDevice ? 80 : isLargeDevice ? 100 : 90
            )
        }

        // Taille minimale des boutons pour iPad (zones de toucher)
        static var minButtonHeight: CGFloat {
            if isIPad {
                return 60 // Minimum 60pt de hauteur sur iPad (recommandation Apple)
            }
            return 44 // Minimum 44pt sur iPhone
        }

        // Taille minimale des boutons pour iPad (zones de toucher)
        static var minButtonWidth: CGFloat {
            if isIPad {
                return 80 // Minimum 80pt de largeur sur iPad
            }
            return 44 // Minimum 44pt sur iPhone
        }
    }

    // MARK: - Typography (Tailles de texte adaptées pour iPad)
    struct Typography {
        static var titleSize: CGFloat {
            if isIPad {
                return 40 // Titres plus grands sur iPad
            }
            return 32
        }

        static var bodySize: CGFloat {
            if isIPad {
                return 18 // Texte plus lisible sur iPad
            }
            return 16
        }

        static var buttonSize: CGFloat {
            if isIPad {
                return 22 // Boutons plus lisibles sur iPad
            }
            return 20
        }
    }
}

// MARK: - SwiftUI Extensions pour faciliter l'usage
extension View {
    func adaptivePadding(_ edges: Edge.Set = .all) -> some View {
        self.padding(edges, LayoutConstants.Spacing.horizontal)
    }

    func adaptiveHorizontalPadding() -> some View {
        self.padding(.horizontal, LayoutConstants.Spacing.horizontal)
    }

    func topBarSpacing() -> some View {
        self.padding(.top, LayoutConstants.Spacing.topBarTop)
            .padding(.bottom, LayoutConstants.Spacing.topBarBottom)
    }

    /// Limite la largeur du contenu sur iPad (centré avec marges)
    func iPadContentWidth() -> some View {
        regularWidthContainer(maxWidth: LayoutConstants.maxContentWidth)
    }

    /// Applique un espacement adaptatif entre éléments
    func adaptiveSpacing(_ spacing: CGFloat? = nil) -> some View {
        self.padding(.vertical, spacing ?? LayoutConstants.Spacing.betweenElements / 2)
    }

    /// Garantit une taille minimale de bouton pour iPad (zones de toucher)
    func iPadMinButtonSize() -> some View {
        Group {
            if LayoutConstants.isIPad {
                self
                    .frame(minWidth: LayoutConstants.Cards.minButtonWidth)
                    .frame(minHeight: LayoutConstants.Cards.minButtonHeight)
            } else {
                self
            }
        }
    }

    /// Applique un espacement adaptatif dans un VStack
    func adaptiveVStackSpacing() -> some View {
        self.padding(.vertical, LayoutConstants.Spacing.verticalStack / 2)
    }
}
