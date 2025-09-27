import SwiftUI
import Supabase

// MARK: - Offer Insert Model
private struct OfferInsert: Encodable {
    let seek_listing_id: String
    let seller_id: String
    let seeker_id: String
    let price_cents: Int
    let message: String
    let status: String
}

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
    
    // Custom offer amount states
    @State private var offerAmount = ""
    @State private var showingKeypad = false
    @FocusState private var isAmountFocused: Bool
    
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
                            
                            // Offer amount input
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Your Offer Amount")
                                    .font(.headline)
                                
                                HStack {
                                    Text("$")
                                        .font(.title2)
                                        .foregroundColor(.secondary)
                                    
                                    TextField("0.00", text: $offerAmount)
                                        .font(.title)
                                        .fontWeight(.semibold)
                                        .keyboardType(.decimalPad)
                                        .focused($isAmountFocused)
                                        .onChange(of: offerAmount) { newValue in
                                            // Format the input as currency
                                            let filtered = newValue.filter { "0123456789.".contains($0) }
                                            let parts = filtered.split(separator: ".")
                                            if parts.count > 2 {
                                                // Multiple decimal points, use only first
                                                offerAmount = String(parts[0]) + "." + String(parts[1])
                                            } else if parts.count == 2 && parts[1].count > 2 {
                                                // Limit to 2 decimal places
                                                offerAmount = String(parts[0]) + "." + String(parts[1].prefix(2))
                                            } else {
                                                offerAmount = filtered
                                            }
                                        }
                                    
                                    Spacer()
                                    
                                    Button(action: { isAmountFocused = true }) {
                                        Image(systemName: "keyboard")
                                            .font(.title2)
                                            .foregroundColor(Color("ThemeColor"))
                                    }
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .onTapGesture {
                                    isAmountFocused = true
                                }
                                
                                // Budget guidance
                                if let budgetMin = seekListing.budgetMin, let budgetMax = seekListing.budgetMax {
                                    HStack {
                                        Image(systemName: "info.circle")
                                            .foregroundColor(.blue)
                                        Text("Seeker's budget: $\(budgetMin, specifier: "%.2f") - $\(budgetMax, specifier: "%.2f")")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                } else if let budgetMax = seekListing.budgetMax {
                                    HStack {
                                        Image(systemName: "info.circle")
                                            .foregroundColor(.blue)
                                        Text("Seeker's budget: Up to $\(budgetMax, specifier: "%.2f")")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
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
                                .background(offerAmount.isEmpty || Double(offerAmount) == nil || Double(offerAmount) == 0 ? Color.gray : Color("ThemeColor"))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(offerAmount.isEmpty || Double(offerAmount) == nil || Double(offerAmount) == 0 || isLoading)
                            .accessibilityLabel(offerAmount.isEmpty ? "Send offer button, disabled" : "Send offer")
                            .accessibilityHint(offerAmount.isEmpty ? "Enter an offer amount first to enable this button" : "Sends your offer to the seeker")
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
            // No need to load listings for seeking posts with custom amounts
            isLoadingListings = false
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
        guard let amount = Double(offerAmount), amount > 0 else {
            errorMessage = "Please enter a valid offer amount"
            return
        }
        guard let currentUserId = authManager.currentUserId else {
            errorMessage = "You must be logged in to make offers"
            return
        }
        
        Task {
            await createOfferWithPrice(
                seekListingId: seekListing.id,
                sellerId: currentUserId,
                seekerId: seekListing.user.id,
                priceCents: Int(amount * 100),
                message: message.isEmpty ? nil : message
            )
        }
    }
    
    private func createOfferWithPrice(
        seekListingId: UUID,
        sellerId: String,
        seekerId: String,
        priceCents: Int,
        message: String?
    ) async {
        await MainActor.run { isLoading = true; errorMessage = nil }
        
        do {
            // Create the offer with custom price
            let offer = OfferInsert(
                seek_listing_id: seekListingId.uuidString,
                seller_id: sellerId,
                seeker_id: seekerId,
                price_cents: priceCents,
                message: message ?? "",
                status: "pending"
            )
            
            let response = try await supabase
                .from("offers")
                .insert(offer)
                .execute()
            
            print("✅ Offer inserted successfully")
            
            // Send a message with the offer details
            await createOfferMessage(
                seekListingId: seekListingId,
                sellerId: sellerId,
                seekerId: seekerId,
                priceCents: priceCents,
                customMessage: message
            )
            
            await MainActor.run {
                isLoading = false
                // Analytics: Track offer creation
                print("📊 Analytics: Offer created - Seek: \(seekListingId), Price: $\(Double(priceCents) / 100)")
                dismiss()
            }
            
        } catch {
            await MainActor.run {
                let errorDesc = error.localizedDescription
                if errorDesc.contains("price_cents") || errorDesc.contains("column") {
                    errorMessage = "Database setup required. Please run the offers migration script in Supabase first."
                } else if errorDesc.contains("format") {
                    errorMessage = "Database schema mismatch. Please check if the offers table is up to date."
                } else {
                    errorMessage = "Failed to send offer: \(errorDesc)"
                }
                isLoading = false
                
                #if DEBUG
                print("❌ Offer creation failed: \(error)")
                #endif
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
    
    private func createOfferMessage(
        seekListingId: UUID,
        sellerId: String,
        seekerId: String,
        priceCents: Int,
        customMessage: String?
    ) async {
        do {
            // First, find or create conversation
            let existingConversations: [Conversation] = try await supabase
                .from("conversations")
                .select("*")
                .eq("listing_id", value: seekListingId.uuidString)
                .eq("buyer_id", value: seekerId)
                .eq("seller_id", value: sellerId)
                .execute()
                .value
            
            let conversation: Conversation
            if let existing = existingConversations.first {
                conversation = existing
            } else {
                // Create new conversation
                let newConversation = [
                    "listing_id": seekListingId.uuidString,
                    "buyer_id": seekerId,
                    "seller_id": sellerId
                ]
                
                let created: [Conversation] = try await supabase
                    .from("conversations")
                    .insert(newConversation)
                    .execute()
                    .value
                
                guard let firstCreated = created.first else { return }
                conversation = firstCreated
            }
            
            // Create the offer notification message
            let offerAmount = Double(priceCents) / 100.0
            var messageContent = "💰 New Offer: $\(String(format: "%.2f", offerAmount)) for \"\(seekListing.title)\""
            
            if let customMessage = customMessage, !customMessage.isEmpty {
                messageContent += "\n\nMessage from seller:\n\(customMessage)"
            }
            
            messageContent += "\n\n🔗 Accept this offer in your messages or wallet to proceed with purchase."
            
            let message = [
                "conversation_id": conversation.id.uuidString,
                "sender_id": sellerId,
                "content": messageContent,
                "message_type": "offer_notification"
            ]
            
            let _: [Message] = try await supabase
                .from("messages")
                .insert(message)
                .execute()
                .value
            
        } catch {
            #if DEBUG
            print("Failed to create offer message: \(error)")
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
                
                Text("$\((listing.price ?? 0), specifier: "%.2f")")
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
