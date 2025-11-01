import Foundation

// MARK: - Report Types
enum ReportType: String, Codable, CaseIterable {
    case inappropriateContent = "inappropriate_content"
    case scam = "scam"
    case harassment = "harassment"
    case spam = "spam"
    case fakeProfile = "fake_profile"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .inappropriateContent:
            return "Inappropriate Content"
        case .scam:
            return "Scam or Fraud"
        case .harassment:
            return "Harassment or Bullying"
        case .spam:
            return "Spam"
        case .fakeProfile:
            return "Fake Profile"
        case .other:
            return "Other"
        }
    }
    
    var description: String {
        switch self {
        case .inappropriateContent:
            return "Content that violates community guidelines"
        case .scam:
            return "Suspicious or fraudulent activity"
        case .harassment:
            return "Threatening or abusive behavior"
        case .spam:
            return "Repetitive or unwanted messages"
        case .fakeProfile:
            return "Account impersonating someone else"
        case .other:
            return "Other violation not listed above"
        }
    }
}

// MARK: - Report Model
struct Report: Codable, Identifiable {
    let id: String
    let reporterId: String
    let reportedUserId: String?
    let reportedListingId: String?
    let reportType: ReportType
    let description: String
    let status: ReportStatus
    let createdAt: Date
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case reporterId = "reporter_id"
        case reportedUserId = "reported_user_id"
        case reportedListingId = "reported_listing_id"
        case reportType = "report_type"
        case description
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Report Status
enum ReportStatus: String, Codable {
    case pending = "pending"
    case reviewing = "reviewing"
    case resolved = "resolved"
    case dismissed = "dismissed"
}

// MARK: - Report Creation
struct ReportCreate: Codable {
    let reporterId: String
    let reportedUserId: String?
    let reportedListingId: String?
    let reportType: String
    let description: String
    
    enum CodingKeys: String, CodingKey {
        case reporterId = "reporter_id"
        case reportedUserId = "reported_user_id"
        case reportedListingId = "reported_listing_id"
        case reportType = "report_type"
        case description
    }
}
