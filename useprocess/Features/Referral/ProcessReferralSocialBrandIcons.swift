import SwiftUI

enum ProcessSocialBrand {
    case copyLink
    case messages
    case instagram
    case whatsApp
    case tikTok
    case snapchat
    case x

    var assetName: String {
        switch self {
        case .copyLink: return "social_copy_link"
        case .messages: return "social_imessage"
        case .instagram: return "social_instagram"
        case .whatsApp: return "social_whatsapp"
        case .tikTok: return "social_tiktok"
        case .snapchat: return "social_snapchat"
        case .x: return "social_x"
        }
    }
}

/// Icône marque — asset carré, crop cercle (parrainage, réglages).
struct ProcessSocialBrandIcon: View {
    let brand: ProcessSocialBrand
    var size: CGFloat = 52
    var showsStroke: Bool = true

    @ViewBuilder
    var body: some View {
        if brand == .copyLink {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.12))
                Image(systemName: "link")
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: size, height: size)
            .overlay {
                if showsStroke {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
                }
            }
            .accessibilityHidden(true)
        } else {
            Image(brand.assetName)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay {
                    if showsStroke {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
                    }
                }
                .accessibilityHidden(true)
        }
    }
}

typealias ProcessReferralSocialBrand = ProcessSocialBrand

struct ProcessReferralSocialBrandIcon: View {
    let brand: ProcessReferralSocialBrand

    var body: some View {
        ProcessSocialBrandIcon(brand: brand, size: 52)
            .shadow(color: Color.black.opacity(0.18), radius: 6, y: 3)
    }
}
