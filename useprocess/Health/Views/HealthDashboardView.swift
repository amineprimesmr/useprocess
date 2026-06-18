import SwiftUI

struct HealthDashboardView: View {
    @Binding var selectedSection: ProcessMainSection
    var onOpenProfile: () -> Void

    @EnvironmentObject private var healthManager: HealthManager
    @EnvironmentObject private var dataManager: DailyDataManager
    @EnvironmentObject private var profileService: UnifiedProfileService
    @Environment(\.appTheme) private var theme

    @State private var planStore = WelcomePlanStore.shared
    @State private var hubTab: HealthHubTab = .today
    @State private var programSection: OriginPlanProgramSection = .week

    @State private var claudeDailyBrief: CoachDailyBriefContent?
    @State private var isLoadingBrief = false
    @State private var readinessExplanation: String?
    @State private var isExplainingReadiness = false
    @State private var showReadinessSheet = false

    @State private var showFaceScan = false
    @State private var showFaceHistory = false
    @State private var selectedFaceScan: FaceScanResult?
    @State private var faceHistoryStore = FaceScanHistoryStore.shared

    private var livePlan: FaceOriginPlan? { planStore.plan }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Hub", selection: $hubTab) {
                    ForEach(HealthHubTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 4)
                .padding(.bottom, 10)

