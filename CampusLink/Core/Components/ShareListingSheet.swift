import SwiftUI

struct ShareListingSheet: View {
    let listingId: String
    let listingTitle: String
    let listingDescription: String
    let listingPrice: String
    let listingImageURL: String?
    @Binding var isPresented: Bool
    @Environment(\.dismiss) var dismiss
    
    @State private var isGeneratingImage = false
    
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
                                icon: "photo.fill",
                                iconColor: .yellow,
                                title: "Share Sticker",
                                subtitle: "Snapchat, Messages, etc."
                            ) {
                                shareStickerGeneric()
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
        }
    }
    
    // MARK: - Share Handlers
    
    private func shareToInstagramStories() {
        guard let url = URL(string: "instagram-stories://share") else { return }
        
        if UIApplication.shared.canOpenURL(url) {
            Task {
                isGeneratingImage = true
                // defer { isGeneratingImage = false } // Don't defer, handle inside
                
                guard let stickerImage = await generateStickerImage() else {
                    isGeneratingImage = false
                    return
                }
                
                guard let imageData = stickerImage.pngData() else {
                    isGeneratingImage = false
                    return
                }
                
                // Create pasteboard items
                let pasteboardItems: [String: Any] = [
                    "com.instagram.sharedSticker.stickerImage": imageData,
                    "com.instagram.sharedSticker.backgroundTopColor": "#F5F5F5",
                    "com.instagram.sharedSticker.backgroundBottomColor": "#FFFFFF",
                    "com.instagram.sharedSticker.contentURL": generateShareURL().absoluteString
                ]
                
                // Set pasteboard options with expiration
                let pasteboardOptions: [UIPasteboard.OptionsKey: Any] = [
                    .expirationDate: Date().addingTimeInterval(60 * 5)
                ]
                
                await MainActor.run {
                    UIPasteboard.general.setItems([pasteboardItems], options: pasteboardOptions)
                    UIApplication.shared.open(url)
                    isGeneratingImage = false
                }
            }
        } else {
            // Fallback if Instagram is not installed
            print("Instagram not installed, showing alert or fallback")
            // Could show an alert here, but for simplicity just log
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
        // 1. Download image if available
        var listingImage: UIImage?
        if let urlString = listingImageURL, let url = URL(string: urlString) {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                listingImage = UIImage(data: data)
            } catch {
                print("Error downloading image for sticker: \(error)")
            }
        }
        
        // 2. Create View
        let stickerView = ListingStickerView(
            title: listingTitle,
            price: listingPrice,
            description: listingDescription,
            image: listingImage
        )
        
        // 3. Render
        if #available(iOS 16.0, *) {
            let renderer = ImageRenderer(content: stickerView)
            renderer.scale = UIScreen.main.scale
            return renderer.uiImage
        } else {
            // Fallback for iOS 15 (if needed, though ImageRenderer is preferred)
            // Since we are using modern SwiftUI, it's likely okay.
            // Simple fallback: return just the image or nil
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
