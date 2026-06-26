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
    var tasks: [OriginPlanTask] = [
      journalTask(
        id: "\(dayId).face.lymph",
        title: "Massage lymphatique",
        detail: "\(targets.lymphFaceMassageMinutes) min sous les yeux vers les oreilles",
        pillar: "Visage",
        minutes: targets.lymphFaceMassageMinutes
      )
    ]

    let jawWork = plan.faceProtocol.jawAndTongueWork
    if !jawWork.isEmpty {
      let index = dayIndex % jawWork.count
      let line = jawWork[index]
      tasks.append(
        journalTask(
          id: "\(dayId).face.orofacial",
          title: "Orofacial du jour",
          detail: line,
          pillar: "Visage",
          minutes: 5
        )
      )
    }

    if plan.faceProtocol.jawAndTongueWork.contains(where: {
      $0.localizedCaseInsensitiveContains("tape")
    }) {
      tasks.append(
        journalTask(
          id: "\(dayId).face.tape",
          title: "Tape zyg / mentalis",
          detail: "Joues + menton avant le coucher — lip seal nocturne",
          pillar: "Visage",
          minutes: 2,
          optional: true
        )
      )
    }

    return tasks
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

    if !plan.postureProtocol.breathingWork.isEmpty {
      let breathing = plan.postureProtocol.breathingWork.first ?? ""
      tasks.append(
        journalTask(
          id: "\(dayId).posture.breath",
          title: "Respiration nasale",
          detail: breathing,
          pillar: "Posture",
          minutes: 5
        )
      )
    }

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
