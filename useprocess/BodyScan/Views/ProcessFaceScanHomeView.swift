import AVFoundation
import SwiftUI

/// Hub Scan — aperçu caméra, historique, cohérence entre scans.
struct ProcessFaceScanHomeView: View {
    @Binding var selectedSection: ProcessMainSection
    var isTabActive: Bool = true
    var isOnboardingPreview: Bool = false

    @Environment(\.appTheme) private var theme
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var profileService: UnifiedProfileService
    @Bindable private var historyStore = FaceScanHistoryStore.shared
    @ObservedObject private var creatorMode = ProcessCreatorModeStore.shared

    @State private var isScanFlowActive = false
    @State private var selectedFilter: ProcessFaceScanHistoryFilter = .all
    @State private var selectedAnalysisScan: FaceScanResult?
    @State private var isComparePresented = false
    @Namespace private var scanCaptureZoomNamespace

    private let accentBlue = Color(red: 0.0, green: 0.478, blue: 1.0)
    private let cardRadius: CGFloat = 22

    private enum HeroLayout {
        /// Même silhouette que le scan onboarding (`FaceScanOnboardingOvalShape`).
        static let ovalWidth: CGFloat = 212
        static var ovalHeight: CGFloat {
            ovalWidth * FaceScanViewportMetrics.onboardingOvalAspect
        }
    }

    private var isRuntimeActive: Bool {
        isTabActive && scenePhase == .active
    }

    private var livePreviewActive: Bool {
        isRuntimeActive && !isScanFlowActive
    }

    private var filteredHistory: [FaceScanResult] {
        selectedFilter.filtered(from: historyStore.history)
    }

    private var groupedHistory: [(title: String, scans: [FaceScanResult])] {
        ProcessFaceScanHistoryGrouping.monthSections(from: filteredHistory)
    }

    private var consistencyPair: (newest: FaceScanResult, previous: FaceScanResult)? {
        guard historyStore.history.count >= 2 else { return nil }
        return (historyStore.history[0], historyStore.history[1])
    }

