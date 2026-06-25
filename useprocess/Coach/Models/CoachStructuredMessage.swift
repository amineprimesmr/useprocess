import Foundation

enum CoachMessageSegment: Equatable {
    case paragraph(String)
    case workout(CoachWorkoutPreview)
}

struct CoachWorkoutPreview: Equatable {
    var title: String
    var durationMinutes: Int?
    var exercises: [CoachExercisePreview]
    var footer: String?
}

struct CoachExercisePreview: Equatable, Identifiable {
    let id: String
    let name: String
    let sets: Int
    let reps: String
}

enum CoachStructuredMessageParser {

    private struct ExerciseMatch {
        let name: String
        let sets: Int
        let reps: String
        let range: Range<String.Index>
    }

    static func segments(from text: String) -> [CoachMessageSegment] {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else { return [] }

        let matches = findExerciseMatches(in: normalized)
        guard matches.count >= 2 else {
            return [.paragraph(normalized)]
        }

        let firstRange = matches.first!.range
        let lastRange = matches.last!.range

        let intro = String(normalized[..<firstRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ":,"))

        let outro = String(normalized[lastRange.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let duration = extractDuration(from: normalized)
        let title = extractSessionTitle(from: intro, fullText: normalized)

        let exercises = matches.map { match in
            CoachExercisePreview(
                id: "\(match.name)|\(match.sets)x\(match.reps)",
                name: match.name.trimmingCharacters(in: .whitespacesAndNewlines),
                sets: match.sets,
                reps: match.reps
            )
        }

        var segments: [CoachMessageSegment] = []

        if let introParagraph = cleanedIntro(intro), !introParagraph.isEmpty {
            segments.append(.paragraph(introParagraph))
        }

        segments.append(
            .workout(
                CoachWorkoutPreview(
                    title: title,
                    durationMinutes: duration,
                    exercises: exercises,
                    footer: outro.isEmpty ? nil : outro
                )
            )
        )

        return segments
    }

    private static func findExerciseMatches(in text: String) -> [ExerciseMatch] {
        let pattern = #"([^,\n]+?)\s+(\d+)\s*[x×]\s*([\d./\-–]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }

        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let results = regex.matches(in: text, options: [], range: nsRange)

        return results.compactMap { result in
            guard result.numberOfRanges >= 4,
                  let nameRange = Range(result.range(at: 1), in: text),
                  let setsRange = Range(result.range(at: 2), in: text),
                  let repsRange = Range(result.range(at: 3), in: text),
                  let fullRange = Range(result.range, in: text) else { return nil }

            let name = String(text[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            let sets = Int(text[setsRange].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            let reps = String(text[repsRange]).trimmingCharacters(in: .whitespacesAndNewlines)

            guard !name.isEmpty, sets > 0, !reps.isEmpty else { return nil }

            return ExerciseMatch(name: name, sets: sets, reps: reps, range: fullRange)
        }
    }

    private static func extractDuration(from text: String) -> Int? {
        let pattern = #"(\d+)\s*min"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return Int(text[range])
    }

    private static func extractSessionTitle(from intro: String, fullText: String) -> String {
        let corpus = (intro + " " + fullText).lowercased()

        let namedSessions = [
            ("push", "Push"),
            ("pull", "Pull"),
            ("legs", "Legs"),
            ("leg day", "Legs"),
            ("upper", "Upper"),
            ("lower", "Lower"),
            ("full body", "Full body"),
            ("cardio", "Cardio")
        ]
        for (needle, label) in namedSessions where corpus.contains(needle) {
            return label
        }

        if let range = intro.range(
            of: #"(?:séance|seance)\s*[:\-]?\s*([^\.,\n]+)"#,
            options: .regularExpression
        ) {
            let fragment = String(intro[range])
            let cleaned = fragment
                .replacingOccurrences(of: "séance", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "seance", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: CharacterSet(charactersIn: ":- ").union(.whitespacesAndNewlines))
            if !cleaned.isEmpty { return cleaned.capitalized }
        }

        return "Séance"
    }

    private static func cleanedIntro(_ intro: String) -> String? {
        var value = intro
            .replacingOccurrences(of: " :", with: ":")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if value.hasSuffix(":") {
            value = String(value.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return value.isEmpty ? nil : value
    }
}
