import Foundation

enum ProcessAffiliateCodeKind: String, Codable, Equatable {
    case affiliate
    case referral
}

struct ProcessAffiliateResolveResult: Decodable, Equatable {
    let ok: Bool
    let type: ProcessAffiliateCodeKind
    let code: String
    let displayName: String?
    let affiliateId: String?
    let referrerUserId: String?
}

enum ProcessAffiliateAttributionKind: String, Codable {
    case affiliate
    case referral
}

struct ProcessStoredAcquisitionCode: Codable, Equatable {
    var code: String
    var kind: ProcessAffiliateAttributionKind
    var displayName: String?
}
