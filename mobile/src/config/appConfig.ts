import { isPreview } from './secrets';

export const AppConfig = {
  // MARK: - Feature Flags
  
  /** Controls whether Seek mode is enabled in the app */
  enableSeekMode: true,
  
  /** Controls whether Ratings system is enabled in the app */
  enableRatings: true,
  
  /** Controls whether Search functionality is enabled in the app */
  enableSearch: true,
  
  /** Controls whether Hybrid Search (keyword + semantic) is enabled */
  enableHybridSearch: false,
  
  /** Controls whether Notifications system is enabled in the app */
  enableNotifications: true,
  
  /** Controls whether Distance feature is enabled in the app */
  enableDistanceFeature: false,
  
  // MARK: - Preview Branch Features
  
  /** Controls whether Smart Search is enabled */
  enableSmartSearch: true,
  
  /** Controls whether Recommendations are enabled */
  enableRecommendations: true,
  
  // MARK: - Campus Filter
  
  /** Controls whether listings are filtered by campus */
  enableCampusFilter: true,
  
  // MARK: - Other Settings
  
  maxImageSizeBytes: 10 * 1024 * 1024, // 10MB
  imageCompressionQuality: 0.8,
  
  // MARK: - Environment Info
  
  /** Helper to check if we're on preview branch */
  isPreviewEnvironment: isPreview,
} as const;

export default AppConfig;

