import Foundation

enum ProcessLegalURLs {
    private static var langQuery: String {
        ProcessAppLanguage.prefersEnglish ? "?lang=en" : ""
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
}
