import UIKit

extension UIImage {
    /// Resizes the image to fit within the specified maximum dimension while maintaining aspect ratio
    /// - Parameters:
    ///   - maxDimension: The maximum width or height (whichever is larger)
    ///   - compressionQuality: JPEG compression quality (0.0 to 1.0)
    /// - Returns: Resized image data or nil if resizing fails
    func resizedForUpload(maxDimension: CGFloat = 1080, compressionQuality: CGFloat = 0.8) -> Data? {
        // Don't resize if already small enough
        let currentMaxDimension = max(self.size.width, self.size.height)
        if currentMaxDimension <= maxDimension {
            return self.jpegData(compressionQuality: compressionQuality)
        }
        
        // Calculate new size maintaining aspect ratio
        let scale = maxDimension / currentMaxDimension
        let newWidth = self.size.width * scale
        let newHeight = self.size.height * scale
        let newSize = CGSize(width: newWidth, height: newHeight)
        
        // Create graphics context and draw resized image
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        self.draw(in: CGRect(origin: .zero, size: newSize))
        
        guard let resizedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            return nil
        }
        
        return resizedImage.jpegData(compressionQuality: compressionQuality)
    }
    
    /// Resizes the image for profile pictures (smaller dimension)
    func resizedForProfile(maxDimension: CGFloat = 500, compressionQuality: CGFloat = 0.9) -> Data? {
        return resizedForUpload(maxDimension: maxDimension, compressionQuality: compressionQuality)
    }
    
    /// Resizes the image for thumbnails (very small)
    func resizedForThumbnail(maxDimension: CGFloat = 200, compressionQuality: CGFloat = 0.7) -> Data? {
        return resizedForUpload(maxDimension: maxDimension, compressionQuality: compressionQuality)
    }
    
    /// Returns the approximate file size reduction percentage
    func sizeReductionPercentage(originalData: Data, resizedData: Data) -> Int {
        let originalSize = Double(originalData.count)
        let resizedSize = Double(resizedData.count)
        let reduction = ((originalSize - resizedSize) / originalSize) * 100
        return Int(reduction)
    }
}