    var body: some View {
        NavigationStack {
            processMainScrollableChrome(
                selectedSection: $selectedSection,
                pageSection: .scan,
                adoptsFloatingTabBar: !isOnboardingPreview
            ) {
                VStack(spacing: 28) {
                    heroSection
                    previousScansSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, ProcessIGTabMetrics.tabBarOverlayClearance + 16)
            }
            .navigationBarHidden(true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .processClearUIKitHostingBackground()
        .fullScreenCover(isPresented: $isScanFlowActive) {
            FaceScanSessionView(
                onDismiss: { isScanFlowActive = false },
                onComplete: { _ in isScanFlowActive = false },
                showsMediaImport: creatorMode.allowsPhotoImport
            )
            .environmentObject(profileService)
            .processZoomTransition(id: .faceScanCapture, namespace: scanCaptureZoomNamespace)
        }
        .fullScreenCover(item: $selectedAnalysisScan) { scan in
            FaceScanResultContent(
                result: scan,
                previous: previousScan(before: scan),
                history: historyStore.history
            )
        }
        .onAppear {
            historyStore.reloadForUser(userId: profileService.currentProfile?.userId)
        }
        .sheet(isPresented: $isComparePresented) {
            ProcessFaceScanCompareSheet(
                initials: profileInitials,
                isPlaybackActive: isRuntimeActive
            )
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 0) {
            if !isOnboardingPreview {
                HStack(spacing: 10) {
                    // TEMP — retour rapide vers l’accueil depuis l’onglet Scan.
                    Button {
                        HapticManager.shared.impact(.light)
                        withAnimation(ProcessZoomTransitionID.presentationSpring) {
                            selectedSection = .plan
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(theme.primaryText)
                            .frame(width: 40, height: 40)
                            .contentShape(Circle())
                    }
                    .processGlassButton(in: Circle())
                    .accessibilityLabel(AppCopy.t("Retour", en: "Back"))

                    Spacer(minLength: 0)
                }
                .padding(.bottom, 10)
            }

            VStack(spacing: 8) {
                Text(AppCopy.t("Fais le scan du jour", en: "Take today's scan"))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(theme.primaryText)
                    .multilineTextAlignment(.center)

                Text(AppCopy.t(
                    "12 métriques · structure & peau · ~30 s · reste sur l’appareil",
                    en: "12 metrics · structure & skin · ~30 sec · stays on device"
                ))
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(theme.secondaryText)
                .multilineTextAlignment(.center)

                if !historyStore.canStartTodayScan, historyStore.latestResult != nil {
                    Text(AppCopy.t(
                        "Scan du jour déjà enregistré — historique ci-dessous.",
                        en: "Today's scan is already saved — history below."
                    ))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.green.opacity(0.92))
                    .multilineTextAlignment(.center)
                }
            }
            .padding(.top, 4)

            Spacer(minLength: 18)
                .frame(height: 22)

            ProcessFaceScanOvalCameraPreview(isActive: livePreviewActive)
                .frame(width: HeroLayout.ovalWidth, height: HeroLayout.ovalHeight)
                .processZoomSource(id: .faceScanCapture, namespace: scanCaptureZoomNamespace)

            Spacer(minLength: 18)
                .frame(height: 24)

            Button(action: startScan) {
                Label(
                    historyStore.canStartTodayScan || historyStore.latestResult == nil
                        ? AppCopy.t("Lancer le scan", en: "Start scan")
                        : AppCopy.t("Scan déjà fait", en: "Scan already done"),
                    systemImage: "viewfinder"
                )
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background {
                    Capsule(style: .continuous)
                        .fill(historyStore.canStartTodayScan || historyStore.latestResult == nil ? accentBlue : theme.secondaryText.opacity(0.45))
                        .shadow(
                            color: accentBlue.opacity(historyStore.canStartTodayScan || historyStore.latestResult == nil ? 0.28 : 0),
                            radius: 14,
                            y: 8
                        )
                }
            }
            .buttonStyle(.plain)
            .disabled(!historyStore.canStartTodayScan && historyStore.latestResult != nil)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - History

    private var previousScansSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(AppCopy.t("Scans précédents", en: "Previous scans"))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(theme.primaryText)

                Spacer(minLength: 12)

                Button(action: { isComparePresented = true }) {
                    Text(AppCopy.t("Comparer", en: "Compare"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(accentBlue)
                }
                .buttonStyle(.plain)
                .disabled(historyStore.history.count < 2)
                .opacity(historyStore.history.count < 2 ? 0.45 : 1)
            }

            filterChips

            if let pair = consistencyPair, selectedFilter.showsConsistencyCard {
                ProcessFaceScanConsistencyCard(
                    newest: pair.newest,
                    previous: pair.previous,
                    filter: selectedFilter
                )
            }

            if filteredHistory.isEmpty {
                emptyHistoryState
            } else {
                ForEach(groupedHistory, id: \.title) { section in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(section.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(theme.secondaryText.opacity(0.82))
                            .textCase(.uppercase)

                        ForEach(section.scans) { scan in
                            ProcessFaceScanHistoryRow(
                                scan: scan,
                                deltaVsPrevious: deltaVsPrevious(for: scan),
                                onTap: { selectedAnalysisScan = scan }
                            )
                        }
                    }
                }
            }
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ProcessFaceScanHistoryFilter.allCases) { filter in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selectedFilter = filter
                        }
                    } label: {
                        Text(filter.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(selectedFilter == filter ? Color.white : theme.primaryText)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background {
                                Capsule(style: .continuous)
                                    .fill(selectedFilter == filter ? theme.primaryText : theme.cardBackground)
                                    .overlay {
                                        if selectedFilter != filter {
                                            Capsule(style: .continuous)
                                                .strokeBorder(theme.cardStroke.opacity(0.75), lineWidth: 0.75)
                                        }
                                    }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var emptyHistoryState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppCopy.t("Aucun scan pour ce filtre", en: "No scans for this filter"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.primaryText)

            Text(AppCopy.t(
                "Lance ton premier scan pour voir l’historique ici.",
                en: "Take your first scan to see history here."
            ))
            .font(.system(size: 14))
            .foregroundStyle(theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(cardBackground)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
            .fill(theme.cardBackground)
            .overlay {
                RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                    .strokeBorder(theme.cardStroke.opacity(0.55), lineWidth: 0.75)
            }
    }

    private var profileInitials: String {
        let name = profileService.currentProfile?.firstName
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard let first = name.first else { return "?" }
        return String(first).uppercased()
    }

    private func startScan() {
        guard historyStore.canStartTodayScan || historyStore.latestResult == nil else { return }
        HapticManager.shared.impact(.medium)
        withAnimation(ProcessZoomTransitionID.presentationSpring) {
            isScanFlowActive = true
        }
    }

    private func previousScan(before scan: FaceScanResult) -> FaceScanResult? {
        let ordered = historyStore.history.sorted { $0.createdAt > $1.createdAt }
        guard let index = ordered.firstIndex(where: { $0.id == scan.id }), index + 1 < ordered.count else {
            return nil
        }
        return ordered[index + 1]
    }

    private func deltaVsPrevious(for scan: FaceScanResult) -> Int? {
        guard let previous = previousScan(before: scan) else { return nil }
        return scan.displayWellnessScore - previous.displayWellnessScore
    }
}

// MARK: - Filters

enum ProcessFaceScanHistoryFilter: String, CaseIterable, Identifiable {
    case all
    case thisWeek
    case best
    case structure
    case skin

    var id: String { rawValue }

    @MainActor
    var title: String {
        switch self {
        case .all: AppCopy.t("Tous", en: "All")
        case .thisWeek: AppCopy.t("Cette semaine", en: "This week")
        case .best: AppCopy.t("Meilleurs", en: "Best")
        case .structure: AppCopy.t("Structure", en: "Structure")
        case .skin: AppCopy.t("Peau", en: "Skin")
        }
    }

    var showsConsistencyCard: Bool {
        self != .best
    }

    func filtered(from history: [FaceScanResult]) -> [FaceScanResult] {
        switch self {
        case .all:
            return history
        case .thisWeek:
            let calendar = Calendar.current
            let start = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            return history.filter { $0.createdAt >= start }
        case .best:
            return history.sorted { $0.displayWellnessScore > $1.displayWellnessScore }
        case .structure, .skin:
            return history
        }
    }
}

// MARK: - Grouping

enum ProcessFaceScanHistoryGrouping {
    static func monthSections(from history: [FaceScanResult]) -> [(title: String, scans: [FaceScanResult])] {
        guard !history.isEmpty else { return [] }

        let formatter = DateFormatter()
        formatter.locale = ProcessAppLanguage.shared.locale
        formatter.dateFormat = "LLLL yyyy"

        var buckets: [String: [FaceScanResult]] = [:]
        var order: [String] = []

        for scan in history {
            let key = formatter.string(from: scan.createdAt).uppercased()
            if buckets[key] == nil {
                order.append(key)
            }
            buckets[key, default: []].append(scan)
        }

        return order.map { title in
            (title: title, scans: buckets[title] ?? [])
        }
    }
}

// MARK: - Consistency metrics

enum ProcessFaceScanConsistencyMetric: CaseIterable, Identifiable {
    case overall
    case redness
    case texture
    case tone
    case pores
    case glow

    var id: String { String(describing: self) }

    @MainActor
    var title: String {
        switch self {
        case .overall: AppCopy.t("GLOBAL", en: "OVERALL")
        case .redness: AppCopy.t("ROUGEUR", en: "REDNESS")
        case .texture: AppCopy.t("TEXTURE", en: "TEXTURE")
        case .tone: AppCopy.t("TEINT", en: "TONE")
        case .pores: AppCopy.t("PORES", en: "PORES")
        case .glow: AppCopy.t("ÉCLAT", en: "GLOW")
        }
    }

    static func metrics(for filter: ProcessFaceScanHistoryFilter) -> [ProcessFaceScanConsistencyMetric] {
        switch filter {
        case .structure:
            return [.overall, .tone, .glow]
        case .skin:
            return [.overall, .redness, .texture, .pores, .glow]
        default:
            return allCases
        }
    }

    func score(for result: FaceScanResult) -> Int {
        switch self {
        case .overall:
            return result.displayWellnessScore
        case .redness:
            return FaceScanIndicators.wellnessPercent(for: .recovery, result: result)
        case .texture:
            return result.markers.skinClarityScore
        case .tone:
            return result.markers.facialSymmetryScore
        case .pores:
            return max(0, 100 - FaceScanIndicators.displayPercent(for: .retention, result: result))
        case .glow:
            return FaceScanIndicators.wellnessPercent(for: .definition, result: result)
        }
    }
}

private struct ProcessFaceScanConsistencyCard: View {
    @Environment(\.appTheme) private var theme

    let newest: FaceScanResult
    let previous: FaceScanResult
    let filter: ProcessFaceScanHistoryFilter

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(AppCopy.t("COHÉRENCE", en: "CONSISTENCY"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.secondaryText.opacity(0.82))

            Text(AppCopy.t(
                "Chaque score sur tes 2 derniers scans — le plus récent en premier. La pastille = l’écart ; plus petit = plus stable.",
                en: "Each score across your last 2 scans — newest first. The chip is the spread; smaller = steadier."
            ))
            .font(.system(size: 13))
            .foregroundStyle(theme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 12) {
                ForEach(ProcessFaceScanConsistencyMetric.metrics(for: filter)) { metric in
                    consistencyRow(metric: metric)
                }
            }
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(theme.cardBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(theme.cardStroke.opacity(0.55), lineWidth: 0.75)
                }
        }
    }

    private func consistencyRow(metric: ProcessFaceScanConsistencyMetric) -> some View {
        let newestScore = metric.score(for: newest)
        let previousScore = metric.score(for: previous)
        let spread = abs(newestScore - previousScore)

        return HStack(spacing: 12) {
            Text(metric.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.secondaryText.opacity(0.88))
                .frame(width: 74, alignment: .leading)

            HStack(spacing: 4) {
                Text("\(newestScore)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(theme.primaryText)
                Text("/")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(theme.secondaryText.opacity(0.55))
                Text("\(previousScore)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.secondaryText)
            }

            Spacer(minLength: 8)

            Text("Δ\(spread)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(spread <= 4 ? Color.green : Color(red: 0.93, green: 0.33, blue: 0.44))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background {
                    Capsule(style: .continuous)
                        .fill(
                            (spread <= 4 ? Color.green : Color(red: 0.93, green: 0.33, blue: 0.44))
                                .opacity(0.14)
                        )
                }
        }
    }
}

// MARK: - History row

private struct ProcessFaceScanHistoryRow: View {
    @Environment(\.appTheme) private var theme

    let scan: FaceScanResult
    let deltaVsPrevious: Int?
    let onTap: () -> Void

    private let accentBlue = Color(red: 0.0, green: 0.478, blue: 1.0)

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                thumbnail

                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(primaryDateLabel)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(theme.primaryText)

                        Text(secondaryTimeLabel)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(theme.secondaryText)
                    }

                    HStack(spacing: 6) {
                        metricTag("SYM", value: scan.markers.facialSymmetryScore)
                        metricTag("JAW", value: scan.markers.jawTensionScore)
                    }

                    skinScorePill
                }

                Spacer(minLength: 0)

                trailingDelta
            }
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(theme.cardBackground)
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(theme.cardStroke.opacity(0.55), lineWidth: 0.75)
                    }
            }
        }
        .buttonStyle(.plain)
    }

