import SwiftUI
import UIKit

/// Outil timer hydratation — rappel boire + Dynamic Island / Live Activity.
struct ProcessHydrationTimerView: View {
    var dayId: String?
    var targetMilliliters: Int = ProcessHydrationTimerState.defaultHydrationTargetML
    var onDismiss: () -> Void

    @Environment(\.appTheme) private var theme
    @Bindable private var timerStore = ProcessHydrationTimerStore.shared
    @Bindable private var hydrationStore = ProcessHydrationLogStore.shared

    @State private var selectedInterval: ProcessHydrationTimerInterval = .fortyFive
    @State private var appeared = false
    @State private var isBusy = false

    private var milliliters: Int { hydrationStore.milliliters() }
    private var progress: CGFloat {
        guard targetMilliliters > 0 else { return 0 }
        return min(1, CGFloat(milliliters) / CGFloat(targetMilliliters))
    }

    private var litersLabel: String {
        let current = String(format: "%g", Double(milliliters) / 1000.0)
        let goal = String(format: "%g", Double(targetMilliliters) / 1000.0)
        return "\(current) / \(goal) L"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                background

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 28) {
                        heroRing
                            .padding(.top, 8)

                        intervalSection

                        if timerStore.isRunning {
                            runningCard
                        }

                        primaryCTA

                        tipLine
                            .padding(.bottom, 28)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }
            }
            .navigationTitle(AppCopy.t("Hydratation", en: "Hydration"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(AppCopy.t("Fermer", en: "Close")) {
                        onDismiss()
                    }
                    .fontWeight(.medium)
                }
            }
        }
        .onAppear {
            selectedInterval = timerStore.selectedInterval
            withAnimation(.easeOut(duration: 0.55)) {
                appeared = true
            }
            ProcessHydrationTimerMonitor.shared.refreshMonitoring()
        }
    }

    // MARK: - Layers

    private var background: some View {
        LinearGradient(
            colors: theme.isDark
                ? [
                    Color(red: 0.04, green: 0.08, blue: 0.14),
                    Color(red: 0.06, green: 0.12, blue: 0.20),
                    theme.background
                ]
                : [
                    Color(red: 0.90, green: 0.97, blue: 1.0),
                    Color(red: 0.96, green: 0.98, blue: 1.0),
                    theme.background
                ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var heroRing: some View {
        ZStack {
            Circle()
                .stroke(theme.secondaryText.opacity(0.12), lineWidth: 14)
                .frame(width: 196, height: 196)

            Circle()
                .trim(from: 0, to: appeared ? progress : 0)
                .stroke(
                    AngularGradient(
                        colors: [
                            Color(red: 0.35, green: 0.78, blue: 0.98),
                            Color(red: 0.15, green: 0.55, blue: 0.92),
                            Color(red: 0.45, green: 0.88, blue: 1.0)
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 196, height: 196)
                .animation(.spring(response: 0.7, dampingFraction: 0.85), value: progress)

            VStack(spacing: 6) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color(red: 0.28, green: 0.72, blue: 0.95))
                    .symbolEffect(.pulse, options: .repeating, isActive: timerStore.isRunning)

                Text(litersLabel)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.primaryText)
                    .monospacedDigit()
                    .contentTransition(.numericText())

                Text(AppCopy.t("aujourd'hui", en: "today"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity)
        .scaleEffect(appeared ? 1 : 0.92)
        .opacity(appeared ? 1 : 0)
    }

    private var intervalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AppCopy.t("Rappel tous les", en: "Remind every"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.primaryText)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ],
                spacing: 10
            ) {
                ForEach(ProcessHydrationTimerInterval.allCases) { interval in
                    intervalChip(interval)
                }
            }
        }
    }

    private func intervalChip(_ interval: ProcessHydrationTimerInterval) -> some View {
        let selected = selectedInterval == interval
        return Button {
            HapticManager.shared.selection()
            selectedInterval = interval
            timerStore.setInterval(interval)
        } label: {
            VStack(spacing: 4) {
                Text(interval.title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(selected ? .white : theme.primaryText)
                Text(interval.subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(selected ? .white.opacity(0.78) : theme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        selected
                            ? Color(red: 0.18, green: 0.58, blue: 0.86)
                            : theme.cardBackground.opacity(theme.isDark ? 0.7 : 0.9)
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        selected ? Color.clear : theme.secondaryText.opacity(0.12),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
    }

    private var runningCard: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = remainingText(at: context.date)
            HStack(spacing: 12) {
                Image(systemName: "timer")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(red: 0.28, green: 0.72, blue: 0.95))

                VStack(alignment: .leading, spacing: 2) {
                    Text(AppCopy.t("Prochain sip", en: "Next sip"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(theme.secondaryText)
                    Text(remaining)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.primaryText)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                Spacer()

                Button {
                    Task {
                        await timerStore.markDrinkDue(source: .manual)
                    }
                } label: {
                    Text(AppCopy.t("Boire", en: "Drink"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color(red: 0.18, green: 0.58, blue: 0.86)))
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(theme.cardBackground.opacity(theme.isDark ? 0.75 : 0.95))
            }
        }
    }

    private var primaryCTA: some View {
        VStack(spacing: 10) {
            Button {
                Task { await toggleTimer() }
            } label: {
                Text(
                    timerStore.isRunning
                        ? AppCopy.t("Arrêter le timer", en: "Stop timer")
                        : AppCopy.t("Démarrer le timer", en: "Start timer")
                )
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(timerStore.isRunning ? theme.primaryText : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background {
                    Capsule(style: .continuous)
                        .fill(
                            timerStore.isRunning
                                ? theme.cardBackground
                                : Color(red: 0.12, green: 0.52, blue: 0.82)
                        )
                }
                .overlay {
                    if timerStore.isRunning {
                        Capsule(style: .continuous)
                            .strokeBorder(theme.secondaryText.opacity(0.18), lineWidth: 1)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(isBusy)

            if timerStore.isRunning {
                HStack(spacing: 10) {
                    quickLog(ml: 250)
                    quickLog(ml: 500)
                }
            }
        }
    }

    private func quickLog(ml: Int) -> some View {
        Button {
            Task {
                _ = await timerStore.logSip(milliliters: ml, celebrateOnHome: true)
            }
        } label: {
            Text("+\(ml) ml")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.primaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background {
                    Capsule(style: .continuous)
                        .fill(theme.cardBackground.opacity(theme.isDark ? 0.75 : 0.95))
                }
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(theme.secondaryText.opacity(0.14), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    private var tipLine: some View {
        Text(AppCopy.t(
            "Compte à rebours dans la Dynamic Island uniquement — rien sur l'écran verrouillé.",
            en: "Countdown in Dynamic Island only — nothing on the Lock Screen."
        ))
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(theme.secondaryText)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 8)
    }

    // MARK: - Actions

    private func toggleTimer() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }

        if timerStore.isRunning {
            await timerStore.stop()
            HapticManager.shared.impact(.light)
            return
        }

        let granted = await timerStore.start(
            interval: selectedInterval,
            dayId: dayId,
            targetMilliliters: targetMilliliters
        )
        _ = granted
        HapticManager.shared.notification(.success)
    }

    private func remainingText(at date: Date) -> String {
        guard let next = timerStore.nextSipAt else {
            return AppCopy.t("—", en: "—")
        }
        let seconds = max(0, Int(next.timeIntervalSince(date)))
        if seconds == 0 {
            return AppCopy.t("Maintenant", en: "Now")
        }
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
