import SwiftUI

/// Résumé scan visage — page Plan, sous le bandeau de jours.
struct PlanLastFaceScanSection: View {
    let latest: FaceScanResult?
    let isScanDue: Bool
    var zoomNamespace: Namespace.ID? = nil
    var onOpenHistory: (() -> Void)? = nil

    @Environment(\.appTheme) private var theme
    @Bindable private var displayPreferences = PlanHomeFaceScanDisplayPreferences.shared

    private let videoWidthRatio: CGFloat = 0.38
    private let cardRadius: CGFloat = 16
    private let expandedCardHeight: CGFloat = 148

    /// Panneau vidéo uniquement quand un scan existe et l’aperçu visage est activé.
    private var showsMediaColumn: Bool {
        latest != nil && displayPreferences.showsVideo
    }

    var body: some View {
        Group {
            if onOpenHistory != nil {
                Button(action: openHistory) {
                    cardContent
                }
                .buttonStyle(PlanFaceScanSectionButtonStyle())
            } else {
                cardContent
            }
        }
        .processZoomSource(id: .faceScanHistory, namespace: zoomNamespace)
        .onAppear {
            displayPreferences.reload()
        }
    }

    private func openHistory() {
        HapticManager.shared.impact(.light)
        onOpenHistory?()
    }

    @ViewBuilder
    private var cardContent: some View {
        Group {
            if showsMediaColumn {
                expandedCardContent
            } else {
                compactCardContent
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: showsMediaColumn)
        .contentShape(cardShape)
        .contextMenu {
            faceScanDisplayMenu
        }
    }

  // MARK: - Layout avec vidéo

    private var expandedCardContent: some View {
        GeometryReader { geo in
            let videoWidth = min(max(118, geo.size.width * videoWidthRatio), geo.size.width * 0.44)

            HStack(spacing: 0) {
                videoSidePanel
                    .frame(width: videoWidth)
                    .frame(maxHeight: .infinity)

                VStack(alignment: .leading, spacing: 12) {
                    headerContent
                    nextScanCountdownPanel
                }
                .padding(.vertical, 14)
                .padding(.leading, 14)
                .padding(.trailing, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, minHeight: expandedCardHeight, alignment: .leading)
            .background(cardBackground)
            .clipShape(cardShape)
        }
        .frame(height: expandedCardHeight)
    }

    private var videoSidePanel: some View {
        ZStack(alignment: .trailing) {
            if let latest {
                PlanFaceScanMediaPanel(result: latest)
                    .equatable()
            }

            LinearGradient(
                colors: [
                    .clear,
                    theme.isDark
                        ? Color(red: 0.11, green: 0.11, blue: 0.12).opacity(0.35)
                        : theme.cardBackgroundStrong.opacity(0.55),
                    cardBackgroundColor.opacity(0.95)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 44)
            .allowsHitTesting(false)
        }
        .frame(maxHeight: .infinity)
        .clipped()
    }

    // MARK: - Layout compact (visage masqué ou pas de scan)

    private var compactCardContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            compactHeaderRow
            nextScanCountdownPanel
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .clipShape(cardShape)
    }

    private var compactHeaderRow: some View {
        HStack(alignment: .top, spacing: 12) {
            compactLeadingIcon

            VStack(alignment: .leading, spacing: 4) {
                Text("Dernier scan visage")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.primaryText)

                Text(compactSubtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

            if let latest {
                FaceWellnessScoreBadge(
                    score: latest.resolvedFaceDayScore,
                    theme: theme,
                    style: .compact
                )
            }
        }
    }

    private var compactSubtitle: String {
        if let latest {
            return "\(lastScanDateLabel(for: latest.createdAt)) · Aperçu masqué"
        }
        return "Aucun scan enregistré"
    }

    private var compactLeadingIcon: some View {
        ZStack {
            Circle()
                .fill(compactIconFill.opacity(0.16))
                .frame(width: 40, height: 40)

            Image(systemName: latest == nil ? "camera.fill" : "eye.slash")
                .font(.body.weight(.semibold))
                .foregroundStyle(compactIconFill)
        }
        .accessibilityLabel(compactIconAccessibilityLabel)
    }

    private var compactIconFill: Color {
        if latest == nil {
            return .orange
        }
        return theme.secondaryText.opacity(0.75)
    }

    private var compactIconAccessibilityLabel: String {
        latest == nil ? "Aucun scan" : "Aperçu visage masqué"
    }

    @ViewBuilder
    private var faceScanDisplayMenu: some View {
        if latest != nil {
            if displayPreferences.showsVideo {
                Button {
                    HapticManager.shared.selection()
                    displayPreferences.setShowsVideo(false)
                } label: {
                    Label("Masquer mon visage", systemImage: "eye.slash")
                }
            } else {
                Button {
                    HapticManager.shared.selection()
                    displayPreferences.setShowsVideo(true)
                } label: {
                    Label("Afficher la vidéo", systemImage: "video")
                }
            }
        }
    }

    private var cardShape: some Shape {
        RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
    }

    // MARK: - En-tête (layout vidéo)

    private var headerContent: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Dernier scan visage")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.primaryText)

                if let latest {
                    Text(lastScanDateLabel(for: latest.createdAt))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 4)

            if let latest {
                FaceWellnessScoreBadge(
                    score: latest.resolvedFaceDayScore,
                    theme: theme,
                    style: .compact
                )
            }
        }
    }

    // MARK: - Compte à rebours

    @ViewBuilder
    private var nextScanCountdownPanel: some View {
        if latest == nil || isScanDue {
            scanDuePanel
        } else {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                activeCountdownPanel(now: context.date)
            }
        }
    }

