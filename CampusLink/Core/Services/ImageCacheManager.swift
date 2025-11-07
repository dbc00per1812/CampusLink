import SwiftUI
import Combine

/// Production-grade image cache with memory and disk persistence
class ImageCacheManager: ObservableObject {
    static let shared = ImageCacheManager()
    
    private let memoryCache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    // Prefetch queue for background image loading
    private let prefetchQueue = DispatchQueue(label: "com.campuslink.imageprefetch", qos: .userInitiated, attributes: .concurrent)
    
    private init() {
        // Configure memory cache
        memoryCache.countLimit = 100 // Cache up to 100 images in memory
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50 MB memory limit
        
        // Setup disk cache directory
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("ImageCache")
        
        // Create cache directory if it doesn't exist
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // Clear old cache on init (keep last 7 days)
        clearOldCache(olderThan: 7 * 24 * 60 * 60) // 7 days in seconds
    }
    
    // MARK: - Cache Key Generation
    
    private func cacheKey(for urlString: String) -> String {
        return urlString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? urlString
    }
    
    private func diskCacheURL(for key: String) -> URL {
        return cacheDirectory.appendingPathComponent(key.replacingOccurrences(of: "/", with: "_"))
    }
    
    // MARK: - Get Image (Memory → Disk → Network)
    
    func getImage(for urlString: String) async -> UIImage? {
        let key = cacheKey(for: urlString)
        
        // 1. Check memory cache first (fastest)
        if let cachedImage = memoryCache.object(forKey: key as NSString) {
            #if DEBUG
            print("📸 ImageCache: HIT (memory) - \(urlString)")
            #endif
            return cachedImage
        }
        
        // 2. Check disk cache (fast)
        if let diskImage = loadFromDisk(key: key) {
            #if DEBUG
            print("📸 ImageCache: HIT (disk) - \(urlString)")
            #endif
            // Store in memory for next time
            memoryCache.setObject(diskImage, forKey: key as NSString)
            return diskImage
        }
        
        // 3. Download from network (slow)
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            #if DEBUG
            print("📸 ImageCache: MISS (downloading) - \(urlString)")
            #endif
            
            let (data, _) = try await URLSession.shared.data(from: url)
            
            guard let image = UIImage(data: data) else { return nil }
            
            // Cache in both memory and disk
            memoryCache.setObject(image, forKey: key as NSString)
            saveToDisk(image: image, key: key)
            
            #if DEBUG
            print("📸 ImageCache: CACHED - \(urlString)")
            #endif
            
            return image
        } catch {
            #if DEBUG
            print("❌ ImageCache: FAILED - \(urlString) - \(error)")
            #endif
            return nil
        }
    }
    
    // MARK: - Disk Operations
    
    private func loadFromDisk(key: String) -> UIImage? {
        let fileURL = diskCacheURL(for: key)
        guard let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }
        return image
    }
    
    private func saveToDisk(image: UIImage, key: String) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        let fileURL = diskCacheURL(for: key)
        try? data.write(to: fileURL)
    }
    
    // MARK: - Prefetching
    
    /// Prefetch images in background for upcoming listings
    func prefetchImages(urls: [String]) {
        for urlString in urls {
            let key = cacheKey(for: urlString)
            
            // Skip if already in memory cache
            if memoryCache.object(forKey: key as NSString) != nil {
                continue
            }
            
            // Prefetch in background
            prefetchQueue.async {
                Task {
                    _ = await self.getImage(for: urlString)
                }
            }
        }
    }
    
    // MARK: - Cache Management
    
    /// Clear all cached images
    func clearCache() {
        memoryCache.removeAllObjects()
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        #if DEBUG
        print("📸 ImageCache: CLEARED")
        #endif
    }
    
    /// Clear cache older than specified seconds
    private func clearOldCache(olderThan seconds: TimeInterval) {
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return
        }
        
        let cutoffDate = Date(timeIntervalSinceNow: -seconds)
        
        for fileURL in files {
            guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                  let modificationDate = attributes[.modificationDate] as? Date else {
                continue
            }
            
            if modificationDate < cutoffDate {
                try? fileManager.removeItem(at: fileURL)
            }
        }
    }
    
    /// Get cache size in bytes
    func getCacheSize() -> Int {
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        
        return files.reduce(0) { totalSize, fileURL in
            guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                  let fileSize = attributes[.size] as? Int else {
                return totalSize
            }
            return totalSize + fileSize
        }
    }
}

/// SwiftUI View for cached images
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: String?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @State private var image: UIImage?
    @State private var isLoading = false
    
    init(
        url: String?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let image = image {
                content(Image(uiImage: image))
            } else {
                placeholder()
                    .onAppear {
                        loadImage()
                    }
            }
        }
    }
    
    private func loadImage() {
        guard let urlString = url, !isLoading else { return }
        
        isLoading = true
        
        Task {
            let loadedImage = await ImageCacheManager.shared.getImage(for: urlString)
            
            await MainActor.run {
                self.image = loadedImage
                isLoading = false
            }
        }
    }
}


