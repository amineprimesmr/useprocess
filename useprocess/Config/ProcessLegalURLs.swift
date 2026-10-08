import Foundation

enum ProcessLegalURLs {
    private static var langQuery: String {
        let code = ProcessAppLanguage.currentCode
        return code == .french ? "" : "?lang=\(code.rawValue)"
    }

    static var termsOfUse: URL {
        URL(string: "\(AppConfiguration.websiteOrigin)/cgu\(langQuery)")!
    }

    static var privacyPolicy: URL {
        URL(string: "\(AppConfiguration.websiteOrigin)/confidentialite\(langQuery)")!
    }

    static var privacyPolicyFaceData: URL {
        URL(string: "\(AppConfiguration.websiteOrigin)/confidentialite\(langQuery)#donnees-faciales")!
    }

    static var privacyPolicyAI: URL {
        URL(string: "\(AppConfiguration.websiteOrigin)/confidentialite\(langQuery)#intelligence-artificielle")!
    }

    static var legalNotice: URL {
        URL(string: "\(AppConfiguration.websiteOrigin)/mentions-legales\(langQuery)")!
    }

    static var supportPage: URL {
        URL(string: "\(AppConfiguration.websiteOrigin)/support\(langQuery)")!
    }

    static var supportMail: URL { URL(string: "mailto:\(AppConfiguration.supportEmail)")! }


    static let tiktok = URL(string: "https://www.tiktok.com/@useprocess")!
    static let instagram = URL(string: "https://www.instagram.com/useprocess")!
    static let snapchat = URL(string: "https://www.snapchat.com/add/useprocess")!
    static let x = URL(string: "https://x.com/useprocess")!
}
