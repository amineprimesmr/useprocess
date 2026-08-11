import Foundation

/// Tâches journal quotidien dérivées du protocole généré (visage, posture, sommeil).
enum OriginPlanDailyTaskCatalog {

  // MARK: - Visage

  static func faceTasks(
    plan: FaceOriginPlan,
    targets: OriginPersonalizedDailyTargets,
    dayId: String,
    dayIndex: Int
  ) -> [OriginPlanTask] {
    _ = plan
    _ = dayIndex

    return FaceMorningRoutineCatalog.buildSteps(targets: targets).enumerated().map { index, line in
      let parts = splitTitleAndDetail(line)
      return journalTask(
        id: "\(dayId).face.morning.\(index)",
        title: parts.title,
        detail: parts.detail.isEmpty ? line : parts.detail,
        pillar: "Visage",
        minutes: repMinutes(from: line, targets: targets)
      )
    }
  }

  // MARK: - Posture

  static func postureTasks(plan: FaceOriginPlan, dayId: String) -> [OriginPlanTask] {
    let blocks = PlanPostureCircuitContent.mobilityBlocks(for: plan)
    guard !blocks.isEmpty else { return [] }

    let duration = PlanPostureCircuitContent.estimatedCircuitDurationMinutes(for: plan)

    let tasks: [OriginPlanTask] = [
      journalTask(
        id: "\(dayId).posture.circuit",
        title: AppCopy.tSync("Cardio et Circuit", en: "Cardio & Circuit"),
        detail: AppCopy.tSync(
          "\(duration) min — \(blocks.prefix(2).joined(separator: " · "))",
          en: "\(duration) min — \(blocks.prefix(2).joined(separator: " · "))"
        ),
        pillar: AppCopy.tSync("Circuit", en: "Circuit"),
        minutes: duration
      )
    ]

    return tasks
  }

  // MARK: - Soir / sommeil

  static func eveningTasks(
    plan: FaceOriginPlan,
    answers: [String: WelcomePlanAnswer],
    dayId: String
  ) -> [OriginPlanTask] {
    var tasks: [OriginPlanTask] = []

    if answers["screen_before_bed"]?.choiceIds.first == "yes" {
      tasks.append(
        journalTask(
          id: "\(dayId).evening.screen",
          title: AppCopy.tSync("Couvre-feu écrans", en: "Screen curfew"),
          detail: AppCopy.tSync(
            "\(ProcessDailyTargets.screenCurfewMinutes) min avant coucher — mode avion",
            en: "\(ProcessDailyTargets.screenCurfewMinutes) min before bed — airplane mode"
          ),
          pillar: AppCopy.tSync("Sommeil", en: "Sleep")
        )
      )
    }

    if answers["alcohol_frequency"]?.choiceIds.first == "often"
      || answers["alcohol_frequency"]?.choiceIds.first == "weekly" {
      tasks.append(
        journalTask(
          id: "\(dayId).evening.alcohol",
          title: AppCopy.tSync("Alcool", en: "Alcohol"),
          detail: AppCopy.tSync(
            "Soir sans alcool — debloat visage garanti",
            en: "Alcohol-free evening — guaranteed face debloat"
          ),
          pillar: AppCopy.tSync("Nutrition", en: "Nutrition")
        )
      )
    }

    for (index, line) in SideSleepIntelligenceGuide.checklistEveningTasks(
      answers: answers,
      sleepProtocol: plan.sleepProtocol
    ).enumerated() {
      tasks.append(
        journalTask(
          id: "\(dayId).evening.sleep.\(index)",
          title: checklistTitle(for: line, index: index),
          detail: line,
          pillar: "Sommeil"
        )
      )
    }

    return tasks
  }

  // MARK: - Private

  private static func journalTask(
    id: String,
    title: String,
    detail: String,
    pillar: String,
    minutes: Int? = nil,
    optional: Bool = false
  ) -> OriginPlanTask {
    OriginPlanTask(
      id: id,
      title: title,
      detail: detail,
      pillar: pillar,
      durationMinutes: minutes,
      isOptional: optional
    )
  }

  private static func splitTitleAndDetail(_ line: String) -> (title: String, detail: String) {
    for separator in [" — ", " – ", " - "] {
      if let range = line.range(of: separator) {
        let title = String(line[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
        let detail = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        return (title, detail)
      }
    }
    return (line.trimmingCharacters(in: .whitespaces), "")
  }

  private static func repMinutes(from line: String, targets: OriginPersonalizedDailyTargets) -> Int? {
    let lower = line.lowercased()
    if lower.contains("eau tiède") || lower.contains("eau tiede") { return 2 }
    if lower.contains("sauts sur place") || lower.contains("saut sur place") {
      return max(1, ProcessDailyTargets.lymphJumpSeconds / 60)
    }
    if lower.contains("montées de genoux") || lower.contains("montee de genoux") {
      return max(1, ProcessDailyTargets.lymphKneeRaiseSeconds / 60)
    }
    if lower.contains("bras alternés") || lower.contains("bras alternes") {
      return max(1, ProcessDailyTargets.lymphArmRaiseSeconds / 60)
    }
    if lower.contains("massage") { return targets.lymphFaceMassageMinutes }
    if lower.contains("glacon") || lower.contains("glaçon") || lower.contains("eau froide") { return 1 }
    return nil
  }

  private static func checklistTitle(for line: String, index: Int) -> String {
    let lower = line.lowercased()
    if lower.contains("côté") || lower.contains("dos") {
      return AppCopy.tSync("Sommeil sur le côté", en: "Side sleep")
    }
    if lower.contains("spot t") || lower.contains("déglut") {
      return AppCopy.tSync("Langue sur palais (nuit)", en: "Tongue on palate (night)")
    }
    if lower.contains("tape") {
      return AppCopy.tSync("Tape zyg / mentalis", en: "Zyg / mentalis tape")
    }
    if lower.contains("respiration") {
      return AppCopy.tSync("Respiration fasciale", en: "Facial breathing")
    }
    if index == 0 {
      return AppCopy.tSync("Préparation sommeil", en: "Sleep prep")
    }
    return AppCopy.tSync("Routine nocturne", en: "Night routine")
  }
}