    private var scanDuePanel: some View {
        HStack(spacing: 12) {
            if showsMediaColumn {
                ZStack {
                    Circle()
                        .fill((latest == nil ? Color.orange : theme.onboardingAccent).opacity(0.16))
                        .frame(width: 40, height: 40)
                    Image(systemName: "camera.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(latest == nil ? .orange : theme.onboardingAccent)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(latest == nil ? "Premier scan" : "C'est le moment")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
                    .textCase(.uppercase)
                Text(latest == nil ? "Lance ton premier scan" : "Scan disponible")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(latest == nil ? .orange : theme.onboardingAccent)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(countdownSurface)
    }

    private func activeCountdownPanel(now: Date) -> some View {
        let headline = FaceScanCadence.nextScanHeadline(since: latest?.createdAt, now: now)
        let components = FaceScanCadence.countdownComponents(since: latest?.createdAt, now: now)
        let progress = latest.map { FaceScanCadence.intervalProgress(since: $0.createdAt, now: now) } ?? 0

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Prochain scan")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(theme.secondaryText)
                        .textCase(.uppercase)
                    Text(headline)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(theme.primaryText)
                }

                Spacer(minLength: 4)

                if let components {
                    countdownDigits(components)
                }
            }

            scanProgressBar(progress: progress)
        }
        .padding(12)
        .background(countdownSurface)
    }

    private func countdownDigits(_ components: FaceScanCadence.CountdownComponents) -> some View {
        HStack(spacing: 4) {
            if components.hours > 0 {
                countdownDigit(value: components.hours, unit: "h")
            }
            countdownDigit(value: components.minutes, unit: "m")
            countdownDigit(value: components.seconds, unit: "s")
        }
        .accessibilityLabel(FaceScanCadence.countdownLabel(since: latest?.createdAt))
    }

    private func countdownDigit(value: Int, unit: String) -> some View {
        VStack(spacing: 1) {
            Text(String(format: "%02d", value))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(theme.primaryText)
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(unit)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(theme.secondaryText)
        }
        .frame(minWidth: 30)
        .padding(.horizontal, 4)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(theme.isDark ? Color.white.opacity(0.07) : Color.white.opacity(0.82))
        )
    }

    private func scanProgressBar(progress: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(theme.isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.06))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [theme.onboardingAccent.opacity(0.85), theme.glow.opacity(0.95)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(6, geo.size.width * progress))
                    .animation(.easeInOut(duration: 0.35), value: progress)
            }
        }
        .frame(height: 5)
        .accessibilityLabel("Progression vers le prochain scan")
        .accessibilityValue("\(Int(progress * 100)) pour cent")
    }

    // MARK: - Style

    private var cardBackgroundColor: Color {
        theme.isDark ? Color(red: 0.11, green: 0.11, blue: 0.12) : theme.cardBackgroundStrong
    }

    private var cardBackground: some View {
        cardShape.fill(cardBackgroundColor)
    }

    private var countdownSurface: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(theme.isDark ? Color.white.opacity(0.05) : theme.cardBackground.opacity(0.88))
    }

    private func lastScanDateLabel(for date: Date) -> String {
        let calendar = Calendar.current
        let dayLabel: String
        if calendar.isDateInToday(date) {
            dayLabel = "Aujourd'hui"
        } else if calendar.isDateInYesterday(date) {
            dayLabel = "Hier"
        } else {
            dayLabel = date.formatted(.dateTime.day().month(.abbreviated))
        }
        return "\(dayLabel) · \(date.formatted(date: .omitted, time: .shortened))"
    }
}

private struct PlanFaceScanSectionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.78), value: configuration.isPressed)
    }
}

/// Panneau média isolé du compte à rebours pour éviter de recréer le lecteur vidéo chaque seconde.
private struct PlanFaceScanMediaPanel: View, Equatable {
    let result: FaceScanResult

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.result.id == rhs.result.id
            && lhs.result.videoFilename == rhs.result.videoFilename
            && lhs.result.snapshotFilename == rhs.result.snapshotFilename
    }

    var body: some View {
        FaceScanRecordingMediaView(
            result: result,
            displayMode: .sidePanel
        )
        .accessibilityLabel("Vidéo du dernier scan visage")
    }
}
