import Foundation

/// Dates produit — toujours la locale de `ProcessLanguageCode`, jamais un calque FR vs EN.
enum ProcessLocalizedDate {
    static func string(
        from date: Date,
        template: String,
        code: ProcessLanguageCode = ProcessSharedLanguage.currentCode
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: code.localeIdentifier)
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }
}