    private var thumbnail: some View {
        ZStack(alignment: .bottomLeading) {
            FaceScanRecordingMediaView(
                result: scan,
                height: 64,
                displayMode: .thumbnail,
                isPlaybackActive: false
            )
            .frame(width: 64, height: 64)
            .clipShape(Circle())

            Text("\(scan.displayWellnessScore)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background {
                    Capsule(style: .continuous)
                        .fill(Color.black.opacity(0.82))
                }
                .offset(x: -2, y: 4)
        }
        .frame(width: 64, height: 64)
    }

    private var skinScorePill: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkle")
                .font(.system(size: 10, weight: .bold))
            Text("SKIN \(FaceScanIndicators.wellnessPercent(for: .skin, result: scan))")
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(accentBlue)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background {
            Capsule(style: .continuous)
                .fill(accentBlue.opacity(0.12))
        }
    }

    @ViewBuilder
    private var trailingDelta: some View {
        HStack(spacing: 6) {
            if let deltaVsPrevious, deltaVsPrevious != 0 {
                Text(deltaVsPrevious > 0 ? "+\(deltaVsPrevious)" : "\(deltaVsPrevious)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(deltaVsPrevious > 0 ? Color.green : Color(red: 0.93, green: 0.33, blue: 0.44))
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.secondaryText.opacity(0.55))
        }
    }

    private func metricTag(_ label: String, value: Int) -> some View {
        Text("\(label) \(value)")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(theme.secondaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                Capsule(style: .continuous)
                    .fill(theme.cardBackgroundStrong.opacity(theme.isDark ? 0.55 : 0.92))
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(theme.cardStroke.opacity(0.45), lineWidth: 0.6)
                    }
            }
    }

    private var primaryDateLabel: String {
        let formatter = DateFormatter()
        formatter.locale = ProcessAppLanguage.shared.locale
        formatter.setLocalizedDateFormatFromTemplate("EEEdMMM")
        return formatter.string(from: scan.createdAt)
    }

    private var secondaryTimeLabel: String {
        let timeFormatter = DateFormatter()
        timeFormatter.locale = ProcessAppLanguage.shared.locale
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short

        return "\(timeFormatter.string(from: scan.createdAt)) · \(timeOfDayLabel(for: scan.createdAt))"
    }

    private func timeOfDayLabel(for date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<12:
            return AppCopy.t("matin", en: "morning")
        case 12..<17:
            return AppCopy.t("après-midi", en: "afternoon")
        case 17..<22:
            return AppCopy.t("soir", en: "evening")
        default:
            return AppCopy.t("nuit", en: "night")
        }
    }
}

