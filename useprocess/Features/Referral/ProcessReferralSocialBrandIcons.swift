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
    var linkIconRatio: CGFloat = 0.38
    var brandImageFillScale: CGFloat = 1.0

    @ViewBuilder
    var body: some View {
        if brand == .copyLink {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.12))
                Image(systemName: "link")
                    .font(.system(size: size * linkIconRatio, weight: .semibold))
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
                .scaleEffect(brandImageFillScale)
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

enum ProcessReferralSocialShareMetrics {
    static let buttonSize: CGFloat = 56
    static let linkIconRatio: CGFloat = 0.50
    static let brandImageFillScale: CGFloat = 1.12
}

struct ProcessReferralSocialBrandIcon: View {
    let brand: ProcessReferralSocialBrand
    var size: CGFloat = ProcessReferralSocialShareMetrics.buttonSize

    var body: some View {
        ProcessSocialBrandIcon(
            brand: brand,
            size: size,
            linkIconRatio: ProcessReferralSocialShareMetrics.linkIconRatio,
            brandImageFillScale: ProcessReferralSocialShareMetrics.brandImageFillScale
        )
        .shadow(color: Color.black.opacity(0.18), radius: 6, y: 3)
    }
}
