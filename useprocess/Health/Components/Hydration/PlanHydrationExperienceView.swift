import SwiftUI

/// Hub hydratation — liquid glass iOS 26, contenu visible derrière l'eau.
struct PlanHydrationExperienceView: View {
    let plan: FaceOriginPlan
    let day: OriginProgramDay
    var selectedDate: Date

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var healthManager: HealthManager

    @StateObject private var waterEngine = ProcessFluidWaterMotionEngine()
    @Bindable private var hydrationStore = ProcessHydrationLogStore.shared

    @State private var animatedFill: CGFloat = 0.08
    @State private var displayedMilliliters: Int = 0
    @State private var showGoalCelebration = false
    @State private var showCustomAmountSheet = false
    @State private var customAmountML = 300

    private var targets: OriginPersonalizedDailyTargets { plan.resolvedDailyTargets }
    private var targetMilliliters: Int { targets.hydrationLitersPerDay * 1000 }

    private var healthKitMilliliters: Int {
        Int((healthManager.todaySnapshot.nutrition.waterLiters * 1000).rounded())
    }

    private var effectiveMilliliters: Int {
        max(hydrationStore.milliliters(for: selectedDate), healthKitMilliliters)
    }

    private var fillProgress: CGFloat {
        CGFloat(hydrationStore.progress(
            for: selectedDate,
            targetLiters: Double(targets.hydrationLitersPerDay),
            healthKitLiters: healthManager.todaySnapshot.nutrition.waterLiters
        ))
    }

    private var percentage: Int {
        guard targetMilliliters > 0 else { return 0 }
        return min(999, Int((Double(effectiveMilliliters) / Double(targetMilliliters) * 100).rounded()))
    }

    private var todayEntries: [ProcessHydrationEntry] {
        hydrationStore.entries(for: selectedDate)
    }

