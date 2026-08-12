import SwiftUI

/// Mockup lock screen iPhone — remplaçable plus tard par un asset PNG dédié.
struct OnboardingPushNotificationPhoneMockup: View {
    /// Asset optionnel (`onboarding_push_notification_phone`) — prioritaire s'il existe.
    var assetName: String = "onboarding_push_notification_phone"

    private let designSize = CGSize(width: 390, height: 844)
    private let cornerRadius: CGFloat = 48

    var body: some View {
        Group {
            if UIImage(named: assetName) != nil {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
            } else {
                programmaticMockup
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(designSize.width / designSize.height, contentMode: .fit)
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 0.82),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var programmaticMockup: some View {
        GeometryReader { proxy in
            let scale = min(
                proxy.size.width / designSize.width,
                proxy.size.height / designSize.height
            )
            let size = CGSize(
                width: designSize.width * scale,
                height: designSize.height * scale
            )

            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius * scale, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.78, green: 0.90, blue: 0.82),
                                Color(red: 0.96, green: 0.82, blue: 0.88),
                                Color(red: 0.98, green: 0.90, blue: 0.72)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(spacing: 0) {
                    dynamicIsland(scale: scale)
                        .padding(.top, 14 * scale)

                    lockScreenHeader(scale: scale)
                        .padding(.top, 28 * scale)

                    notificationStack(scale: scale)
                        .padding(.top, 22 * scale)
                        .padding(.horizontal, 16 * scale)

                    Spacer(minLength: 0)

                    lockScreenWidgets(scale: scale)
                        .padding(.horizontal, 22 * scale)
                        .padding(.bottom, 24 * scale)
                }

                phoneChrome(scale: scale, size: size)
            }
            .frame(width: size.width, height: size.height)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func phoneChrome(scale: CGFloat, size: CGSize) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius * scale, style: .continuous)
            .strokeBorder(Color.black.opacity(0.88), lineWidth: 3 * scale)
            .frame(width: size.width, height: size.height)
    }

    @ViewBuilder
    private func dynamicIsland(scale: CGFloat) -> some View {
        HStack(spacing: 10 * scale) {
            Image(systemName: "drop.fill")
                .font(.system(size: 11 * scale, weight: .bold))
                .foregroundStyle(Color(red: 0.34, green: 0.74, blue: 0.98))

            Capsule(style: .continuous)
                .fill(Color.black)
                .frame(width: 118 * scale, height: 34 * scale)

            Image(systemName: "drop.fill")
                .font(.system(size: 11 * scale, weight: .bold))
                .foregroundStyle(Color(red: 0.34, green: 0.74, blue: 0.98))
        }
    }

    @ViewBuilder
    private func lockScreenHeader(scale: CGFloat) -> some View {
        VStack(spacing: 4 * scale) {
            Text(lockScreenDateLabel)
                .font(.system(size: 16 * scale, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))

            Text("9:41")
                .font(.system(size: 58 * scale, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .shadow(color: .black.opacity(0.18), radius: 8 * scale, y: 3 * scale)
    }

    @ViewBuilder
    private func notificationStack(scale: CGFloat) -> some View {
        ZStack(alignment: .top) {
            blurredNotification(
                scale: scale,
                tint: Color.green,
                symbol: "message.fill",
                offset: CGSize(width: 0, height: 18 * scale)
            )

            blurredNotification(
                scale: scale,
                tint: Color.red,
                symbol: "heart.fill",
                offset: CGSize(width: 0, height: 36 * scale)
            )

            primaryNotificationCard(scale: scale)
        }
        .frame(height: 150 * scale)
    }

    @ViewBuilder
    private func blurredNotification(
        scale: CGFloat,
        tint: Color,
        symbol: String,
        offset: CGSize
    ) -> some View {
        RoundedRectangle(cornerRadius: 18 * scale, style: .continuous)
            .fill(.white.opacity(0.55))
            .frame(height: 58 * scale)
            .overlay(alignment: .leading) {
                HStack(spacing: 10 * scale) {
                    RoundedRectangle(cornerRadius: 8 * scale, style: .continuous)
                        .fill(tint.opacity(0.85))
                        .frame(width: 28 * scale, height: 28 * scale)
                        .overlay {
                            Image(systemName: symbol)
                                .font(.system(size: 12 * scale, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    RoundedRectangle(cornerRadius: 4 * scale)
                        .fill(Color.black.opacity(0.08))
                        .frame(width: 120 * scale, height: 8 * scale)
                    Spacer()
                }
                .padding(.horizontal, 12 * scale)
            }
            .blur(radius: 1.2 * scale)
            .opacity(0.72)
            .offset(offset)
    }

    @ViewBuilder
    private func primaryNotificationCard(scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8 * scale) {
            HStack(alignment: .top, spacing: 10 * scale) {
                Image("ProcessAppIcon")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 38 * scale, height: 38 * scale)
                    .clipShape(RoundedRectangle(cornerRadius: 9 * scale, style: .continuous))

                VStack(alignment: .leading, spacing: 4 * scale) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(OnboardingCopy.t("Temps pour se détendre", en: "Time to unwind"))
                            .font(.system(size: 14 * scale, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.92))
                            .lineLimit(1)

                        Spacer(minLength: 6 * scale)

                        Text(OnboardingCopy.t("Maintenant", en: "Now"))
                            .font(.system(size: 12 * scale, weight: .medium))
                            .foregroundStyle(Color.black.opacity(0.42))
                    }

                    Text(OnboardingCopy.t(
                        "Vous devez commencer à vous détendre à 23 h 18 et vous mettre au lit avant 23 h 48 pour profiter d'un sommeil optimal.",
                        en: "Start winding down at 11:18 PM and be in bed before 11:48 PM for optimal sleep."
                    ))
                    .font(.system(size: 12 * scale, weight: .regular))
                    .foregroundStyle(Color.black.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2 * scale)
                }
            }
        }
        .padding(12 * scale)
        .background {
            RoundedRectangle(cornerRadius: 20 * scale, style: .continuous)
                .fill(.white.opacity(0.94))
                .shadow(color: .black.opacity(0.12), radius: 16 * scale, y: 8 * scale)
        }
    }

    @ViewBuilder
    private func lockScreenWidgets(scale: CGFloat) -> some View {
        HStack(spacing: 14 * scale) {
            ForEach([40, 60, 75], id: \.self) { value in
                ZStack {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.35), lineWidth: 4 * scale)
                        .frame(width: 46 * scale, height: 46 * scale)

                    Text("\(value)")
                        .font(.system(size: 13 * scale, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))
                }
            }
        }
    }

    private var lockScreenDateLabel: String {
        let formatter = DateFormatter()
        formatter.locale = ProcessAppLanguage.shared.locale
        formatter.setLocalizedDateFormatFromTemplate("EEEdMMM")
        return formatter.string(from: Date())
    }
}
