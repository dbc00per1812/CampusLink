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
    
    // MARK: - Campus Domain Filter
    
    /// Controls whether listings are filtered by campus domain
    static let enableDomainFilter = false
    
    // MARK: - API Configuration
    
    static let supabaseURL = "https://your-project.supabase.co"
    static let supabaseAnonKey = "your-anon-key"
    
    // MARK: - Stripe Configuration
    
    static let stripePublishableKey = "pk_test_..."
    
    // MARK: - Other Settings
    
    static let maxImageSizeBytes = 10 * 1024 * 1024 // 10MB
    static let imageCompressionQuality: CGFloat = 0.8
}
