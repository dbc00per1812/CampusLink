import SwiftUI

struct ShareListingSheet: View {
    let listingTitle: String
    let listingDescription: String
    let listingPrice: String
    @Binding var isPresented: Bool
    @Environment(\.dismiss) var dismiss
    
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
                VStack(spacing: 0) {
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
    
    private func shareViaSystemSheet() {
        let text = generateShareText()
        let activityVC = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )
        
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
        // TODO: Replace with actual deep link when implemented
        let link = "campuslink://listing/\(listingTitle.replacingOccurrences(of: " ", with: "-"))"
        UIPasteboard.general.string = link
        
        // Show confirmation
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // You could show a toast here
        print("✅ Link copied to clipboard")
    }
    
    private func shareViaMessages() {
        let text = generateShareText()
        let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
        
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
        var text = "🎉 Check out my listing on CampusLink!\n\n"
        text += "📦 \(listingTitle)\n"
        if !listingDescription.isEmpty {
            text += "\(listingDescription)\n"
        }
        text += "\n💰 \(listingPrice)\n"
        text += "\n🔗 Get it on CampusLink!"
        return text
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
            listingTitle: "iPhone 13 Pro Max",
            listingDescription: "256GB, Space Gray, excellent condition",
            listingPrice: "$799.00",
            isPresented: .constant(true)
        )
    }
}

