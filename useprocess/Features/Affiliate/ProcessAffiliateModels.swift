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

struct ProcessAffiliateDashboardStats: Decodable, Equatable {
    let referredCount: Int
    let activeSubscribers: Int
    let pendingCents: Int
    let payableCents: Int
    let paidCents: Int
    let lifetimeCents: Int
}

struct ProcessAffiliateDashboardCode: Decodable, Equatable, Identifiable {
    var id: String { code }
    let code: String
    let displayName: String
    let status: String
}

struct ProcessAffiliateDashboardCommission: Decodable, Equatable, Identifiable {
    let id: String
    let inviteeUid: String
    let eventType: String
    let productId: String?
    let commissionCents: Int
    let currency: String
    let status: String
    let createdAt: Double?
    let holdUntil: Double?
}

struct ProcessAffiliateDashboardPayout: Decodable, Equatable, Identifiable {
    let id: String
    let amountCents: Int
    let currency: String
    let method: String
    let status: String
    let createdAt: Double?
}

struct ProcessAffiliateStripeConnect: Decodable, Equatable {
    let accountId: String?
    let onboardingComplete: Bool
    let payoutsEnabled: Bool
    let detailsSubmitted: Bool
    let requirementsDue: [String]
}

struct ProcessAffiliateDashboardResponse: Decodable, Equatable {
    let ok: Bool
    let affiliateId: String
    let displayName: String
    let status: String
    let payoutMethod: String?
    let stripeConnect: ProcessAffiliateStripeConnect?
    let codes: [ProcessAffiliateDashboardCode]
    let stats: ProcessAffiliateDashboardStats
    let recentCommissions: [ProcessAffiliateDashboardCommission]
    let payouts: [ProcessAffiliateDashboardPayout]
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
