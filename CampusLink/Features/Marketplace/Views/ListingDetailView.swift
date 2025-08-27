import SwiftUI

struct ListingDetailView: View {
    let listing: ListingWithUser
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager

    @StateObject private var paymentService = PaymentService.shared
    @StateObject private var conversationViewModel = ConversationListViewModel()

    @State private var isContactingSeller = false
    @State private var isPrimaryActionLoading = false
    @State private var purchaseError: String?
    @State private var showErrorAlert = false
    @State private var activeSheet: ActiveSheet?          // <- single entry point for all sheets

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
                            .overlay(ProgressView())
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

                // Title and Price
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

                // Service-Specific
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

                // Description
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(listing.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineSpacing(4)
                }

                // Seller Info
                VStack(alignment: .leading, spacing: 12) {
                    Text("Seller Information")
                        .font(.headline)
                        .foregroundColor(.primary)

                    HStack(spacing: 12) {
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

                // Listing Details
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

                // Actions
                ActionButtonRow(
                    listing: listing,
                    isOwnListing: isOwnListing,
                    isContactingLoading: isContactingSeller,
                    isPrimaryActionLoading: isPrimaryActionLoading,
                    onContactSeller: { handleContactSeller() },
                    onPrimaryAction: { handlePrimaryAction() }
                )

                Spacer(minLength: 100)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    if !isOwnListing {
                        Button {
                            activeSheet = .report(
                                userId: listing.user.id,
                                userName: listing.user.name ?? "Unknown User",
                                listingId: listing.id.uuidString,
                                listingTitle: listing.title
                            )
                        } label: {
                            Image(systemName: "flag").foregroundColor(.red)
                        }
                    }

                    Button("Done") { dismiss() }
                }
            }
        }

        // Single sheet router
        .sheet(item: $activeSheet, onDismiss: sheetDidDismiss) { sheet in
            switch sheet {
            case let .report(userId, userName, listingId, listingTitle):
                ReportUserView(
                    userId: userId,
                    userName: userName,
                    listingId: listingId,
                    listingTitle: listingTitle
                )
                .environmentObject(authManager)

            case .purchaseConfirmation:
                PurchaseConfirmationView(
                    listing: listing,
                    paymentResult: paymentService.paymentResult,
                    onDismiss: {
                        activeSheet = nil
                        let wasCompleted: Bool = {
                            if case .completed? = paymentService.paymentResult { return true }
                            return false
                        }()
                        // Clear Stripe state
                        paymentService.paymentResult = nil
                        paymentService.paymentSheet = nil
                        if wasCompleted { dismiss() }
                    },
                    onViewTransactions: {
                        AppRouter.shared.pushTransactions()
                    }
                )

            case let .chat(conversation):
                ChatView(conversation: conversation)
            }
        }

        .alert("Payment Error", isPresented: $showErrorAlert) {
            Button("OK") { purchaseError = nil }
        } message: {
            Text(purchaseError ?? "An unknown error occurred")
        }

        .onAppear {
            // Clear any stale payment state when view appears
            paymentService.paymentResult = nil
            paymentService.paymentSheet = nil
            activeSheet = nil  // Ensure no sheet is shown on appear
        }
        .onDisappear {
            // Clear to prevent re-triggering elsewhere
            paymentService.paymentResult = nil
            paymentService.paymentSheet = nil
            activeSheet = nil  // Clear sheet state
        }
    }

    // MARK: - Helpers

    private func sheetDidDismiss() {
        // Safety: ensure Stripe state is cleared whenever any sheet goes away
        paymentService.paymentResult = nil
        paymentService.paymentSheet = nil
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func handleContactSeller() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        isContactingSeller = true

        Task {
            if let userId = authManager.session?.user.id.uuidString {
                await conversationViewModel.initialize(userId: userId)

                if let conversation = await conversationViewModel.getOrCreateConversation(for: listing) {
                    await MainActor.run {
                        isContactingSeller = false
                        activeSheet = .chat(conversation)
                        #if DEBUG
                        print("✅ Opening chat for listing: \(listing.title)")
                        #endif
                    }
                } else {
                    await MainActor.run {
                        isContactingSeller = false
                        purchaseError = "Failed to start conversation. Please try again."
                        showErrorAlert = true
                        #if DEBUG
                        print("❌ Failed to create/find conversation for listing: \(listing.title)")
                        #endif
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
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()

        isPrimaryActionLoading = true

        if listing.listingType == .product {
            Task {
                do {
                    try await paymentService.configurePaymentSheet(for: listing.id.uuidString)

                    await MainActor.run {
                        isPrimaryActionLoading = false

                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let rootVC = windowScene.windows.first?.rootViewController {
                            Task { @MainActor in
                                paymentService.presentPaymentSheet(from: rootVC)

                                // Wait briefly for result to populate
                                try? await Task.sleep(nanoseconds: 500_000_000)

                                if let _ = paymentService.paymentResult {
                                    // Consume/clear first, then show confirmation
                                    // (prevents re-trigger on next appear)
                                    // Keep the result available to the sheet; it will clear on dismiss.
                                    activeSheet = .purchaseConfirmation
                                }
                            }
                        }
                    }
                } catch {
                    await MainActor.run {
                        isPrimaryActionLoading = false
                        purchaseError = error.localizedDescription
                        showErrorAlert = true
                        #if DEBUG
                        print("❌ Failed to create payment intent: \(error)")
                        #endif
                    }
                }
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isPrimaryActionLoading = false
                #if DEBUG
                print("📅 Book service: \(listing.title)")
                if let duration = listing.serviceDuration { print("   Duration: \(duration)") }
                if let location = listing.serviceLocation { print("   Location: \(location.displayName)") }
                #endif
            }
        }
    }
}

// MARK: - Sheet Router

enum ActiveSheet: Identifiable {
    case report(userId: String, userName: String, listingId: String, listingTitle: String)
    case purchaseConfirmation
    case chat(Conversation)

    var id: String {
        switch self {
        case let .report(userId, _, listingId, _): return "report:\(userId):\(listingId)"
        case .purchaseConfirmation: return "purchaseConfirmation"
        case let .chat(conversation): return "chat:\(conversation.id)"
        }
    }
}

// MARK: - Support Views

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
