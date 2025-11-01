import Foundation

struct AppConfig {
    // MARK: - Feature Flags
    
    /// Controls whether Seek mode is enabled in the app
    /// Phase 3: Enabled after database supports NULL price for seeks
    static let enableSeekMode = true
    
    /// Controls whether Ratings system is enabled in the app
    /// Phase 0: Enabled after database setup is complete
    static let enableRatings = true
    
    /// Controls whether Search functionality is enabled in the app
    /// Phase 0: Ready for testing - basic search infrastructure complete
    static let enableSearch = true
    
    /// Controls whether Notifications system is enabled in the app
    /// Phase 0: Enabled after database setup is complete
    static let enableNotifications = true
    
    /// Controls whether Distance feature is enabled in the app
    /// Shows distance between buyers and sellers on listing cards
    static let enableDistanceFeature = false
    
    // MARK: - Campus Filter
    
    /// Controls whether listings are filtered by campus
    static let enableCampusFilter = true
    
    // MARK: - Other Settings
    
    static let maxImageSizeBytes = 10 * 1024 * 1024 // 10MB
    static let imageCompressionQuality: CGFloat = 0.8
}