// MARK: - Compare sheet

private struct ProcessFaceScanCompareSheet: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    let initials: String
    let isPlaybackActive: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(AppCopy.t(
                        "Compare ton premier scan et ta dernière photo — même cadrage, même lumière si possible.",
                        en: "Compare your first scan and latest photo — same framing and lighting when you can."
                    ))
                    .font(.system(size: 15))
                    .foregroundStyle(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                    ProfileScanEvolutionPair(
                        isPlaybackActive: isPlaybackActive,
                        initials: initials
                    )
                }
                .padding(20)
            }
            .navigationTitle(AppCopy.t("Comparer", en: "Compare"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(AppCopy.close) { dismiss() }
                }
            }
        }
    }
}

// MARK: - Oval camera preview

private struct ProcessFaceScanOvalCameraPreview: View {
    var isActive: Bool

    @Environment(\.appTheme) private var theme
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var camera = BodyScanCameraService()

    private var cameraLifecycleKey: String {
        "\(isActive)-\(scenePhase == .active)"
    }

    var body: some View {
        ZStack {
            cameraLayer
                .mask {
                    FaceScanOnboardingOvalShape()
                }

            FaceScanOnboardingOvalShape()
                .stroke(theme.cardStroke.opacity(0.18), lineWidth: 0.75)

            if isActive {
                FaceScanOnboardingInnerEdgeGlow(intensity: theme.isDark ? 0.62 : 0.54)
            }
        }
        .compositingGroup()
        .shadow(color: Color.black.opacity(theme.isDark ? 0.35 : 0.10), radius: 18, y: 10)
        .task(id: cameraLifecycleKey) {
            guard isActive, scenePhase == .active else {
                camera.stop()
                return
            }
            await startCameraIfNeeded()
        }
        .onDisappear {
            camera.stop()
        }
        .accessibilityLabel(AppCopy.t("Aperçu caméra frontale", en: "Front camera preview"))
    }

    @ViewBuilder
    private var cameraLayer: some View {
        switch camera.authorizationStatus {
        case .authorized:
            BodyScanCameraPreview(
                session: camera.session,
                mirrorFrontCamera: true,
                isSessionRunning: camera.isRunning
            )
            .background(Color.black)
        case .denied, .restricted:
            placeholder(systemImage: "camera.fill", message: AppCopy.t("Caméra refusée", en: "Camera denied"))
        default:
            placeholder(systemImage: "camera.fill", message: nil)
        }
    }

    private func placeholder(systemImage: String, message: String?) -> some View {
        ZStack {
            Color(red: 0.09, green: 0.09, blue: 0.10)
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.orange.opacity(0.9))
                if let message {
                    Text(message)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(theme.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
            }
        }
    }

    @MainActor
    private func startCameraIfNeeded() async {
        camera.refreshAuthorizationStatus()
        if camera.authorizationStatus == .notDetermined {
            guard await camera.requestAccess() else { return }
        }
        guard camera.authorizationStatus == .authorized else { return }
        await camera.restartPreviewIfNeeded(preferredPosition: .front)
    }
}
