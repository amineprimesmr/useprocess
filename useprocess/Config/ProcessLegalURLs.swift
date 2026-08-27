import Foundation

enum ProcessLegalURLs {
    private static var langQuery: String {
        let code = ProcessAppLanguage.currentCode
        return code == .french ? "" : "?lang=\(code.rawValue)"
    }

    static var termsOfUse: URL {
        URL(string: "https://useprocess.xyz/cgu\(langQuery)")!
    }

    static var privacyPolicy: URL {
        URL(string: "https://useprocess.xyz/confidentialite\(langQuery)")!
    }

    static var privacyPolicyFaceData: URL {
        URL(string: "https://useprocess.xyz/confidentialite\(langQuery)#donnees-faciales")!
    }

    static var privacyPolicyAI: URL {
        URL(string: "https://useprocess.xyz/confidentialite\(langQuery)#intelligence-artificielle")!
    }

    static var legalNotice: URL {
        URL(string: "https://useprocess.xyz/mentions-legales\(langQuery)")!
    }

    static var supportPage: URL {
        URL(string: "https://useprocess.xyz/support\(langQuery)")!
    }

    static let supportMail = URL(string: "mailto:support@useprocess.xyz")!

    static var affiliatePortal: URL {
        URL(string: "https://useprocess.xyz/clipping\(langQuery)")!
    }

    static let tiktok = URL(string: "https://www.tiktok.com/@useprocess")!
    static let instagram = URL(string: "https://www.instagram.com/useprocess")!
    static let snapchat = URL(string: "https://www.snapchat.com/add/useprocess")!
    static let x = URL(string: "https://x.com/useprocess")!
}