    var body: some View {
        ProcessFluidWaterSceneView(
            engine: waterEngine,
            fillLevel: animatedFill
        ) {
            ZStack {
                background

                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                    Spacer(minLength: 24)

                    hero
                        .padding(.horizontal, 24)

                    Spacer(minLength: 32)

                    actions
                        .padding(.horizontal, 20)

                    history
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 28)
                }
            }
        }
        .preferredColorScheme(.light)
        .onAppear {
            waterEngine.start()
            syncDisplayedValues(animated: false)
            Task { await healthManager.syncHealthDataForDate(Date()) }
        }
        .onDisappear {
            waterEngine.stop()
        }
        .onChange(of: effectiveMilliliters) { _, _ in
            syncDisplayedValues(animated: true)
        }
        .onChange(of: fillProgress) { _, progress in
            if progress >= 1, !showGoalCelebration {
                showGoalCelebration = true
                HapticManager.shared.notification(.success)
            }
        }
        .sheet(isPresented: $showCustomAmountSheet) {
            customAmountSheet
        }
    }

    // MARK: - Fond riche (le glass `.clear` réfracte ce qu'il y a derrière)

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.99, blue: 1.0),
                    Color(red: 0.88, green: 0.96, blue: 1.0),
                    Color(red: 0.76, green: 0.91, blue: 0.98)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    Color(red: 0.55, green: 0.88, blue: 0.98, opacity: 0.35),
                    .clear
                ],
                center: .init(x: 0.5, y: 0.72),
                startRadius: 20,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button {
                HapticManager.shared.impact(.light)
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary.opacity(0.72))
                    .frame(width: 40, height: 40)
            }
            .processNativeGlassCircleButtonStyle()

            Spacer()

            if showGoalCelebration {
                Label("Objectif atteint", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(red: 0.08, green: 0.56, blue: 0.36))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .processGlassEffect(in: Capsule(), interactive: false)
            } else {
                Text("\(targets.hydrationLitersPerDay) L / jour")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary.opacity(0.55))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .processGlassEffect(in: Capsule(), interactive: false)
            }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 10) {
            Text("\(percentage)%")
                .font(.system(size: 96, weight: .bold, design: .rounded))
                .foregroundStyle(Color.primary.opacity(0.88))
                .contentTransition(.numericText())
                .animation(.spring(response: 0.5, dampingFraction: 0.82), value: percentage)

            Text("\(formattedML(displayedMilliliters)) ml")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.primary.opacity(0.82))
                .contentTransition(.numericText())

            Text("sur \(formattedML(targetMilliliters)) ml")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.48))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Hydratation \(percentage) pour cent, \(displayedMilliliters) millilitres sur \(targetMilliliters)")
    }

    // MARK: - Actions

    private var actions: some View {
        HStack(spacing: 10) {
            correctionButton
            addButton(title: "+ 150 ml", amount: 150)
            addButton(title: "+ 250 ml", amount: 250)
            Button {
                HapticManager.shared.impact(.light)
                showCustomAmountSheet = true
            } label: {
                Text("Perso")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }
            .processGlassButton(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var correctionButton: some View {
        Button {
            removeWater(milliliters: 500)
        } label: {
            Image(systemName: "minus")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.primary)
                .frame(width: 52, height: 48)
        }
        .processGlassButton(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .disabled(hydrationStore.milliliters(for: selectedDate) <= 0)
        .opacity(hydrationStore.milliliters(for: selectedDate) <= 0 ? 0.45 : 1)
        .accessibilityLabel("Retirer 500 millilitres")
    }

    private func addButton(title: String, amount: Int) -> some View {
        Button {
            addWater(milliliters: amount)
        } label: {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
        }
        .processGlassButton(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Historique

    private var history: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Aujourd'hui")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.primary.opacity(0.86))

                Spacer()

                Text("\(formattedLiters(displayedMilliliters)) L")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary.opacity(0.52))
            }

            if todayEntries.isEmpty {
                Text("Ajoute ta première prise d'eau")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.42))
            } else {
                ForEach(todayEntries.prefix(5)) { entry in
                    HStack {
                        Text(entry.milliliters >= 0 ? "+\(entry.milliliters) ml" : "\(entry.milliliters) ml")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(entry.milliliters >= 0 ? Color.primary.opacity(0.78) : Color.primary.opacity(0.45))

                        Spacer()

                        Text(entry.loggedAt, format: .dateTime.hour().minute())
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.primary.opacity(0.38))
                    }
                }
            }
        }
        .padding(16)
        .processGlassEffect(in: RoundedRectangle(cornerRadius: 20, style: .continuous), interactive: false)
    }

    // MARK: - Sheet perso

    private var customAmountSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("\(customAmountML) ml")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .padding(.top, 12)

                Slider(
                    value: Binding(
                        get: { Double(customAmountML) },
                        set: { customAmountML = Int($0.rounded()) }
                    ),
                    in: 50...1500,
                    step: 50
                )
                .padding(.horizontal, 24)

                Button {
                    addWater(milliliters: customAmountML)
                    showCustomAmountSheet = false
                } label: {
                    Text("Ajouter")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .processGlassButton(in: Capsule())

                Spacer()
            }
            .navigationTitle("Quantité")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { showCustomAmountSheet = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Helpers

    private func formattedML(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func formattedLiters(_ value: Int) -> String {
        String(format: "%.1f", Double(value) / 1000)
    }

    private func addWater(milliliters: Int) {
        HapticManager.shared.impact(.medium)
        hydrationStore.addWater(
            milliliters: milliliters,
            for: selectedDate,
            dayId: day.id,
            targetMilliliters: targetMilliliters
        )
        waterEngine.bumpWave()
        syncDisplayedValues(animated: true)
    }

    private func removeWater(milliliters: Int) {
        HapticManager.shared.impact(.light)
        hydrationStore.removeWater(
            milliliters: milliliters,
            for: selectedDate,
            dayId: day.id,
            targetMilliliters: targetMilliliters
        )
        waterEngine.bumpWave()
        showGoalCelebration = fillProgress >= 1
        syncDisplayedValues(animated: true)
    }

    private func syncDisplayedValues(animated: Bool) {
        let ml = effectiveMilliliters
        let fill = max(0.08, min(1, fillProgress))

        if animated {
            withAnimation(.spring(response: 0.62, dampingFraction: 0.78)) {
                displayedMilliliters = ml
                animatedFill = fill
            }
        } else {
            displayedMilliliters = ml
            animatedFill = fill
        }
    }
}
