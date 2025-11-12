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
    
    /// Controls whether Hybrid Search (keyword + semantic) is enabled
    /// Phase 2: Enabled after vector embeddings are set up
    /// Falls back to keyword-only search if disabled or if hybrid search fails
    /// SET TO FALSE until embeddings are generated (0% currently)
    static let enableHybridSearch = false
    
    /// Controls whether Notifications system is enabled in the app
    /// Phase 0: Enabled after database setup is complete
    static let enableNotifications = true
    
    /// Controls whether Distance feature is enabled in the app
    /// Shows distance between buyers and sellers on listing cards
    static let enableDistanceFeature = false
    
    // MARK: - Preview Branch Features (Testing on Preview)
    
    /// Controls whether Smart Search is enabled (advanced filtering, sorting)
    /// Testing on preview branch first
    static let enableSmartSearch = true
    
    /// Controls whether Recommendations are enabled (AI/ML-based suggestions)
    /// Testing on preview branch first  
    static let enableRecommendations = true
    
    // MARK: - Campus Filter
    
    /// Controls whether listings are filtered by campus
    static let enableCampusFilter = true
    
    // MARK: - Other Settings
    
    static let maxImageSizeBytes = 10 * 1024 * 1024 // 10MB
    static let imageCompressionQuality: CGFloat = 0.8
    
    // MARK: - Environment Info
    
    /// Helper to check if we're on preview branch
    static var isPreviewEnvironment: Bool {
        // Import Secrets to check environment
        return Secrets.isPreview
    }
}