                processMainScrollableChrome(
                    selectedSection: $selectedSection,
                    pageSection: .health
                ) {
                    VStack(spacing: 18) {
                        if let plan = livePlan {
                            OriginPlanHeaderCard(plan: plan)
                        }

                        switch hubTab {
                        case .today:
                            todayTab
                        case .tracking:
                            trackingTab
                        case .program:
                            programTab
                        }
                    }
                    .padding()
                }
            }
            .background(theme.background.ignoresSafeArea())
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await refreshAll(forceBrief: true) }
            .task { await refreshAll(forceBrief: false) }
            .sheet(isPresented: $showReadinessSheet) { readinessSheet }
            .fullScreenCover(isPresented: $showFaceScan) { faceScanCover }
            .sheet(isPresented: $showFaceHistory) {
                FaceScanHistoryView(history: faceHistoryStore.history) { scan in
                    showFaceHistory = false
                    selectedFaceScan = scan
                }
            }
            .sheet(item: $selectedFaceScan) { scan in
                FaceScanDetailView(
                    result: scan,
                    previous: faceHistoryStore.history.first(where: { $0.id != scan.id && $0.createdAt < scan.createdAt })
                )
            }
            .onAppear {
                planStore.reloadForCurrentUser()
                faceHistoryStore = FaceScanHistoryStore.shared
            }
        }
    }

    // MARK: - Aujourd'hui

    @ViewBuilder
    private var todayTab: some View {
        readinessCompact
        HealthTodayMetricsStrip(onOpenTracking: { hubTab = .tracking })
        briefCard

        if let plan = livePlan {
            OriginPlanProgramContent(section: .constant(.today), plan: plan)
        } else {
            noPlanCard
        }

        FaceScanHealthCompact(
            latest: faceHistoryStore.latestResult,
            faceDayScore: healthManager.faceDayScore,
            isScanDue: faceHistoryStore.isScanDue,
            daysUntilNextScan: faceHistoryStore.daysUntilNextScan,
            onScan: { showFaceScan = true },
            onHistory: { showFaceHistory = true }
        )

        if !healthManager.faceCorrelations.isEmpty {
            correlationsBlock
        }
    }

    private var readinessCompact: some View {
        HStack(spacing: 16) {
            readinessMiniRing(score: healthManager.readinessScore, title: "Ready")

            VStack(alignment: .leading, spacing: 6) {
                Text(healthManager.readinessLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.primaryText)

                if let factor = healthManager.readinessFactors.first {
                    Text(factor)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(2)
                }

                if ClaudeConfiguration.isConfigured {
                    Button {
                        Task { await explainReadiness() }
                    } label: {
                        Text(isExplainingReadiness ? "…" : "Détails")
                            .font(.caption.weight(.semibold))
                    }
                    .disabled(isExplainingReadiness)
                }
            }

            if let face = healthManager.faceDayScore {
                readinessMiniRing(score: face, title: "Visage")
            }
        }
        .padding(14)
        .background(HealthHubDesign.surfaceCard(theme: theme))
    }

    private func readinessMiniRing(score: Int, title: String) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(theme.progressTrack, lineWidth: 5)
                    .frame(width: 52, height: 52)
                Circle()
                    .trim(from: 0, to: CGFloat(max(score, 0)) / 100)
                    .stroke(readinessColor(for: score), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 52, height: 52)
                    .rotationEffect(.degrees(-90))
                Text("\(score)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(theme.secondaryText)
        }
    }

    @ViewBuilder
    private var briefCard: some View {
        if ClaudeConfiguration.isConfigured {
            VStack(alignment: .leading, spacing: 8) {
                Label("Brief du jour", systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.primaryText)

                if isLoadingBrief {
                    ProgressView().tint(theme.primaryText)
                } else if let brief = claudeDailyBrief, brief.isValid {
                    CoachDailyBriefCard(content: brief, theme: theme)
                } else {
                    Text("Tire pour rafraîchir.")
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HealthHubDesign.surfaceCard(theme: theme))
        }
    }

    private var noPlanCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Protocole Origine")
                .font(.headline)
            Text("Termine la configuration avec le coach pour débloquer ton programme.")
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HealthHubDesign.surfaceCard(theme: theme))
    }

    private var correlationsBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tendances scan")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.secondaryText)
            ForEach(healthManager.faceCorrelations.prefix(2)) { insight in
                Text("• \(OriginPlanPresenter.truncate(insight.message, max: 100))")
                    .font(.caption)
                    .foregroundStyle(theme.primaryText)
            }
        }
        .padding(14)
        .background(HealthHubDesign.surfaceCard(theme: theme))
    }

    // MARK: - Suivi

    private var trackingTab: some View {
        HealthTrackingPanel {
            Task { await healthManager.requestAuthorizationAsync() }
        }
    }

    // MARK: - Programme

    @ViewBuilder
    private var programTab: some View {
        if let plan = livePlan {
            Picker("Programme", selection: $programSection) {
                Text("Semaine").tag(OriginPlanProgramSection.week)
                Text("Piliers").tag(OriginPlanProgramSection.pillars)
            }
            .pickerStyle(.segmented)

            OriginPlanProgramContent(section: $programSection, plan: plan)
        } else {
            noPlanCard
        }
    }

    // MARK: - Sheets

    private var readinessSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(readinessExplanation ?? "Analyse indisponible.")
                        .font(.body)
                        .foregroundStyle(theme.primaryText)
                    HealthMedicalSourcesView(style: .compact)
                }
                .padding()
            }
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Readiness")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { showReadinessSheet = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var faceScanCover: some View {
        FaceScanSessionView(
            onDismiss: { showFaceScan = false },
            onComplete: { _ in
                faceHistoryStore = FaceScanHistoryStore.shared
                showFaceScan = false
                Task { await healthManager.performFullSync() }
            }
        )
        .environmentObject(profileService)
    }

    // MARK: - Data

    private func refreshAll(forceBrief: Bool) async {
        planStore.reloadForCurrentUser()
        if healthManager.isHealthDataAvailable && !healthManager.isAuthorized {
            await healthManager.requestAuthorizationAsync()
        } else if healthManager.isAuthorized {
            await healthManager.performFullSync()
            await dataManager.updateCurrentDayData(with: healthManager)
        }
        await loadClaudeBrief(forceRefresh: forceBrief)
    }

    private func loadClaudeBrief(forceRefresh: Bool) async {
        guard ClaudeConfiguration.isConfigured else { return }
        isLoadingBrief = true
        defer { isLoadingBrief = false }
        claudeDailyBrief = await CoachEngine.generateDailyBrief(
            profile: profileService.currentProfile,
            forceRefresh: forceRefresh
        )
    }

    private func explainReadiness() async {
        isExplainingReadiness = true
        defer { isExplainingReadiness = false }
        readinessExplanation = await CoachEngine.explainReadiness(profile: profileService.currentProfile)
        showReadinessSheet = readinessExplanation != nil
    }

    private func readinessColor(for score: Int) -> Color {
        switch score {
        case 80...: return .green
        case 60..<80: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }
}

