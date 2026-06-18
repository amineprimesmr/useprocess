import SwiftUI

struct HealthDashboardView: View {
    @Binding var selectedSection: ProcessMainSection
    var onOpenProfile: () -> Void

    @EnvironmentObject private var healthManager: HealthManager
    @EnvironmentObject private var dataManager: DailyDataManager
    @EnvironmentObject private var profileService: UnifiedProfileService
    @Environment(\.appTheme) private var theme

    @State private var planStore = WelcomePlanStore.shared

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
            processMainScrollableChrome(
                selectedSection: $selectedSection,
                pageSection: .health
            ) {
                VStack(spacing: 18) {
                    healthContent
                }
                .padding()
            }
            .background(theme.background.ignoresSafeArea())
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await refreshAll() }
            .task { await refreshAll() }
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

    @ViewBuilder
    private var healthContent: some View {
        if let plan = livePlan {
            OriginPlanHeaderCard(plan: plan)
        }

        ReadinessScoreGaugeView(
            score: healthManager.readinessScore,
            label: healthManager.readinessLabel,
            subtitle: ReadinessGaugeCopy.defaultSubtitle(for: healthManager.readinessScore),
            showsDetails: ClaudeConfiguration.isConfigured,
            isLoadingDetails: isExplainingReadiness,
            onDetails: {
                Task { await explainReadiness() }
            }
        )

        if let face = healthManager.faceDayScore {
            faceDayChip(score: face, label: healthManager.faceDayLabel ?? "Visage")
        }

        if let plan = livePlan {
            programSection(title: "Aujourd'hui", section: .today, plan: plan)
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

        HealthTrackingPanel {
            Task { await healthManager.requestAuthorizationAsync() }
        }

        if let plan = livePlan {
            programSection(title: "Semaine", section: .week, plan: plan)
            programSection(title: "Piliers", section: .pillars, plan: plan)
        }
    }

    private func programSection(
        title: String,
        section: OriginPlanProgramSection,
        plan: FaceOriginPlan
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(theme.primaryText)

            OriginPlanProgramContent(section: .constant(section), plan: plan)
        }
    }

    // MARK: - Sections

    private func faceDayChip(score: Int, label: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "face.smiling")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.secondaryText)
            VStack(alignment: .leading, spacing: 2) {
                Text("Scan visage")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
                Text("\(score)/100 · \(label)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.primaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(HealthHubDesign.surfaceCard(theme: theme))
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

    private func refreshAll() async {
        planStore.reloadForCurrentUser()
        if healthManager.isHealthDataAvailable && !healthManager.isAuthorized {
            await healthManager.requestAuthorizationAsync()
        } else if healthManager.isAuthorized {
            await healthManager.performFullSync()
            await dataManager.updateCurrentDayData(with: healthManager)
        }
    }

    private func explainReadiness() async {
        isExplainingReadiness = true
        defer { isExplainingReadiness = false }
        readinessExplanation = await CoachEngine.explainReadiness(profile: profileService.currentProfile)
        showReadinessSheet = readinessExplanation != nil
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
