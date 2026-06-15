import SwiftUI

/// Rendu markdown léger pour les messages coach (**gras**, *italique*).
struct CoachFormattedText: View {
    let text: String
    var font: Font = .system(size: 18, weight: .regular)
    var lineSpacing: CGFloat = 5
    var color: Color = .primary

    var body: some View {
        Group {
            if let attributed = makeAttributedString(from: text) {
                Text(attributed)
            } else {
                Text(plainText(from: text))
            }
        }
        .font(font)
        .foregroundStyle(color)
        .lineSpacing(lineSpacing)
    }

    static func plainText(from text: String) -> String {
        text
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "_", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func sanitizeField(_ text: String) -> String {
        plainText(from: text)
    }

    private func plainText(from text: String) -> String {
        Self.plainText(from: text)
    }

    private func makeAttributedString(from raw: String) -> AttributedString? {
        let normalized = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        guard let attributed = try? AttributedString(
            markdown: normalized,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
        ) else {
            return nil
        }
        return attributed
    }
}
