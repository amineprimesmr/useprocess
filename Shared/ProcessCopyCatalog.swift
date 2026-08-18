import Foundation

/// Catalogues JA / DE / KO / ES / PT-BR — clé = anglais source (`en:` de AppCopy).
/// FR et EN restent les arguments de `AppCopy.t` / `ProcessSharedLanguage.t`.
nonisolated enum ProcessCopyCatalog {
    private struct File: Decodable {
        var exact: [String: String]
        var templates: [Template]

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            exact = try container.decodeIfPresent([String: String].self, forKey: .exact) ?? [:]
            templates = try container.decodeIfPresent([Template].self, forKey: .templates) ?? []
        }

        private enum CodingKeys: String, CodingKey {
            case exact
            case templates
        }
    }

    private struct Template: Decodable {
        var re: String
        var to: String
    }

    private struct Loaded {
        var exact: [String: String]
        var templates: [(NSRegularExpression, String)]
    }

    private static let tables: [String: Loaded] = {
        var result: [String: Loaded] = [:]
        for code in ["ja", "de", "ko", "es", "pt-BR"] {
            result[code] = load(code)
        }
        return result
    }()

    static func resolve(fr: String, en: String, code: ProcessLanguageCode) -> String {
        switch code {
        case .french:
            return fr
        case .english:
            return en
        case .japanese, .german, .korean, .spanish, .portugueseBrazil:
            if let hit = tables[code.rawValue]?.exact[en] {
                return hit
            }
            if let hit = applyTemplates(en, code: code.rawValue) {
                return hit
            }
            return en
        }
    }

    private static func applyTemplates(_ en: String, code: String) -> String? {
        guard let templates = tables[code]?.templates, !templates.isEmpty else { return nil }
        let ns = en as NSString
        let range = NSRange(location: 0, length: ns.length)
        for (regex, replacement) in templates {
            if regex.firstMatch(in: en, options: [], range: range) != nil {
                return regex.stringByReplacingMatches(
                    in: en,
                    options: [],
                    range: range,
                    withTemplate: replacement
                )
            }
        }
        return nil
    }

    private static func load(_ code: String) -> Loaded {
        let resource = "copy-\(code)"
        let url =
            Bundle.main.url(forResource: resource, withExtension: "json")
            ?? Bundle.main.url(forResource: resource, withExtension: "json", subdirectory: "Localization")
        guard let url,
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data)
        else {
            return Loaded(exact: [:], templates: [])
        }
        let templates: [(NSRegularExpression, String)] = file.templates.compactMap { row in
            guard let regex = try? NSRegularExpression(pattern: row.re) else { return nil }
            return (regex, row.to)
        }
        return Loaded(exact: file.exact, templates: templates)
    }
}
