//
//  LaunchScreen.swift
//  useprocess
//
//  Animation d’ouverture — identique à l’app Process (logo + révélation mask).
//

import SwiftUI

struct LaunchScreen<RootView: View, Logo: View>: Scene {
    var config: LaunchScreenConfig = .init()
    @ViewBuilder var logo: () -> Logo
    @ViewBuilder var rootContent: RootView

    var body: some Scene {
        WindowGroup {
            rootContent
                .modifier(LaunchScreenModifier(config: config, logo: logo))
        }
    }
}

private struct LaunchScreenModifier<Logo: View>: ViewModifier {
    var config: LaunchScreenConfig
    @ViewBuilder var logo: Logo

    @Environment(\.scenePhase) private var scenePhase
    @State private var splashWindow: UIWindow?

    func body(content: Content) -> some View {
        content
            .onAppear {
                let scenes = UIApplication.shared.connectedScenes
                for scene in scenes {
                    guard let windowScene = scene as? UIWindowScene,
                          checkStates(windowScene.activationState),
                          !windowScene.windows.contains(where: { $0.tag == 1009 }) else {
                        continue
                    }

                    let window = UIWindow(windowScene: windowScene)
                    window.backgroundColor = .black
                    window.isHidden = false
                    window.isUserInteractionEnabled = true

                    let rootViewController = UIHostingController(
                        rootView: LaunchScreenView(config: config) {
                            logo
                        } isCompleted: {
                            window.isHidden = true
                            window.isUserInteractionEnabled = false
                        }
                    )

                    rootViewController.view.backgroundColor = .black
                    window.rootViewController = rootViewController
                    window.tag = 1009
                    splashWindow = window
                }
            }
    }

    private func checkStates(_ state: UIWindowScene.ActivationState) -> Bool {
        switch scenePhase {
        case .active: return state == .foregroundActive
        case .inactive: return state == .foregroundInactive
        case .background: return state == .background
        @unknown default: return false
        }
    }
}

struct LaunchScreenConfig {
    var initialDelay: Double = 0.2
    var backgroundColor: Color = .black
    var logoBackgroundColor: Color = .white
    var scaling: CGFloat = 4
    var forceHideLogo: Bool = false

    var scaleDownAnimation: Animation = .spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.1)
    var scaleUpAnimation: Animation = .spring(response: 1.0, dampingFraction: 0.75, blendDuration: 0.1)
    var fadeAnimation: Animation = .easeInOut(duration: 1.0)
    var animationDuration: Double = 1.0
}

private struct LaunchScreenView<Logo: View>: View {
    var config: LaunchScreenConfig
    @ViewBuilder var logo: Logo
    var isCompleted: () -> Void

    @State private var logoScale: CGFloat = 1.0
    @State private var maskScale: CGFloat = 0.25

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.black)
                .ignoresSafeArea()

            GeometryReader { geometry in
                let maskSize = geometry.size.applying(
                    .init(scaleX: config.scaling * maskScale, y: config.scaling * maskScale)
                )

                Rectangle()
                    .fill(.black)
                    .mask {
                        Rectangle()
                            .overlay {
                                logo
                                    .blendMode(.destinationOut)
                            }
                            .frame(width: maskSize.width, height: maskSize.height)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
            }

            GeometryReader { _ in
                logo
                    .scaleEffect(logoScale)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(0.3))

            await MainActor.run {
                withAnimation(.easeOut(duration: 0.4)) {
                    logoScale = config.scaling * 2.5
                    maskScale = 1.0
                }
            }

            try? await Task.sleep(for: .seconds(0.2))
            isCompleted()
        }
    }
}
