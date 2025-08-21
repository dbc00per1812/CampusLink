import SwiftUI

struct ListingDetailView: View {
    let listing: ListingWithUser
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager
    @StateObject private var paymentService = PaymentService.shared
    @StateObject private var conversationViewModel = ConversationListViewModel()
    @State private var isContactingSeller = false
    @State private var isPrimaryActionLoading = false
    @State private var showPurchaseConfirmation = false
    @State private var purchaseError: String?
    @State private var showErrorAlert = false
    @State private var activeConversation: Conversation?
    @State private var showingChat = false
    @State private var showingReportSheet = false
    
    private var isOwnListing: Bool {
        guard let currentUserId = authManager.session?.user.id.uuidString else { return false }
        return listing.user.id == currentUserId
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Large Photo Section
                if let photoURL = listing.photo, let url = URL(string: photoURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color(UIColor.systemGray5))
                            .overlay(
                                ProgressView()
                            )
                    }
                    .frame(height: 300)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .cornerRadius(16)
                } else {
                    Rectangle()
                        .fill(Color(UIColor.systemGray6))
                        .frame(height: 300)
                        .overlay(
                            VStack {
                                Image(systemName: "photo")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                                Text("No Photo")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                            }
                        )
                        .cornerRadius(16)
                }
                
                // Title and Price Section
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(listing.title)
                                .font(.title)
                                .fontWeight(.bold)
                                .lineLimit(3)
                            
                            HStack {
                                Text(listing.category)
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color("ThemeColor").opacity(0.2))
                                    .foregroundColor(Color("ThemeColor"))
                                    .cornerRadius(8)
                                
                                Text(listing.listingType.displayName)
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(listing.listingType == .product ? Color.blue.opacity(0.2) : Color.green.opacity(0.2))
                                    .foregroundColor(listing.listingType == .product ? .blue : .green)
                                    .cornerRadius(8)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("$\(listing.price, specifier: "%.2f")")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(Color("ThemeColor"))
                            
                            if listing.isSold {
                                Text("SOLD")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.red)
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                            }
                        }
                    }
                }
                
                // Service-Specific Information
                if listing.listingType == .service {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Service Details")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 8) {
                            if let duration = listing.serviceDuration, !duration.isEmpty {
                                ServiceDetailRow(title: "Duration", value: duration, icon: "clock")
                            }
                            
                            if let location = listing.serviceLocation {
                                ServiceDetailRow(title: "Location", value: location.displayName, icon: "location")
                            }
                            
                            if let availability = listing.serviceAvailability, !availability.isEmpty {
                                ServiceDetailRow(title: "Availability", value: availability, icon: "calendar")
                            }
                        }
                    }
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                }
                
                // Description Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(listing.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineSpacing(4)
                }
                
                // Seller Information Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Seller Information")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 12) {
                        // Seller Profile Photo Placeholder
                        Circle()
                            .fill(Color("ThemeColor").opacity(0.2))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Text((listing.user.name?.first?.uppercased()) ?? "?")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(Color("ThemeColor"))
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(listing.user.name ?? "Unknown Seller")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text(listing.user.email ?? "")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("Member since \(formatDate(listing.createdAt))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                }
                
                // Listing Information
                VStack(alignment: .leading, spacing: 8) {
                    Text("Listing Details")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Text("Posted:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatDate(listing.createdAt))
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                }
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(12)
                
                // Action Buttons Section
                ActionButtonRow(
                    listing: listing,
                    isOwnListing: isOwnListing,
                    isContactingLoading: isContactingSeller,
                    isPrimaryActionLoading: isPrimaryActionLoading,
                    onContactSeller: {
                        handleContactSeller()
                    },
                    onPrimaryAction: {
                        handlePrimaryAction()
                    }
                )
                
                // Bottom spacing
                Spacer(minLength: 100)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    // Report button (only show if not own listing)
                    if !isOwnListing {
                        Button(action: {
                            showingReportSheet = true
                        }) {
                            Image(systemName: "flag")
                                .foregroundColor(.red)
                        }
                    }
                    
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingReportSheet) {
            ReportUserView(
                userId: listing.user.id,
                userName: listing.user.name ?? "Unknown User",
                listingId: listing.id.uuidString,
                listingTitle: listing.title
            )
            .environmentObject(authManager)
        }
        .sheet(isPresented: $showPurchaseConfirmation) {
            PurchaseConfirmationView(
                listing: listing,
                paymentResult: paymentService.paymentResult,
                onDismiss: {
                    showPurchaseConfirmation = false
                    // If payment was successful, dismiss the detail view too
                    if case .completed = paymentService.paymentResult {
                        dismiss()
                    }
                },
                onViewTransactions: {
                    AppRouter.shared.pushTransactions()
                }
            )
        }
        .alert("Payment Error", isPresented: $showErrorAlert) {
            Button("OK") {
                purchaseError = nil
            }
        } message: {
            Text(purchaseError ?? "An unknown error occurred")
        }
        .sheet(item: $activeConversation) { conversation in
            ChatView(conversation: conversation)
        }
        .onReceive(paymentService.$paymentResult) { result in
            if result != nil {
                showPurchaseConfirmation = true
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func handleContactSeller() {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        isContactingSeller = true
        
        Task {
            // Initialize view model with user ID if needed
            if let userId = authManager.session?.user.id.uuidString {
                await conversationViewModel.initialize(userId: userId)
                
                // Create or find conversation for this listing
                if let conversation = await conversationViewModel.getOrCreateConversation(for: listing) {
                    await MainActor.run {
                        isContactingSeller = false
                        activeConversation = conversation
                        showingChat = true
                        print("✅ Opening chat for listing: \(listing.title)")
                    }
                } else {
                    await MainActor.run {
                        isContactingSeller = false
                        purchaseError = "Failed to start conversation. Please try again."
                        showErrorAlert = true
                        print("❌ Failed to create/find conversation for listing: \(listing.title)")
                    }
                }
            } else {
                await MainActor.run {
                    isContactingSeller = false
                    purchaseError = "You must be logged in to contact the seller."
                    showErrorAlert = true
                }
            }
        }
    }
    
    private func handlePrimaryAction() {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        isPrimaryActionLoading = true
        
        if listing.listingType == .product {
            // Handle product purchase
            Task {
                do {
                    // Configure PaymentSheet with the listing
                    try await paymentService.configurePaymentSheet(for: listing.id.uuidString)
                    
                    // Present the Stripe PaymentSheet
                    await MainActor.run {
                        isPrimaryActionLoading = false
                        
                        // Present the PaymentSheet from the current view controller
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let rootViewController = windowScene.windows.first?.rootViewController {
                            paymentService.presentPaymentSheet(from: rootViewController)
                        }
                    }
                } catch {
                    await MainActor.run {
                        isPrimaryActionLoading = false
                        purchaseError = error.localizedDescription
                        showErrorAlert = true
                        print("❌ Failed to create payment intent: \(error)")
                    }
                }
            }
        } else {
            // Handle service booking
            // Simulate network delay for future implementation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isPrimaryActionLoading = false
                print("📅 Book service: \(listing.title)")
                if let duration = listing.serviceDuration {
                    print("   Duration: \(duration)")
                }
                if let location = listing.serviceLocation {
                    print("   Location: \(location.displayName)")
                }
                // TODO: Navigate to booking flow for services
            }
        }
    }
}

struct ServiceDetailRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(Color("ThemeColor"))
                .frame(width: 20)
            
            Text(title + ":")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }
}

struct ListingDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ListingDetailView(listing: ListingWithUser(
                id: UUID(),
                title: "Sample Product",
                description: "This is a sample product description that shows how the detail view will look when displaying product information.",
                price: 49.99,
                category: "Electronics",
                photo: nil,
                isSold: false,
                listingType: .product,
                serviceDuration: nil,
                serviceLocation: nil,
                serviceAvailability: nil,
                createdAt: Date(),
                user: UserProfile(id: UUID().uuidString, name: "Test User", bio: nil, profilePic: nil, email: "test@university.edu", createdAt: Date())
            ))
        }
        .environmentObject(AuthManager())
    }
}
