import SwiftUI

struct HealthDashboardView: View {
    @Binding var selectedSection: ProcessMainSection
    var onOpenProfile: () -> Void

    @EnvironmentObject private var healthManager: HealthManager
    @EnvironmentObject private var dataManager: DailyDataManager
    @EnvironmentObject private var profileService: UnifiedProfileService
    @Environment(\.appTheme) private var theme

    @State private var claudeDailyBrief: CoachDailyBriefContent?
    @State private var isLoadingBrief = false
    @State private var readinessExplanation: String?
    @State private var isExplainingReadiness = false
    @State private var showReadinessSheet = false
    @State private var showFaceScan = false
    @State private var showFaceHistory = false
    @State private var selectedFaceScan: FaceScanResult?
    @State private var faceHistoryStore = FaceScanHistoryStore.shared

    var body: some View {
        NavigationStack {
            processMainScrollableChrome(
                selectedSection: $selectedSection,
                pageSection: .health
            ) {
                VStack(spacing: 20) {
                    readinessCard
                    WelcomePlanHealthSection()
                    faceScanSection
                    claudeBriefCard
                    metricsGrid
                    sleepSection
                    vitalsSection
                    nutritionSection
                    sourcesSection
                    syncSection
                }
                .padding()
            }
            .background(theme.background.ignoresSafeArea())
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar(.hidden, for: .navigationBar)
            .refreshable {
                await healthManager.performFullSync()
                await dataManager.updateCurrentDayData(with: healthManager)
                await loadClaudeBrief(forceRefresh: true)
            }
            .task {
                if healthManager.isHealthDataAvailable && !healthManager.isAuthorized {
                    await healthManager.requestAuthorizationAsync()
                } else if healthManager.isAuthorized {
                    await healthManager.performFullSync()
                    await dataManager.updateCurrentDayData(with: healthManager)
                }
                await loadClaudeBrief()
            }
            .sheet(isPresented: $showReadinessSheet) {
                NavigationStack {
                    ScrollView {
                        Text(readinessExplanation ?? "Analyse indisponible.")
                            .font(.body)
                            .foregroundStyle(theme.primaryText)
                            .padding()
                    }
                    .background(theme.background.ignoresSafeArea())
                    .navigationTitle("Readiness — Claude")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Fermer") { showReadinessSheet = false }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
            .fullScreenCover(isPresented: $showFaceScan) {
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
                faceHistoryStore = FaceScanHistoryStore.shared
            }
        }
    }

    private var faceScanSection: some View {
        FaceScanHealthSection(
            latest: faceHistoryStore.latestResult,
            previous: faceHistoryStore.previousResult,
            history: faceHistoryStore.history,
            streakDays: faceHistoryStore.streakDays,
            daysSinceLastScan: faceHistoryStore.daysSinceLastScan,
            daysUntilNextScan: faceHistoryStore.daysUntilNextScan,
            isScanDue: faceHistoryStore.isScanDue,
            faceDayScore: healthManager.faceDayScore,
            correlations: healthManager.faceCorrelations,
            onScan: { showFaceScan = true },
            onHistory: { showFaceHistory = true }
        )
    }

    private func loadClaudeBrief(forceRefresh: Bool = false) async {
        guard ClaudeConfiguration.isConfigured else { return }
        isLoadingBrief = true
        defer { isLoadingBrief = false }
        claudeDailyBrief = await CoachEngine.generateDailyBrief(
            profile: profileService.currentProfile,
            forceRefresh: forceRefresh
        )
    }

    private var claudeBriefCard: some View {
        Group {
            if ClaudeConfiguration.isConfigured {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Brief Claude du jour", systemImage: "sparkles")
                        .font(.headline)
                        .foregroundStyle(theme.primaryText)

                    if isLoadingBrief {
                        HStack(spacing: 8) {
                            ProgressView().tint(theme.primaryText)
                            Text("Analyse de tes données…")
                                .font(.caption)
                                .foregroundStyle(theme.secondaryText)
                        }
                    } else if let brief = claudeDailyBrief, brief.isValid {
                        CoachDailyBriefCard(content: brief, theme: theme)
                    } else {
                        Text("Brief indisponible — tire pour rafraîchir.")
                            .font(.caption)
                            .foregroundStyle(theme.secondaryText)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(cardBackground)
            }
        }
    }

    // MARK: - Readiness

    private var readinessCard: some View {
        VStack(spacing: 12) {
            Text("Readiness")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.secondaryText)

            HStack(spacing: 20) {
                readinessRing(
                    score: healthManager.readinessScore,
                    title: "Global",
                    size: 140,
                    fontSize: 42
                )

                if let faceScore = healthManager.faceDayScore {
                    readinessRing(
                        score: faceScore,
                        title: "Visage",
                        size: 88,
                        fontSize: 28
                    )
                }
            }

            Text(healthManager.readinessLabel)
                .font(.headline)
                .foregroundStyle(theme.primaryText)

            if let faceLabel = healthManager.faceDayLabel {
                Text(faceLabel)
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
            }

            if !healthManager.readinessFactors.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(healthManager.readinessFactors.prefix(3), id: \.self) { factor in
                        Text("• \(factor)")
                            .font(.caption)
                            .foregroundStyle(theme.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 8)
            }

            if ClaudeConfiguration.isConfigured {
                Button {
                    Task { await explainReadiness() }
                } label: {
                    Label(
                        isExplainingReadiness ? "Analyse…" : "Expliquer avec Claude",
                        systemImage: "sparkles"
                    )
                    .font(.caption.weight(.semibold))
                }
                .disabled(isExplainingReadiness)
                .buttonStyle(.bordered)
                .tint(theme.primaryText)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(cardBackground)
    }

    private func readinessRing(score: Int, title: String, size: CGFloat, fontSize: CGFloat) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(theme.progressTrack, lineWidth: size > 100 ? 10 : 7)
                    .frame(width: size, height: size)
                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100)
                    .stroke(readinessColor(for: score), style: StrokeStyle(lineWidth: size > 100 ? 10 : 7, lineCap: .round))
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(-90))
                Text("\(score)")
                    .font(.system(size: fontSize, weight: .black, design: .rounded))
                    .foregroundStyle(theme.primaryText)
            }
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(theme.secondaryText)
        }
    }

    private func explainReadiness() async {
        isExplainingReadiness = true
        defer { isExplainingReadiness = false }
        readinessExplanation = await CoachEngine.explainReadiness(profile: profileService.currentProfile)
        showReadinessSheet = readinessExplanation != nil
    }

    private var readinessColor: Color {
        readinessColor(for: healthManager.readinessScore)
    }

    private func readinessColor(for score: Int) -> Color {
        switch score {
        case 80...: return .green
        case 60..<80: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }

    // MARK: - Activity grid

    private var metricsGrid: some View {
        let s = healthManager.todaySnapshot
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            metricTile("Pas", value: "\(s.effort.steps)", icon: "figure.walk")
            metricTile("Calories", value: "\(Int(s.effort.activeEnergyBurned))", icon: "flame.fill")
            metricTile("Exercice", value: "\(Int(s.effort.exerciseMinutes)) min", icon: "figure.run")
            metricTile("Effort", value: "\(Int(s.effort.effortScore))%", icon: "bolt.fill")
            metricTile("Distance", value: String(format: "%.1f km", s.effort.distanceKm), icon: "map")
            metricTile("Workouts", value: "\(s.effort.workoutCount)", icon: "dumbbell.fill")
        }
    }

    private func metricTile(_ title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(theme.secondaryText)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(theme.primaryText)
            Text(title)
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(cardBackground)
    }

    // MARK: - Sections

    private var sleepSection: some View {
        let s = healthManager.todaySnapshot.sleep
        return sectionCard("Sommeil", icon: "bed.double.fill") {
            row("Durée", s.sleepDuration > 0 ? String(format: "%.1f h", s.sleepDuration) : "—")
            row("Profond", s.deepSleepHours > 0 ? String(format: "%.1f h", s.deepSleepHours) : "—")
            row("REM", s.remSleepHours > 0 ? String(format: "%.1f h", s.remSleepHours) : "—")
            row("Dette", s.sleepDebt > 0 ? String(format: "%.1f h", s.sleepDebt) : "Aucune")
        }
    }

    private var vitalsSection: some View {
        let v = healthManager.todaySnapshot.vitals
        let b = healthManager.baselines
        return sectionCard("Signes vitaux", icon: "heart.fill") {
            row("FC moyenne", v.heartRate > 0 ? "\(Int(v.heartRate)) bpm" : "—")
            row("FC repos", v.restingHeartRate > 0 ? "\(Int(v.restingHeartRate)) bpm" : "—")
            row("HRV", v.hrv > 0 ? String(format: "%.0f ms", v.hrv) : "—")
            if b.hrv > 0 {
                row("HRV baseline", String(format: "%.0f ms", b.hrv))
            }
            row("SpO2", v.spo2 > 0 ? String(format: "%.0f%%", v.spo2) : "—")
            row("VO2 max", healthManager.todaySnapshot.activity.vo2Max > 0
                ? String(format: "%.1f", healthManager.todaySnapshot.activity.vo2Max) : "—")
        }
    }

    private var nutritionSection: some View {
        let n = healthManager.todaySnapshot.nutrition
        return sectionCard("Nutrition", icon: "fork.knife") {
            row("Calories", n.caloriesConsumed > 0 ? "\(Int(n.caloriesConsumed)) kcal" : "—")
            row("Protéines", n.proteinGrams > 0 ? "\(Int(n.proteinGrams)) g" : "—")
            row("Glucides", n.carbsGrams > 0 ? "\(Int(n.carbsGrams)) g" : "—")
            row("Eau", n.waterLiters > 0 ? String(format: "%.1f L", n.waterLiters) : "—")
        }
    }

    private var sourcesSection: some View {
        sectionCard("Sources connectées", icon: "link") {
            if healthManager.connectedSources.isEmpty {
                Text("Aucune source détectée — autorise Santé Apple")
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
            } else {
                ForEach(healthManager.connectedSources.prefix(8), id: \.self) { source in
                    HStack {
                        Image(systemName: source.localizedCaseInsensitiveContains("watch") ? "applewatch" : "iphone")
                            .foregroundStyle(theme.secondaryText)
                        Text(source)
                            .font(.subheadline)
                            .foregroundStyle(theme.primaryText)
                    }
                }
            }
            if healthManager.hasAppleWatch {
                Label("Apple Watch détectée", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
    }

    private var syncSection: some View {
        VStack(spacing: 12) {
            if !healthManager.isHealthDataAvailable {
                Text("HealthKit non disponible sur cet appareil")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if !healthManager.isAuthorized {
                Button("Connecter Santé Apple") {
                    Task { await healthManager.requestAuthorizationAsync() }
                }
                .buttonStyle(.borderedProminent)
            }

            if let last = healthManager.lastSyncDate {
                Text("Dernière sync : \(last.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(theme.secondaryText)
            }

            if healthManager.syncInProgress {
                ProgressView().tint(theme.primaryText)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - Components

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(theme.cardBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(theme.cardStroke, lineWidth: theme.isDark ? 0 : 0.5)
            }
    }

    private func sectionCard(_ title: String, icon: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(theme.primaryText)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(cardBackground)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(theme.primaryText)
        }
    }
}