// MARK: - Suivi HealthKit

private struct HealthTrackingPanel: View {
    @EnvironmentObject private var healthManager: HealthManager
    @Environment(\.appTheme) private var theme

    var onRequestConnect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            appleHealthStatusCard
            keyMetricsGrid

            trackingDisclosure("Activité", icon: "figure.run") {
                let e = healthManager.todaySnapshot.effort
                trackingRow("Pas", metricValue(e.steps))
                trackingRow("Calories actives", e.activeEnergyBurned > 0 ? "\(Int(e.activeEnergyBurned)) kcal" : "—")
                trackingRow("Exercice", e.exerciseMinutes > 0 ? "\(Int(e.exerciseMinutes)) min" : "—")
                trackingRow("Effort Process", e.effortScore > 0 ? "\(Int(e.effortScore)) %" : "—")
                trackingRow("Distance", formatDistance(e.distanceKm))
                trackingRow("Séances", metricValue(e.workoutCount))
                trackingRow("Étages", metricValue(e.flightsClimbed))
                trackingRow("Heures debout", metricValue(healthManager.todaySnapshot.activity.standHours))
            }

            trackingDisclosure("Sommeil", icon: "bed.double.fill") {
                let s = healthManager.todaySnapshot.sleep
                trackingRow("Durée", s.sleepDuration > 0 ? String(format: "%.1f h", s.sleepDuration) : "—")
                trackingRow("Profond", s.deepSleepHours > 0 ? String(format: "%.1f h", s.deepSleepHours) : "—")
                trackingRow("REM", s.remSleepHours > 0 ? String(format: "%.1f h", s.remSleepHours) : "—")
                trackingRow("Dette", s.sleepDebt > 0 ? String(format: "%.1f h", s.sleepDebt) : "Aucune")
                if let bed = s.bedtime {
                    trackingRow("Coucher", bed.formatted(date: .omitted, time: .shortened))
                }
                if let wake = s.wakeTime {
                    trackingRow("Réveil", wake.formatted(date: .omitted, time: .shortened))
                }
            }

            trackingDisclosure("Signes vitaux", icon: "heart.fill") {
                let v = healthManager.todaySnapshot.vitals
                let b = healthManager.baselines
                trackingRow("FC moyenne", v.heartRate > 0 ? "\(Int(v.heartRate)) bpm" : "—")
                trackingRow("FC repos", v.restingHeartRate > 0 ? "\(Int(v.restingHeartRate)) bpm" : "—")
                trackingRow("HRV (SDNN)", v.hrv > 0 ? String(format: "%.0f ms", v.hrv) : "—")
                if b.hrv > 0 {
                    trackingRow("HRV baseline", String(format: "%.0f ms", b.hrv))
                }
                if b.restingHeartRate > 0 {
                    trackingRow("FC repos baseline", String(format: "%.0f bpm", b.restingHeartRate))
                }
                trackingRow("SpO2", v.spo2 > 0 ? String(format: "%.0f %%", v.spo2) : "—")
                trackingRow("Fréq. respiratoire", v.respiratoryRate > 0 ? String(format: "%.0f /min", v.respiratoryRate) : "—")
                trackingRow("VO2 max", healthManager.todaySnapshot.activity.vo2Max > 0
                    ? String(format: "%.1f", healthManager.todaySnapshot.activity.vo2Max) : "—")
            }

            trackingDisclosure("Corps", icon: "figure.stand") {
                let v = healthManager.todaySnapshot.vitals
                trackingRow("Poids", v.bodyMass > 0 ? String(format: "%.1f kg", v.bodyMass) : "—")
                trackingRow("Masse grasse", v.bodyFatPercentage > 0 ? String(format: "%.1f %%", v.bodyFatPercentage) : "—")
            }

