import SwiftUI

struct AllMyOffersView: View {
    @EnvironmentObject private var authManager: AuthManager
    @StateObject private var offerService = UnifiedOfferService.shared
    @StateObject private var feeService = FeeCalculationService.shared
    
    @State private var sentOffers: [Offer] = []
    @State private var receivedOffers: [Offer] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedTab = 0
    @State private var selectedOffer: Offer?
    @State private var showingOfferDetail = false
    @State private var showingCounterSheet = false
    @State private var counterAmount: String = ""
    @State private var counterMessage: String = ""
    @State private var isSubmitting = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab Picker
            Picker("Offer Type", selection: $selectedTab) {
                Text("Received").tag(0)
                Text("Sent").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            // Content
            if isLoading {
                ProgressView("Loading offers...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                TabView(selection: $selectedTab) {
                    // Received Offers
                    receivedOffersView
                        .tag(0)
                    
                    // Sent Offers
                    sentOffersView
                        .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .navigationTitle("My Offers")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await loadOffers()
        }
        .task {
            await loadOffers()
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(isPresented: $showingCounterSheet) {
            counterOfferSheet
        }
    }
    
    // MARK: - Received Offers View
    
    private var receivedOffersView: some View {
        Group {
            if receivedOffers.isEmpty {
                emptyState(message: "No offers received yet", icon: "envelope")
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(receivedOffers) { offer in
                            OfferCard(
                                offer: offer,
                                userRole: .receiver,
                                onAccept: { acceptOffer(offer) },
                                onReject: { rejectOffer(offer) },
                                onCounter: { prepareCounterOffer(offer) },
                                onTap: { selectedOffer = offer; showingOfferDetail = true }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
    }
    
    // MARK: - Sent Offers View
    
    private var sentOffersView: some View {
        Group {
            if sentOffers.isEmpty {
                emptyState(message: "No offers sent yet", icon: "paperplane")
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(sentOffers) { offer in
                            OfferCard(
                                offer: offer,
                                userRole: .sender,
                                onAccept: nil,
                                onReject: nil,
                                onCounter: nil,
                                onTap: { selectedOffer = offer; showingOfferDetail = true }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private func emptyState(message: String, icon: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(message)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Counter Offer Sheet
    
    private var counterOfferSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let offer = selectedOffer {
                    // Original Offer
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Original Offer")
                            .font(.headline)
                        Text(offer.formattedPrice ?? "N/A")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(10)
                    
                    // Counter Amount
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Counter-Offer")
                            .font(.headline)
                        
                        HStack {
                            Text("$")
                                .foregroundColor(.secondary)
                            TextField("0.00", text: $counterAmount)
                                .keyboardType(.decimalPad)
                        }
                        .padding()
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(10)
                    }
                    
                    // Counter Message
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Message (Optional)")
                            .font(.headline)
                        
                        TextEditor(text: $counterMessage)
                            .frame(height: 100)
                            .padding(8)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(10)
                    }
                    
                    Spacer()
                    
                    // Submit Button
                    Button(action: submitCounterOffer) {
                        if isSubmitting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Submit Counter-Offer")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isValidCounterAmount ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .disabled(!isValidCounterAmount || isSubmitting)
                }
            }
            .padding()
            .navigationTitle("Counter Offer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingCounterSheet = false
                        counterAmount = ""
                        counterMessage = ""
                    }
                }
            }
        }
    }
    
    private var isValidCounterAmount: Bool {
        guard let amount = Double(counterAmount), amount > 0 else { return false }
        return true
    }
    
    // MARK: - Actions
    
    private func loadOffers() async {
        guard let currentUserId = authManager.currentUserId else {
            await MainActor.run {
                errorMessage = "You must be logged in to view offers"
                isLoading = false
            }
            return
        }
        
        do {
            let (sent, received) = try await offerService.getMyOffers(currentUserId: currentUserId)
            await MainActor.run {
                self.sentOffers = sent
                self.receivedOffers = received
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load offers: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    private func acceptOffer(_ offer: Offer) {
        guard let currentUserId = authManager.currentUserId else { return }
        
        Task {
            do {
                let order = try await offerService.acceptOffer(offerId: offer.id, currentUserId: currentUserId)
                print("✅ Offer accepted, order created: \(order.id)")
                await loadOffers()
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to accept offer: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func rejectOffer(_ offer: Offer) {
        guard let currentUserId = authManager.currentUserId else { return }
        
        Task {
            do {
                try await offerService.rejectOffer(offerId: offer.id, currentUserId: currentUserId)
                print("✅ Offer rejected")
                await loadOffers()
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to reject offer: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func prepareCounterOffer(_ offer: Offer) {
        selectedOffer = offer
        counterAmount = ""
        counterMessage = ""
        showingCounterSheet = true
    }
    
    private func submitCounterOffer() {
        guard let offer = selectedOffer,
              let currentUserId = authManager.currentUserId else {
            errorMessage = "Invalid counter-offer"
            return
        }
        
        guard let amountDouble = Double(counterAmount) else {
            errorMessage = "Invalid counter-offer amount"
            return
        }
        
        let amountCents = Int(amountDouble * 100)
        
        Task {
            await MainActor.run { isSubmitting = true }
            
            do {
                let counterOffer = try await offerService.counterOffer(
                    parentOfferId: offer.id,
                    amountCents: amountCents,
                    message: counterMessage.isEmpty ? nil : counterMessage,
                    currentUserId: currentUserId
                )
                
                print("✅ Counter-offer created: \(counterOffer.id)")
                
                await MainActor.run {
                    isSubmitting = false
                    showingCounterSheet = false
                    counterAmount = ""
                    counterMessage = ""
                }
                
                await loadOffers()
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to create counter-offer: \(error.localizedDescription)"
                    isSubmitting = false
                }
            }
        }
    }
}

// MARK: - Offer Card Component

struct OfferCard: View {
    let offer: Offer
    let userRole: OfferUserRole
    let onAccept: (() -> Void)?
    let onReject: (() -> Void)?
    let onCounter: (() -> Void)?
    let onTap: () -> Void
    
    @StateObject private var feeService = FeeCalculationService.shared
    
    private var statusColor: Color {
        switch offer.status {
        case "pending": return .orange
        case "accepted": return .green
        case "declined": return .red
        case "countered": return .blue
        default: return .gray
        }
    }
    
    private var statusText: String {
        if offer.isCounterOffer {
            return "Counter-Offer"
        }
        return offer.status.capitalized
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(offer.listingType == .seek ? "Seek Offer" : "Buyer Offer")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let price = offer.formattedPrice {
                        Text(price)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(Color("ThemeColor"))
                    }
                    
                    if let message = offer.message {
                        Text("\"\(message)\"")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(statusText)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(statusColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor.opacity(0.1))
                        .cornerRadius(6)
                    
                    Text(offer.createdAt, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Action Buttons (only for pending offers you received)
            if offer.status == "pending" && userRole == .receiver {
                HStack(spacing: 12) {
                    if let onAccept = onAccept {
                        Button(action: onAccept) {
                            Text("Accept")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.green)
                                .cornerRadius(8)
                        }
                    }
                    
                    if let onCounter = onCounter {
                        Button(action: onCounter) {
                            Text("Counter")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                    }
                    
                    if let onReject = onReject {
                        Button(action: onReject) {
                            Text("Reject")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.red)
                                .cornerRadius(8)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
        .onTapGesture {
            onTap()
        }
    }
}

// Preview
struct AllMyOffersView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AllMyOffersView()
                .environmentObject(AuthManager())
        }
    }
}

