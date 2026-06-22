import SwiftUI

struct HealthTodayMetricsCard: View {
    @EnvironmentObject private var healthManager: HealthManager
    @EnvironmentObject private var profileService: UnifiedProfileService
    @Environment(\.appTheme) private var theme

    @State private var showDetails = false

    private var snapshot: DailyHealthSnapshot { healthManager.todaySnapshot }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HealthHubDesign.sectionHeader("Aujourd'hui", subtitle: "Apple Santé", theme: theme)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                metricChip("Pas", value: metricValue(snapshot.effort.steps), icon: "figure.walk")
                metricChip("Sommeil", value: formatSleep(snapshot.sleep.sleepDuration), icon: "bed.double.fill")
                metricChip("HRV", value: snapshot.vitals.hrv > 0 ? String(format: "%.0f", snapshot.vitals.hrv) : "—", icon: "waveform.path.ecg")
                metricChip("Calories", value: snapshot.effort.activeEnergyBurned > 0 ? "\(Int(snapshot.effort.activeEnergyBurned))" : "—", icon: "flame.fill")
                metricChip("Exercice", value: snapshot.effort.exerciseMinutes > 0 ? "\(Int(snapshot.effort.exerciseMinutes))m" : "—", icon: "figure.run")
                metricChip("FC repos", value: snapshot.vitals.restingHeartRate > 0 ? "\(Int(snapshot.vitals.restingHeartRate))" : "—", icon: "heart.fill")
            }

            if showDetails {
                VStack(spacing: 8) {
                    detailSection("Activité", icon: "figure.run") {
                        let e = snapshot.effort
                        detailRow("Effort Process", e.effortScore > 0 ? "\(Int(e.effortScore)) %" : "—")
                        detailRow("Distance", formatDistance(e.distanceKm))
                        detailRow("Séances", metricValue(e.workoutCount))
                        detailRow("Étages", metricValue(e.flightsClimbed))
                        detailRow("Heures debout", metricValue(snapshot.activity.standHours))
                    }

                    detailSection("Sommeil", icon: "bed.double.fill") {
                        let s = snapshot.sleep
                        detailRow("Profond", s.deepSleepHours > 0 ? String(format: "%.1f h", s.deepSleepHours) : "—")
                        detailRow("REM", s.remSleepHours > 0 ? String(format: "%.1f h", s.remSleepHours) : "—")
                        detailRow("Dette", s.sleepDebt > 0 ? String(format: "%.1f h", s.sleepDebt) : "Aucune")
                        if let bed = s.bedtime {
                            detailRow("Coucher", bed.formatted(date: .omitted, time: .shortened))
                        }
                        if let wake = s.wakeTime {
                            detailRow("Réveil", wake.formatted(date: .omitted, time: .shortened))
                        }
                    }

                    detailSection("Signes vitaux", icon: "heart.fill") {
                        let v = snapshot.vitals
                        let b = healthManager.baselines
                        detailRow("FC moyenne", v.heartRate > 0 ? "\(Int(v.heartRate)) bpm" : "—")
                        detailRow("SpO2", v.spo2 > 0 ? String(format: "%.0f %%", v.spo2) : "—")
                        detailRow("Fréq. respiratoire", v.respiratoryRate > 0 ? String(format: "%.0f /min", v.respiratoryRate) : "—")
                        detailRow("VO2 max", snapshot.activity.vo2Max > 0 ? String(format: "%.1f", snapshot.activity.vo2Max) : "—")
                        if b.hrv > 0 { detailRow("HRV baseline", String(format: "%.0f ms", b.hrv)) }
                        if b.restingHeartRate > 0 { detailRow("FC repos baseline", String(format: "%.0f bpm", b.restingHeartRate)) }
                    }

                    detailSection("Corps", icon: "figure.stand") {
                        let v = snapshot.vitals
                        let profile = profileService.currentProfile
                        let weightKg = v.bodyMass > 0 ? v.bodyMass : (profile?.weight ?? 0)
                        detailRow("Poids", weightKg > 0 ? String(format: "%.1f kg", weightKg) : "—")
                        if let profile, profile.height > 0 {
                            detailRow("Taille", "\(Int(profile.height)) cm")
                        }
                        detailRow("Masse grasse", v.bodyFatPercentage > 0 ? String(format: "%.1f %%", v.bodyFatPercentage) : "—")
                    }

                    detailSection("Nutrition", icon: "fork.knife") {
                        let n = snapshot.nutrition
                        detailRow("Calories", n.caloriesConsumed > 0 ? "\(Int(n.caloriesConsumed)) kcal" : "—")
                        detailRow("Protéines", n.proteinGrams > 0 ? "\(Int(n.proteinGrams)) g" : "—")
                        detailRow("Glucides", n.carbsGrams > 0 ? "\(Int(n.carbsGrams)) g" : "—")
                        detailRow("Lipides", n.fatGrams > 0 ? "\(Int(n.fatGrams)) g" : "—")
                        detailRow("Eau", n.waterLiters > 0 ? String(format: "%.1f L", n.waterLiters) : "—")
                    }

                    if healthManager.baselines.daysOfData > 0 {
                        detailSection("Moyennes (14 j)", icon: "chart.line.uptrend.xyaxis") {
                            let b = healthManager.baselines
                            detailRow("Jours de données", "\(b.daysOfData)")
                            detailRow("Sommeil cible", b.sleepNeedHours > 0 ? String(format: "%.1f h", b.sleepNeedHours) : "—")
                            detailRow("Pas (14 j)", b.avgDailySteps > 0 ? "\(Int(b.avgDailySteps))" : "—")
                            detailRow("Calories (14 j)", b.avgActiveCalories > 0 ? "\(Int(b.avgActiveCalories)) kcal" : "—")
                        }
                    }
                }
                .padding(.top, 4)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.22)) { showDetails.toggle() }
            } label: {
                Label(showDetails ? "Réduire" : "Plus de détails", systemImage: showDetails ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.secondaryText)
        }
        .padding(14)
        .background(HealthHubDesign.surfaceCard(theme: theme))
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
        .background(theme.coachUserBubble.opacity(0.25), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func detailSection(_ title: String, icon: String, @ViewBuilder rows: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.primaryText)
            rows()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.coachUserBubble.opacity(0.18), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(theme.secondaryText)
            Spacer()
            Text(value).font(.caption.weight(.medium)).foregroundStyle(theme.primaryText)
        }
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
