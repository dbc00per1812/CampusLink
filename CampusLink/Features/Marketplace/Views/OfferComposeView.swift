import SwiftUI
import Supabase

struct OfferComposeView: View {
    let seekListing: ListingWithUser
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager
    
    @State private var selectedListing: ListingWithUser?
    @State private var message = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var myListings: [ListingWithUser] = []
    @State private var isLoadingListings = true
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if AppConfig.enableSeekMode {
                    // Full implementation will go here
                    ScrollView {
                        VStack(spacing: 20) {
                            // Seeker info section
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Responding to:")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    Text(seekListing.title)
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                    Spacer()
                                }
                                
                                if let budgetMin = seekListing.budgetMin, let budgetMax = seekListing.budgetMax {
                                    Text("Budget: $\(budgetMin, specifier: "%.2f") - $\(budgetMax, specifier: "%.2f")")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                } else if let budgetMax = seekListing.budgetMax {
                                    Text("Budget: Up to $\(budgetMax, specifier: "%.2f")")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                            
                            // Listing selection
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Select your listing to offer:")
                                    .font(.headline)
                                
                                if isLoadingListings {
                                    ProgressView("Loading your listings...")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                } else if myListings.isEmpty {
                                    Text("You don't have any active listings yet. Create one first to respond to this request.")
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                } else {
                                    // Listing selection grid/list
                                    ScrollView {
                                        LazyVStack(spacing: 8) {
                                            ForEach(myListings) { listing in
                                                ListingSelectionRow(
                                                    listing: listing,
                                                    isSelected: selectedListing?.id == listing.id
                                                ) {
                                                    selectedListing = listing
                                                }
                                            }
                                        }
                                    }
                                    .frame(maxHeight: 200)
                                }
                            }
                            
                            // Message input
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Message (optional)")
                                    .font(.headline)
                            TextField("Add a message to the seeker...", text: $message, axis: .vertical)
                                .lineLimit(3...6)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .accessibilityLabel("Message to seeker")
                                .accessibilityHint("Optional message to include with your offer")
                            }
                            
                            // Submit button
                            Button(action: submitOffer) {
                                HStack {
                                    if isLoading {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    }
                                    Text(isLoading ? "Sending Offer..." : "Send Offer")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(selectedListing == nil ? Color.gray : Color("ThemeColor"))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(selectedListing == nil || isLoading)
                            .accessibilityLabel(selectedListing == nil ? "Send offer button, disabled" : "Send offer")
                            .accessibilityHint(selectedListing == nil ? "Select a listing first to enable this button" : "Sends your selected item as an offer to the seeker")
                        }
                        .padding()
                    }
                } else {
                    // Feature disabled message
                    VStack(spacing: 20) {
                        Image(systemName: "hammer.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("Coming Soon")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("The ability to respond to wanted posts is currently under development.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Make an Offer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear {
            Task { await loadMyListings() }
        }
    }
    
    private func loadMyListings() async {
        guard let userId = authManager.currentUserId else { 
            await MainActor.run {
                errorMessage = "You must be logged in to make offers"
                isLoadingListings = false
            }
            return 
        }
        
        do {
            let response: [ListingWithUser] = try await supabase
                .from("listings")
                .select("*, user:users(*)")
                .eq("user_id", value: userId)
                .eq("intent", value: "offer")
                .eq("status", value: "active")
                .neq("archived", value: true)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            await MainActor.run {
                myListings = response
                isLoadingListings = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load your listings: \(error.localizedDescription)"
                isLoadingListings = false
            }
        }
    }
    
    private func submitOffer() {
        guard AppConfig.enableSeekMode else { return }
        guard let selectedListing = selectedListing else { return }
        guard let currentUserId = authManager.currentUserId else {
            errorMessage = "You must be logged in to make offers"
            return
        }
        
        Task {
            await createOffer(
                seekListingId: seekListing.id,
                offerListingId: selectedListing.id,
                sellerId: currentUserId,
                seekerId: seekListing.user.id,
                message: message.isEmpty ? nil : message
            )
        }
    }
    
    private func createOffer(
        seekListingId: UUID,
        offerListingId: UUID,
        sellerId: String,
        seekerId: String,
        message: String?
    ) async {
        await MainActor.run { isLoading = true; errorMessage = nil }
        
        do {
            // Create the offer in the database
            let offer = [
                "seek_listing_id": seekListingId.uuidString,
                "offer_listing_id": offerListingId.uuidString,
                "seller_id": sellerId,
                "seeker_id": seekerId,
                "message": message ?? "",
                "status": "pending"
            ]
            
            let _: [Offer] = try await supabase
                .from("offers")
                .insert(offer)
                .execute()
                .value
            
            // Find or create conversation between seller and seeker
            await createOrFindConversation(
                listingId: seekListingId,
                buyerId: seekerId,
                sellerId: sellerId
            )
            
            await MainActor.run {
                isLoading = false
                // Analytics: Track offer creation
                print("📊 Analytics: Offer created - Seek: \(seekListingId), Offer: \(offerListingId)")
                dismiss()
            }
            
        } catch {
            await MainActor.run {
                errorMessage = "Failed to send offer: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    private func createOrFindConversation(listingId: UUID, buyerId: String, sellerId: String) async {
        do {
            // Check if conversation already exists
            let existingConversations: [Conversation] = try await supabase
                .from("conversations")
                .select("*")
                .eq("listing_id", value: listingId.uuidString)
                .eq("buyer_id", value: buyerId)
                .eq("seller_id", value: sellerId)
                .execute()
                .value
            
            if existingConversations.isEmpty {
                // Create new conversation
                let newConversation = [
                    "listing_id": listingId.uuidString,
                    "buyer_id": buyerId,
                    "seller_id": sellerId
                ]
                
                let _: [Conversation] = try await supabase
                    .from("conversations")
                    .insert(newConversation)
                    .execute()
                    .value
            }
            
        } catch {
            #if DEBUG
            print("Failed to create/find conversation: \(error)")
            #endif
        }
    }
}

// MARK: - Supporting Views

struct ListingSelectionRow: View {
    let listing: ListingWithUser
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Listing thumbnail (if available)
            AsyncImage(url: listing.photo.flatMap(URL.init)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }
            .frame(width: 50, height: 50)
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(listing.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Text("$\(listing.price, specifier: "%.2f")")
                    .font(.subheadline)
                    .foregroundColor(Color("ThemeColor"))
                    .fontWeight(.semibold)
                
                Text(listing.category)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color("ThemeColor"))
                    .font(.title2)
            } else {
                Image(systemName: "circle")
                    .foregroundColor(.gray)
                    .font(.title2)
            }
        }
        .padding()
        .background(isSelected ? Color("ThemeColor").opacity(0.1) : Color(.systemGray6))
        .cornerRadius(12)
        .onTapGesture {
            onTap()
        }
    }
}

struct OfferComposeView_Previews: PreviewProvider {
    static var previews: some View {
        OfferComposeView(seekListing: .sampleListing)
            .environmentObject(AuthManager())
    }
}