            trackingDisclosure("Nutrition", icon: "fork.knife") {
                let n = healthManager.todaySnapshot.nutrition
                trackingRow("Calories", n.caloriesConsumed > 0 ? "\(Int(n.caloriesConsumed)) kcal" : "—")
                trackingRow("Protéines", n.proteinGrams > 0 ? "\(Int(n.proteinGrams)) g" : "—")
                trackingRow("Glucides", n.carbsGrams > 0 ? "\(Int(n.carbsGrams)) g" : "—")
                trackingRow("Lipides", n.fatGrams > 0 ? "\(Int(n.fatGrams)) g" : "—")
                trackingRow("Eau", n.waterLiters > 0 ? String(format: "%.1f L", n.waterLiters) : "—")
            }

            if healthManager.baselines.daysOfData > 0 {
                trackingDisclosure("Tes moyennes (14 j)", icon: "chart.line.uptrend.xyaxis") {
                    let b = healthManager.baselines
                    trackingRow("Jours de données", "\(b.daysOfData)")
                    trackingRow("Sommeil cible", b.sleepNeedHours > 0 ? String(format: "%.1f h", b.sleepNeedHours) : "—")
                    trackingRow("Pas / jour", b.avgDailySteps > 0 ? "\(Int(b.avgDailySteps))" : "—")
                    trackingRow("Calories / jour", b.avgActiveCalories > 0 ? "\(Int(b.avgActiveCalories)) kcal" : "—")
                }
            }

            connectedSourcesCard

            HealthMedicalSourcesView(style: .compact)
                .padding(12)
                .background(HealthHubDesign.surfaceCard(theme: theme))

