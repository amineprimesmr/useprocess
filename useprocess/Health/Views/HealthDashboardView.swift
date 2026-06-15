import SwiftUI

struct HealthDashboardView: View {
    @EnvironmentObject private var healthManager: HealthManager
    @EnvironmentObject private var dataManager: DailyDataManager
    @Environment(\.appTheme) private var theme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    readinessCard
                    metricsGrid
                    sleepSection
                    vitalsSection
                    nutritionSection
                    sourcesSection
                    syncSection
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Santé")
            .refreshable {
                await healthManager.performFullSync()
                await dataManager.updateCurrentDayData(with: healthManager)
            }
            .task {
                if healthManager.isHealthDataAvailable && !healthManager.isAuthorized {
                    await healthManager.requestAuthorizationAsync()
                } else if healthManager.isAuthorized {
                    await healthManager.performFullSync()
                    await dataManager.updateCurrentDayData(with: healthManager)
                }
            }
        }
    }

    // MARK: - Readiness

    private var readinessCard: some View {
        VStack(spacing: 12) {
            Text("Readiness")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.6))

            ZStack {
                Circle()
                    .stroke(.white.opacity(0.15), lineWidth: 10)
                    .frame(width: 140, height: 140)
                Circle()
                    .trim(from: 0, to: CGFloat(healthManager.readinessScore) / 100)
                    .stroke(readinessColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text("\(healthManager.readinessScore)")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("/ 100")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            Text(healthManager.readinessLabel)
                .font(.headline)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(cardBackground)
    }

    private var readinessColor: Color {
        switch healthManager.readinessScore {
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
                .foregroundStyle(.white.opacity(0.7))
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(.white)
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))
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
                    .foregroundStyle(.white.opacity(0.6))
            } else {
                ForEach(healthManager.connectedSources.prefix(8), id: \.self) { source in
                    HStack {
                        Image(systemName: source.localizedCaseInsensitiveContains("watch") ? "applewatch" : "iphone")
                            .foregroundStyle(.white.opacity(0.6))
                        Text(source)
                            .font(.subheadline)
                            .foregroundStyle(.white)
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
                    .foregroundStyle(.white.opacity(0.45))
            }

            if healthManager.syncInProgress {
                ProgressView().tint(.white)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - Components

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.white.opacity(0.08))
    }

    private func sectionCard(_ title: String, icon: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(.white)
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
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
        }
    }
}
