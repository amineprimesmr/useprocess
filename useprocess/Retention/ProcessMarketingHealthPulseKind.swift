import Foundation

/// Notifs locales « l’app travaille » pour non-payeurs, basées sur HealthKit (`process.mkt.health_*`).
enum ProcessMarketingHealthPulseKind: String, CaseIterable, Identifiable {
    case sleepDetected = "health_sleep"
    case stepsMilestone = "health_steps"
    case activityDetected = "health_activity"
    case lowMovement = "health_low_movement"
    case eveningRecap = "health_evening"
    case caloriesBurned = "health_calories"
    case hrvSignal = "health_hrv"

    var id: String { rawValue }

    var notificationIdentifier: String {
        "process.mkt.\(rawValue)"
    }

    var userInfoKind: String {
        "marketing_\(rawValue)"
    }

    /// Soft CTA → offre lifetime (sauf recap soir qui ouvre l’app).
    var opensLifetimeOffer: Bool {
        switch self {
        case .eveningRecap:
            return false
        default:
            return true
        }
    }

    /// Plus haut = choisi en priorité quand plusieurs signaux le même jour.
    var priority: Int {
        switch self {
        case .activityDetected: return 100
        case .stepsMilestone: return 90
        case .sleepDetected: return 80
        case .caloriesBurned: return 70
        case .hrvSignal: return 60
        case .lowMovement: return 50
        case .eveningRecap: return 40
        }
    }

    @MainActor
    func title(metrics: ProcessMarketingHealthPulseMetrics) -> String {
        switch self {
        case .sleepDetected:
            return AppCopy.t("Nuit analysée", en: "Night analyzed")
        case .stepsMilestone:
            return AppCopy.t(
                "\(Self.formatSteps(metrics.steps)) pas aujourd’hui",
                en: "\(Self.formatSteps(metrics.steps)) steps today"
            )
        case .activityDetected:
            if metrics.exerciseMinutes >= 1 {
                return AppCopy.t(
                    "\(metrics.exerciseMinutes) min d’activité détectées",
                    en: "\(metrics.exerciseMinutes) min of activity detected"
                )
            }
            return AppCopy.t("Activité détectée", en: "Activity detected")
        case .lowMovement:
            return AppCopy.t("Peu de mouvement aujourd’hui", en: "Low movement today")
        case .eveningRecap:
            return AppCopy.t("Bilan du jour", en: "Today’s recap")
        case .caloriesBurned:
            return AppCopy.t(
                "\(metrics.activeCalories) kcal actives",
                en: "\(metrics.activeCalories) active kcal"
            )
        case .hrvSignal:
            return AppCopy.t("Signal récupération détecté", en: "Recovery signal detected")
        }
    }

    @MainActor
    func body(metrics: ProcessMarketingHealthPulseMetrics) -> String {
        switch self {
        case .sleepDetected:
            let sleep = Self.formatSleep(metrics.sleepHours)
            return AppCopy.t(
                "\(sleep) de sommeil lus via Health. Le gonflement suit souvent ça — débloque ton plan pour agir.",
                en: "\(sleep) of sleep read via Health. Puffiness often follows — unlock your plan to act."
            )
        case .stepsMilestone:
            return AppCopy.t(
                "Ta marche est suivie en live. Bon pour circulation et drainage. Débloque le plan pour en profiter.",
                en: "Your walk is tracked live. Good for circulation and drainage. Unlock the plan to use it."
            )
        case .activityDetected:
            return AppCopy.t(
                "Effort lu via HealthKit. L’impact sur ta rétention est déjà estimé — débloque pour le détail.",
                en: "Effort read via HealthKit. Retention impact is already estimated — unlock for the details."
            )
        case .lowMovement:
            return AppCopy.t(
                "Seulement \(Self.formatSteps(metrics.steps)) pas lus. Une marche aide le visage — ton protocole t’attend.",
                en: "Only \(Self.formatSteps(metrics.steps)) steps read. A walk helps your face — your protocol is waiting."
            )
        case .eveningRecap:
            var parts: [String] = []
            if metrics.steps > 0 {
                parts.append(AppCopy.t("\(Self.formatSteps(metrics.steps)) pas", en: "\(Self.formatSteps(metrics.steps)) steps"))
            }
            if metrics.sleepHours >= 3 {
                parts.append(AppCopy.t("\(Self.formatSleep(metrics.sleepHours)) sommeil", en: "\(Self.formatSleep(metrics.sleepHours)) sleep"))
            }
            if metrics.activeCalories >= 100 {
                parts.append(AppCopy.t("\(metrics.activeCalories) kcal", en: "\(metrics.activeCalories) kcal"))
            }
            let summary = parts.isEmpty
                ? AppCopy.t("HealthKit synchronisé", en: "HealthKit synced")
                : parts.joined(separator: " · ")
            return AppCopy.t(
                "\(summary). On a travaillé pour toi aujourd’hui — ouvre l’app.",
                en: "\(summary). We worked for you today — open the app."
            )
        case .caloriesBurned:
            return AppCopy.t(
                "Ton énergie dépensée a été lue. La circulation aide le dégonflement — débloque ton plan.",
                en: "Your energy burn was read. Circulation helps debloat — unlock your plan."
            )
        case .hrvSignal:
            return AppCopy.t(
                "HRV lue via Health. On relie ça à ton visage — débloque pour le détail.",
                en: "HRV read via Health. We link it to your face — unlock for the details."
            )
        }
    }

    private static func formatSteps(_ steps: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "\u{202F}"
        return formatter.string(from: NSNumber(value: steps)) ?? "\(steps)"
    }

    private static func formatSleep(_ hours: Double) -> String {
        let totalMinutes = Int((hours * 60).rounded())
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        if m == 0 {
            return AppCopy.t("\(h)h", en: "\(h)h")
        }
        return AppCopy.t(
            String(format: "%dh%02d", h, m),
            en: String(format: "%dh%02d", h, m)
        )
    }
}

struct ProcessMarketingHealthPulseMetrics: Equatable {
    var steps: Int = 0
    var sleepHours: Double = 0
    var exerciseMinutes: Int = 0
    var workoutCount: Int = 0
    var activeCalories: Int = 0
    var hrv: Double = 0

    static func from(_ snapshot: DailyHealthSnapshot) -> ProcessMarketingHealthPulseMetrics {
        ProcessMarketingHealthPulseMetrics(
            steps: snapshot.effort.steps,
            sleepHours: snapshot.sleep.sleepDuration,
            exerciseMinutes: Int(snapshot.effort.exerciseMinutes.rounded()),
            workoutCount: snapshot.effort.workoutCount,
            activeCalories: Int(snapshot.effort.activeEnergyBurned.rounded()),
            hrv: snapshot.vitals.hrv
        )
    }
}