            syncFooter
        }
    }

    private var appleHealthStatusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Apple Santé", systemImage: "heart.text.square.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.primaryText)
                Spacer()
                statusBadge
            }

            if !healthManager.isHealthDataAvailable {
                Text("HealthKit n'est pas disponible sur cet appareil.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if !healthManager.isAuthorized {
                Text("Autorise l'accès à tes données pour alimenter le readiness, le protocole et le coach.")
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
                Button("Connecter Apple Santé", action: onRequestConnect)
                    .buttonStyle(.borderedProminent)
                    .tint(theme.onboardingAccent)
            } else {
                Text("Données synchronisées depuis l'app Santé (iPhone, Apple Watch, apps tierces).")
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)

                HStack(spacing: 12) {
                    if healthManager.hasAppleWatch {
                        Label("Apple Watch", systemImage: "applewatch")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                    if let last = healthManager.lastSyncDate {
                        Label("Sync \(last.formatted(date: .omitted, time: .shortened))", systemImage: "arrow.triangle.2.circlepath")
                            .font(.caption2)
                            .foregroundStyle(theme.secondaryText)
                    }
                }
            }
        }
        .padding(14)
        .background(HealthHubDesign.surfaceCard(theme: theme))
    }

    @ViewBuilder
    private var statusBadge: some View {
        if !healthManager.isHealthDataAvailable {
            badge("Indisponible", color: .orange)
        } else if healthManager.isAuthorized {
            badge("Connecté", color: .green)
        } else {
            badge("Non connecté", color: .orange)
        }
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    private var keyMetricsGrid: some View {
        let s = healthManager.todaySnapshot
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            metricChip("Pas", value: metricValue(s.effort.steps), icon: "figure.walk")
            metricChip("Sommeil", value: formatSleep(s.sleep.sleepDuration), icon: "bed.double.fill")
            metricChip("HRV", value: s.vitals.hrv > 0 ? String(format: "%.0f", s.vitals.hrv) : "—", icon: "waveform.path.ecg")
            metricChip("Calories", value: s.effort.activeEnergyBurned > 0 ? "\(Int(s.effort.activeEnergyBurned))" : "—", icon: "flame.fill")
            metricChip("Exercice", value: s.effort.exerciseMinutes > 0 ? "\(Int(s.effort.exerciseMinutes))m" : "—", icon: "figure.run")
            metricChip("Effort", value: s.effort.effortScore > 0 ? "\(Int(s.effort.effortScore))%" : "—", icon: "bolt.fill")
        }
    }

    private func metricChip(_ title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(theme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(title)
                .font(.caption2)
                .foregroundStyle(theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(HealthHubDesign.surfaceCard(theme: theme))
    }

    private var connectedSourcesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HealthHubDesign.sectionHeader(
                "Sources connectées",
                subtitle: "Apps et appareils qui alimentent Santé",
                theme: theme
            )

            if healthManager.connectedSources.isEmpty {
                Text(healthManager.isAuthorized
                    ? "Aucune source détectée pour aujourd'hui."
                    : "Connecte Apple Santé pour voir tes sources.")
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
            } else {
                ForEach(healthManager.connectedSources.prefix(10), id: \.self) { source in
                    HStack(spacing: 10) {
                        Image(systemName: sourceIcon(for: source))
                            .foregroundStyle(theme.secondaryText)
                            .frame(width: 20)
                        Text(source)
                            .font(.caption)
                            .foregroundStyle(theme.primaryText)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(14)
        .background(HealthHubDesign.surfaceCard(theme: theme))
    }

    private func sourceIcon(for name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("watch") { return "applewatch" }
        if lower.contains("iphone") || lower.contains("phone") { return "iphone" }
        return "app.badge"
    }

    private func trackingDisclosure(
        _ title: String,
        icon: String,
        @ViewBuilder content: @escaping () -> some View
    ) -> some View {
        DisclosureGroup {
            VStack(spacing: 8) { content() }
                .padding(.top, 6)
        } label: {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
        }
        .padding(14)
        .background(HealthHubDesign.surfaceCard(theme: theme))
    }

    private func trackingRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(theme.secondaryText)
            Spacer()
            Text(value).font(.caption.weight(.medium)).foregroundStyle(theme.primaryText)
        }
    }

    private var syncFooter: some View {
        VStack(spacing: 6) {
            if healthManager.syncInProgress {
                ProgressView().tint(theme.primaryText)
            }
            Text("Tire vers le bas pour resynchroniser Apple Santé.")
                .font(.caption2)
                .foregroundStyle(theme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func metricValue(_ value: Int) -> String {
        value > 0 ? "\(value)" : "—"
    }

    private func formatSleep(_ hours: Double) -> String {
        hours > 0 ? String(format: "%.1f h", hours) : "—"
    }

    private func formatDistance(_ km: Double) -> String {
        km > 0 ? String(format: "%.1f km", km) : "—"
    }
}

private struct HealthTodayMetricsStrip: View {
    @EnvironmentObject private var healthManager: HealthManager
    @Environment(\.appTheme) private var theme

    var onOpenTracking: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HealthHubDesign.sectionHeader("Apple Santé", subtitle: healthSubtitle, theme: theme)
                Spacer()
                Button("Tout voir", action: onOpenTracking)
                    .font(.caption.weight(.semibold))
            }

            HStack(spacing: 8) {
                miniStat("Pas", value: stat(healthManager.todaySnapshot.effort.steps))
                miniStat("Sommeil", value: sleepStat)
                miniStat("HRV", value: hrvStat)
                miniStat("Kcal", value: kcalStat)
            }
        }
        .padding(14)
        .background(HealthHubDesign.surfaceCard(theme: theme))
    }

    private var healthSubtitle: String {
        if !healthManager.isAuthorized { return "Non connecté" }
        if healthManager.hasAppleWatch { return "iPhone + Watch" }
        return "Synchronisé"
    }

    private func miniStat(_ label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(theme.primaryText)
            Text(label)
                .font(.caption2)
                .foregroundStyle(theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(theme.coachUserBubble.opacity(0.35), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func stat(_ v: Int) -> String { v > 0 ? "\(v)" : "—" }

    private var sleepStat: String {
        let h = healthManager.todaySnapshot.sleep.sleepDuration
        return h > 0 ? String(format: "%.1fh", h) : "—"
    }

    private var hrvStat: String {
        let h = healthManager.todaySnapshot.vitals.hrv
        return h > 0 ? String(format: "%.0f", h) : "—"
    }

    private var kcalStat: String {
        let c = healthManager.todaySnapshot.effort.activeEnergyBurned
        return c > 0 ? "\(Int(c))" : "—"
    }
}
