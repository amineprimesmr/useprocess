import SwiftUI

struct HealthTodayMetricsCard: View {
    @EnvironmentObject private var healthManager: HealthManager
    @EnvironmentObject private var profileService: UnifiedProfileService
    @Environment(\.appTheme) private var theme

    @State private var showDetails = false

    private var snapshot: DailyHealthSnapshot { healthManager.todaySnapshot }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HealthHubDesign.sectionHeader(
                AppCopy.today,
                subtitle: AppCopy.t("Apple Santé", en: "Apple Health"),
                theme: theme
            )

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                metricChip(AppCopy.t("Pas", en: "Steps"), value: metricValue(snapshot.effort.steps), icon: "figure.walk")
                metricChip(AppCopy.t("Sommeil", en: "Sleep"), value: formatSleep(snapshot.sleep.sleepDuration), icon: "bed.double.fill")
                metricChip("HRV", value: snapshot.vitals.hrv > 0 ? String(format: "%.0f", snapshot.vitals.hrv) : "—", icon: "waveform.path.ecg")
                metricChip(AppCopy.t("Calories", en: "Calories"), value: snapshot.effort.activeEnergyBurned > 0 ? "\(Int(snapshot.effort.activeEnergyBurned))" : "—", icon: "flame.fill")
                metricChip(AppCopy.t("Exercice", en: "Exercise"), value: snapshot.effort.exerciseMinutes > 0 ? "\(Int(snapshot.effort.exerciseMinutes))m" : "—", icon: "figure.run")
                metricChip(AppCopy.t("FC repos", en: "Resting HR"), value: snapshot.vitals.restingHeartRate > 0 ? "\(Int(snapshot.vitals.restingHeartRate))" : "—", icon: "heart.fill")
            }

            if showDetails {
                VStack(spacing: 8) {
                    detailSection(AppCopy.t("Activité", en: "Activity"), icon: "figure.run") {
                        let e = snapshot.effort
                        detailRow(AppCopy.t("Effort Process", en: "Process Effort"), e.effortScore > 0 ? "\(Int(e.effortScore)) %" : "—")
                        detailRow(AppCopy.t("Distance", en: "Distance"), formatDistance(e.distanceKm))
                        detailRow(AppCopy.t("Séances", en: "Workouts"), metricValue(e.workoutCount))
                        detailRow(AppCopy.t("Étages", en: "Flights"), metricValue(e.flightsClimbed))
                        detailRow(AppCopy.t("Heures debout", en: "Stand hours"), metricValue(snapshot.activity.standHours))
                    }

                    detailSection(AppCopy.t("Sommeil", en: "Sleep"), icon: "bed.double.fill") {
                        let s = snapshot.sleep
                        detailRow(AppCopy.t("Profond", en: "Deep"), s.deepSleepHours > 0 ? String(format: "%.1f h", s.deepSleepHours) : "—")
                        detailRow("REM", s.remSleepHours > 0 ? String(format: "%.1f h", s.remSleepHours) : "—")
                        detailRow(
                            AppCopy.t("Dette", en: "Debt"),
                            s.sleepDebt > 0
                                ? String(format: "%.1f h", s.sleepDebt)
                                : AppCopy.t("Aucune", en: "None")
                        )
                        if let bed = s.bedtime {
                            detailRow(AppCopy.t("Coucher", en: "Bedtime"), bed.formatted(date: .omitted, time: .shortened))
                        }
                        if let wake = s.wakeTime {
                            detailRow(AppCopy.t("Réveil", en: "Wake"), wake.formatted(date: .omitted, time: .shortened))
                        }
                    }

                    detailSection(AppCopy.t("Signes vitaux", en: "Vitals"), icon: "heart.fill") {
                        let v = snapshot.vitals
                        let b = healthManager.baselines
                        detailRow(AppCopy.t("FC moyenne", en: "Avg HR"), v.heartRate > 0 ? "\(Int(v.heartRate)) bpm" : "—")
                        detailRow("SpO2", v.spo2 > 0 ? String(format: "%.0f %%", v.spo2) : "—")
                        detailRow(
                            AppCopy.t("Fréq. respiratoire", en: "Resp. rate"),
                            v.respiratoryRate > 0 ? String(format: "%.0f /min", v.respiratoryRate) : "—"
                        )
                        detailRow("VO2 max", snapshot.activity.vo2Max > 0 ? String(format: "%.1f", snapshot.activity.vo2Max) : "—")
                        if b.hrv > 0 { detailRow(AppCopy.t("HRV baseline", en: "HRV baseline"), String(format: "%.0f ms", b.hrv)) }
                        if b.restingHeartRate > 0 {
                            detailRow(
                                AppCopy.t("FC repos baseline", en: "Resting HR baseline"),
                                String(format: "%.0f bpm", b.restingHeartRate)
                            )
                        }
                    }

                    detailSection(AppCopy.t("Corps", en: "Body"), icon: "figure.stand") {
                        let v = snapshot.vitals
                        let profile = profileService.currentProfile
                        let weightKg = v.bodyMass > 0 ? v.bodyMass : (profile?.weight ?? 0)
                        detailRow(AppCopy.t("Poids", en: "Weight"), weightKg > 0 ? String(format: "%.1f kg", weightKg) : "—")
                        if let profile, profile.height > 0 {
                            detailRow(AppCopy.t("Taille", en: "Height"), "\(Int(profile.height)) cm")
                        }
                        detailRow(
                            AppCopy.t("Masse grasse", en: "Body fat"),
                            v.bodyFatPercentage > 0 ? String(format: "%.1f %%", v.bodyFatPercentage) : "—"
                        )
                    }

                    detailSection(AppCopy.t("Nutrition", en: "Nutrition"), icon: "fork.knife") {
                        let n = snapshot.nutrition
                        detailRow(AppCopy.t("Calories", en: "Calories"), n.caloriesConsumed > 0 ? "\(Int(n.caloriesConsumed)) kcal" : "—")
                        detailRow(AppCopy.t("Protéines", en: "Protein"), n.proteinGrams > 0 ? "\(Int(n.proteinGrams)) g" : "—")
                        detailRow(AppCopy.t("Glucides", en: "Carbs"), n.carbsGrams > 0 ? "\(Int(n.carbsGrams)) g" : "—")
                        detailRow(AppCopy.t("Lipides", en: "Fat"), n.fatGrams > 0 ? "\(Int(n.fatGrams)) g" : "—")
                        detailRow(AppCopy.t("Eau", en: "Water"), n.waterLiters > 0 ? String(format: "%.1f L", n.waterLiters) : "—")
                    }

                    if healthManager.baselines.daysOfData > 0 {
                        detailSection(AppCopy.t("Moyennes (14 j)", en: "Averages (14 d)"), icon: "chart.line.uptrend.xyaxis") {
                            let b = healthManager.baselines
                            detailRow(AppCopy.t("Jours de données", en: "Days of data"), "\(b.daysOfData)")
                            detailRow(
                                AppCopy.t("Sommeil cible", en: "Sleep target"),
                                b.sleepNeedHours > 0 ? String(format: "%.1f h", b.sleepNeedHours) : "—"
                            )
                            detailRow(AppCopy.t("Pas (14 j)", en: "Steps (14 d)"), b.avgDailySteps > 0 ? "\(Int(b.avgDailySteps))" : "—")
                            detailRow(
                                AppCopy.t("Calories (14 j)", en: "Calories (14 d)"),
                                b.avgActiveCalories > 0 ? "\(Int(b.avgActiveCalories)) kcal" : "—"
                            )
                        }
                    }
                }
                .padding(.top, 4)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.22)) { showDetails.toggle() }
            } label: {
                Label(
                    showDetails
                        ? AppCopy.t("Réduire", en: "Show less")
                        : AppCopy.t("Plus de détails", en: "More details"),
                    systemImage: showDetails ? "chevron.up" : "chevron.down"
                )
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.processPlain)
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
