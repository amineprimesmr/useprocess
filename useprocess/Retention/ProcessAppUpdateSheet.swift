import SwiftUI

/// Sheet de mise à jour App Store — optionnelle ou bloquante (`[FORCE]` dans les notes).
struct ProcessAppUpdateSheet: View {
    let info: ProcessAppUpdateInfo
    let isForced: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 18) {
            logo

            VStack(spacing: 8) {
                Text(AppCopy.t("Mise à jour disponible", en: "Update available"))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(theme.primaryText)
                    .multilineTextAlignment(.center)

                Text(AppCopy.t(
                    "Passe de la version \(info.currentVersion) à la \(info.availableVersion).",
                    en: "Go from version \(info.currentVersion) to \(info.availableVersion)."
                ))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(theme.secondaryText)
                .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 8)

            if !visibleNotes.isEmpty {
                Text(visibleNotes)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(5)
                    .padding(.horizontal, 4)
            }

            VStack(spacing: 10) {
                Button {
                    HapticManager.shared.impact(.medium)
                    ProcessAnalytics.trackAppUpdateTapped(
                        from: info.currentVersion,
                        to: info.availableVersion,
                        forced: isForced
                    )
                    openURL(info.appStoreURL)
                    if !isForced {
                        ProcessAppUpdateStore.shared.dismissOptional()
                        dismiss()
                    }
                } label: {
                    Text(AppCopy.t("Mettre à jour", en: "Update"))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(colorScheme == .light ? Color.white : theme.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            colorScheme == .light ? Color.black : theme.primaryText.opacity(0.14),
                            in: Capsule()
                        )
                }
                .buttonStyle(.processPlain)

                if !isForced {
                    Button {
                        HapticManager.shared.impact(.light)
                        ProcessAnalytics.trackAppUpdateDismissed(
                            from: info.currentVersion,
                            to: info.availableVersion
                        )
                        ProcessAppUpdateStore.shared.dismissOptional()
                        dismiss()
                    } label: {
                        Text(AppCopy.t("Plus tard", en: "Later"))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(theme.secondaryText)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.processPlain)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity)
        .processAppPresentationBackground()
        .presentationDetents([.height(notesDetent)])
        .presentationDragIndicator(isForced ? .hidden : .visible)
        .presentationCornerRadius(28)
        .interactiveDismissDisabled(isForced)
    }

    private var notesDetent: CGFloat {
        visibleNotes.isEmpty ? 380 : 460
    }

    private var visibleNotes: String {
        info.releaseNotes
            .replacingOccurrences(of: "[FORCE]", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var logo: some View {
        Group {
            if let url = info.appLogoURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        placeholderLogo
                    }
                }
            } else {
                placeholderLogo
            }
        }
        .frame(width: 84, height: 84)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(theme.primaryText.opacity(0.08), lineWidth: 1)
        )
    }

    private var placeholderLogo: some View {
        ZStack {
            theme.progressTrack
            Image(systemName: "arrow.down.app.fill")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(theme.primaryText)
        }
    }
}

private struct ProcessAppUpdatePromptModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @Bindable private var session = AppSession.shared
    @Bindable private var store = ProcessAppUpdateStore.shared

    func body(content: Content) -> some View {
        content
            .sheet(item: Binding(
                get: { store.presentedUpdate },
                set: { newValue in
                    if let newValue {
                        store.presentedUpdate = newValue
                    } else if store.isForced == false {
                        store.dismissOptional()
                    }
                }
            )) { info in
                ProcessAppUpdateSheet(info: info, isForced: info.isForced)
            }
            .task {
                try? await Task.sleep(for: .milliseconds(1400))
                guard !Task.isCancelled else { return }
                await store.refresh(hasCompletedOnboarding: session.hasCompletedOnboarding)
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task {
                    await store.refresh(hasCompletedOnboarding: session.hasCompletedOnboarding)
                }
            }
            .onChange(of: session.hasCompletedOnboarding) { _, completed in
                guard completed else { return }
                Task {
                    await store.refresh(hasCompletedOnboarding: true)
                }
            }
    }
}

extension View {
    func processAppUpdatePrompt() -> some View {
        modifier(ProcessAppUpdatePromptModifier())
    }
}
