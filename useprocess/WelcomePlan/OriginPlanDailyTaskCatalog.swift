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
    let blocks = plan.postureProtocol.mobilityBlocks
    guard !blocks.isEmpty else { return [] }

    var tasks: [OriginPlanTask] = [
      journalTask(
        id: "\(dayId).posture.circuit",
        title: "Circuit posture",
        detail: "\(blocks.count) blocs — \(blocks.prefix(2).joined(separator: " · "))",
        pillar: "Posture",
        minutes: 10
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
          title: "Couvre-feu écrans",
          detail: "\(ProcessDailyTargets.screenCurfewMinutes) min avant coucher — mode avion",
          pillar: "Sommeil"
        )
      )
    }

    if answers["alcohol_frequency"]?.choiceIds.first == "often"
      || answers["alcohol_frequency"]?.choiceIds.first == "weekly" {
      tasks.append(
        journalTask(
          id: "\(dayId).evening.alcohol",
          title: "Alcool",
          detail: "Soir sans alcool — debloat visage garanti",
          pillar: "Nutrition"
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
    if lower.contains("soleil") { return targets.morningLightMinutes }
    if lower.contains("massage") { return targets.lymphFaceMassageMinutes }
    if lower.contains("glacon") || lower.contains("glaçon") || lower.contains("eau froide") { return 1 }
    return nil
  }

  private static func checklistTitle(for line: String, index: Int) -> String {
    let lower = line.lowercased()
    if lower.contains("côté") || lower.contains("dos") { return "Sommeil sur le côté" }
    if lower.contains("spot t") || lower.contains("déglut") { return "Langue sur palais (nuit)" }
    if lower.contains("tape") { return "Tape zyg / mentalis" }
    if lower.contains("respiration") { return "Respiration fasciale" }
    if index == 0 { return "Préparation sommeil" }
    return "Routine nocturne"
  }
}
