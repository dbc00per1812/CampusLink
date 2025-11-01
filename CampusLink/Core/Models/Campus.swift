import Foundation

/// Represents the available campuses users can select during signup
enum Campus: String, CaseIterable, Codable {
    case indianaUniversityBloomington = "Indiana University Bloomington"
    case purdueUniversity = "Purdue University"
    
    /// Display name for the campus
    var displayName: String {
        return self.rawValue
    }
    
    /// Short abbreviation for the campus
    var abbreviation: String {
        switch self {
        case .indianaUniversityBloomington:
            return "IU"
        case .purdueUniversity:
            return "Purdue"
        }
    }
}

