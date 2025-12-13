import SwiftUI
import Photos
import SCSDKCreativeKit

struct ShareListingSheet: View {
    let listingId: String
    let listingTitle: String
    let listingDescription: String
    let listingPrice: String
    let listingImageURL: String?
    @Binding var isPresented: Bool
    @Environment(\.dismiss) var dismiss
    
    @State private var isGeneratingImage = false
    @State private var showingSavedAlert = false
    @State private var savedAlertMessage = ""
    @State private var pendingAppToOpen: String? = nil
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Success header
                VStack(spacing: 16) {
                    // Animated checkmark circle
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.1))
                            .frame(width: 80, height: 80)
                        
                        Circle()
                            .fill(Color.green)
                            .frame(width: 64, height: 64)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 32)
                    
                    VStack(spacing: 8) {
                        Text("Posted Successfully!")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Share your listing with others")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 32)
                
                // Share options
                if isGeneratingImage {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Preparing sticker...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: 100)
                    .padding(.horizontal, 20)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ShareOptionRow(
                                icon: "camera.fill",
                                iconColor: .purple,
                                title: "Instagram Stories",
                                subtitle: "Share as a customizable sticker"
                            ) {
                                shareToInstagramStories()
                            }
                            
                            Divider()
                                .padding(.leading, 72)
                            
                        ShareOptionRow(
                            icon: "camera.fill",
                            iconColor: Color(hex: "FFFC00"),
                            title: "Snapchat Stories",
                            subtitle: "Share as a sticker"
                        ) {
                            shareToSnapchatStory()
                        }
                            
                            Divider()
                                .padding(.leading, 72)
                            
                            ShareOptionRow(
                                icon: "square.and.arrow.up",
                                iconColor: .blue,
                                title: "Share via iOS Share Sheet",
                                subtitle: "Share to Messages, Instagram, etc."
                            ) {
                                shareViaSystemSheet()
                            }
                            
                            Divider()
                                .padding(.leading, 72)
                            
                            ShareOptionRow(
                                icon: "link",
                                iconColor: .orange,
                                title: "Copy Link",
                                subtitle: "Copy listing link to clipboard"
                            ) {
                                copyLink()
                            }
                            
                            Divider()
                                .padding(.leading, 72)
                            
                            ShareOptionRow(
                                icon: "message.fill",
                                iconColor: .green,
                                title: "Share via Messages",
                                subtitle: "Send to your contacts"
                            ) {
                                shareViaMessages()
                            }
                            
                            Divider()
                                .padding(.leading, 72)
                            
                            ShareOptionRow(
                                icon: "doc.on.doc",
                                iconColor: .purple,
                                title: "Copy Text",
                                subtitle: "Copy listing details"
                            ) {
                                copyText()
                            }
                        }
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                    }
                }
                
                Spacer()
                
                // Done button
                Button(action: {
                    isPresented = false
                }) {
                    Text("Done")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.blue)
                        .cornerRadius(16)
                        .padding(.horizontal, 20)
                }
                .padding(.bottom, 32)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.title3)
                    }
                }
            }
            .alert("Sticker Ready", isPresented: $showingSavedAlert) {
                if let appScheme = pendingAppToOpen, let url = URL(string: appScheme) {
                    Button("Open App") {
                        UIApplication.shared.open(url)
                        pendingAppToOpen = nil
                    }
                    Button("Done", role: .cancel) {
                        pendingAppToOpen = nil
                    }
                } else {
                    Button("OK", role: .cancel) { }
                }
            } message: {
                Text(savedAlertMessage)
            }
        }
    }
    
    // MARK: - Share Handlers
    
    private func shareToInstagramStories() {
        // Facebook App ID is required for Instagram Stories sticker sharing
        // Get yours at: https://developers.facebook.com
        // Once you have it, replace this placeholder:
        let facebookAppID = "YOUR_FACEBOOK_APP_ID"  // TODO: Replace with real App ID
        
        // Check if we have a real Facebook App ID configured
        let hasValidAppID = facebookAppID != "YOUR_FACEBOOK_APP_ID" && !facebookAppID.isEmpty
        
        Task {
            isGeneratingImage = true
            
            guard let stickerImage = await generateStickerImage() else {
                isGeneratingImage = false
                return
            }
            
            guard let imageData = stickerImage.pngData() else {
                isGeneratingImage = false
                return
            }
            
            await MainActor.run {
                isGeneratingImage = false
                
                if hasValidAppID {
                    // Direct Instagram Stories sharing with sticker pre-loaded
                    let urlString = "instagram-stories://share?source_application=\(facebookAppID)"
                    guard let url = URL(string: urlString) else { return }
                    
                    if UIApplication.shared.canOpenURL(url) {
                        // Set up pasteboard with sticker and link
                        let pasteboardItems: [String: Any] = [
                            "com.instagram.sharedSticker.stickerImage": imageData,
                            "com.instagram.sharedSticker.backgroundTopColor": "#1a1a1a",
                            "com.instagram.sharedSticker.backgroundBottomColor": "#000000",
                            "com.instagram.sharedSticker.contentURL": generateShareURL().absoluteString
                        ]
                        
                        let pasteboardOptions: [UIPasteboard.OptionsKey: Any] = [
                            .expirationDate: Date().addingTimeInterval(60 * 5)
                        ]
                        
                        UIPasteboard.general.setItems([pasteboardItems], options: pasteboardOptions)
                        UIApplication.shared.open(url)
                        print("✅ Instagram Stories opened with sticker and link")
                    } else {
                        // Instagram not installed - fallback to save
                        saveImageAndOpenApp(image: stickerImage, appScheme: "instagram://app", appName: "Instagram")
                    }
                } else {
                    // No Facebook App ID - fallback to save to camera roll
                    print("⚠️ No Facebook App ID configured - using camera roll fallback")
                    saveImageAndOpenApp(image: stickerImage, appScheme: "instagram://app", appName: "Instagram")
                }
            }
        }
    }
    
    private func shareToSnapchatStory() {
        Task {
            isGeneratingImage = true
            print("🚀 Starting Snapchat share...")
            
            guard let stickerImage = await generateStickerImage() else {
                print("❌ Sticker generation failed")
                await MainActor.run {
                    isGeneratingImage = false
                    savedAlertMessage = "Failed to prepare sticker. Please try again."
                    showingSavedAlert = true
                }
                return
            }
            
            await MainActor.run {
                print("📤 Sending to Snapchat...")
                
                // Try Snap Kit SDK first
                let photo = SCSDKSnapPhoto(image: stickerImage)
                let sticker = SCSDKSnapSticker(stickerImage: stickerImage)
                let content = SCSDKPhotoSnapContent(snapPhoto: photo)
                content.sticker = sticker
                content.attachmentUrl = generateShareURL().absoluteString
                
                let snapAPI = SCSDKSnapAPI()
                
                // Set timeout - if SDK doesn't respond in 2 seconds, use fallback
                var didRespond = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    if !didRespond && self.isGeneratingImage {
                        print("⏱️ Snap SDK timeout - using camera roll method")
                        self.isGeneratingImage = false
                        self.saveImageAndOpenApp(image: stickerImage, appScheme: "snapchat://", appName: "Snapchat")
                    }
                }
                
                // Try SDK
                snapAPI.startSending(content) { error in
                    didRespond = true
                    DispatchQueue.main.async {
                        self.isGeneratingImage = false
                        if let error = error {
                            print("❌ Snapchat SDK error: \(error.localizedDescription)")
                            print("📱 Falling back to camera roll...")
                            self.saveImageAndOpenApp(image: stickerImage, appScheme: "snapchat://", appName: "Snapchat")
                        } else {
                            print("✅ Snapchat opened directly via SDK!")
                        }
                    }
                }
            }
        }
    }
    
    /// Save image to camera roll and open the specified app
    private func saveImageAndOpenApp(image: UIImage, appScheme: String, appName: String) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                if status == .authorized || status == .limited {
                    // Save to camera roll
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetChangeRequest.creationRequestForAsset(from: image)
                    }) { success, error in
                        DispatchQueue.main.async {
                            if success {
                                // Try to open the app
                                if let url = URL(string: appScheme), UIApplication.shared.canOpenURL(url) {
                                    self.savedAlertMessage = "Sticker saved to Photos! \(appName) is opening - add it from your camera roll."
                                    self.pendingAppToOpen = appScheme
                                    self.showingSavedAlert = true
                                } else {
                                    self.savedAlertMessage = "Sticker saved to Photos! Open \(appName) and add it from your camera roll."
                                    self.showingSavedAlert = true
                                }
                                print("✅ Sticker saved to Photos")
                            } else {
                                self.savedAlertMessage = "Failed to save sticker. Please try again."
                                self.showingSavedAlert = true
                                print("❌ Failed to save: \(error?.localizedDescription ?? "unknown")")
                            }
                        }
                    }
                } else {
                    self.savedAlertMessage = "Please allow access to Photos in Settings to save stickers."
                    self.showingSavedAlert = true
                }
            }
        }
    }
    
    private func shareStickerGeneric() {
        Task {
            isGeneratingImage = true
            guard let stickerImage = await generateStickerImage() else {
                isGeneratingImage = false
                return
            }
            
            await MainActor.run {
                isGeneratingImage = false
                let shareURL = generateShareURL()
                // We share both the image and the URL. Apps will decide which to use.
                let activityVC = UIActivityViewController(
                    activityItems: [stickerImage, shareURL],
                    applicationActivities: nil
                )
                presentActivityVC(activityVC)
            }
        }
    }
    
    private func shareViaSystemSheet() {
        let shareURL = generateShareURL()
        let text = generateShareText()
        let activityVC = UIActivityViewController(
            activityItems: [text, shareURL],
            applicationActivities: nil
        )
        presentActivityVC(activityVC)
    }
    
    private func presentActivityVC(_ activityVC: UIActivityViewController) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            // Find the topmost view controller
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            activityVC.popoverPresentationController?.sourceView = topVC.view
            activityVC.popoverPresentationController?.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 0, height: 0)
            activityVC.popoverPresentationController?.permittedArrowDirections = []
            topVC.present(activityVC, animated: true)
        }
    }
    
    private func copyLink() {
        let shareURL = generateShareURL()
        UIPasteboard.general.string = shareURL.absoluteString
        
        // Show confirmation
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        print("✅ Link copied to clipboard: \(shareURL.absoluteString)")
    }
    
    private func shareViaMessages() {
        let shareURL = generateShareURL()
        let message = "\(generateShareText())\n\n\(shareURL.absoluteString)"
        let encodedText = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? message
        
        if let url = URL(string: "sms:&body=\(encodedText)") {
            UIApplication.shared.open(url)
        }
    }
    
    private func copyText() {
        let text = generateShareText()
        UIPasteboard.general.string = text
        
        // Show confirmation
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        print("✅ Text copied to clipboard")
    }
    
    private func generateShareText() -> String {
        return "checkout my post on campuslink: \(listingTitle) | \(listingPrice)"
    }
    
    private func generateShareURL() -> URL {
        // Simple App Store link with listing ID
        // iOS will try to open the app if installed, otherwise goes to App Store
        return URL(string: "https://apps.apple.com/us/app/campuslink-student-market/id6751429664")!
    }
    
    // MARK: - Sticker Generation
    
    @MainActor
    private func generateStickerImage() async -> UIImage? {
        print("🎨 Starting sticker generation...")
        
        // 1. Download image if available (with timeout)
        var listingImage: UIImage?
        if let urlString = listingImageURL, let url = URL(string: urlString) {
            do {
                print("📥 Downloading image from: \(url)")
                
                // Add timeout to prevent hanging
                var request = URLRequest(url: url)
                request.timeoutInterval = 5.0  // 5 second timeout
                
                let (data, _) = try await URLSession.shared.data(for: request)
                listingImage = UIImage(data: data)
                print("✅ Image downloaded successfully")
            } catch {
                print("⚠️ Image download failed (will use placeholder): \(error.localizedDescription)")
                // Continue without image - use gradient placeholder
            }
        } else {
            print("📝 No image URL - using gradient placeholder")
        }
        
        // 2. Create View
        print("🖼️ Creating sticker view...")
        let stickerView = ListingStickerView(
            title: listingTitle,
            price: listingPrice,
            description: listingDescription,
            image: listingImage
        )
        
        // 3. Render with timeout protection
        print("🎨 Rendering sticker image...")
        if #available(iOS 16.0, *) {
            let renderer = ImageRenderer(content: stickerView)
            renderer.scale = UIScreen.main.scale
            
            // Force synchronous rendering to avoid async issues
            if let image = renderer.uiImage {
                print("✅ Sticker generated successfully!")
                return image
            } else {
                print("❌ Failed to render sticker view")
                return nil
            }
        } else {
            print("⚠️ iOS 15 fallback - using listing image only")
            return listingImage
        }
    }
}

struct ShareOptionRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.1))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(iconColor)
                }
                
                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
}

// Color extension for hex colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// Preview
struct ShareListingSheet_Previews: PreviewProvider {
    static var previews: some View {
        ShareListingSheet(
            listingId: "123e4567-e89b-12d3-a456-426614174000",
            listingTitle: "iPhone 13 Pro Max",
            listingDescription: "256GB, Space Gray, excellent condition",
            listingPrice: "$799.00",
            listingImageURL: "https://example.com/image.jpg",
            isPresented: .constant(true)
        )
    }
}

