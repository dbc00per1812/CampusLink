import SwiftUI
import Combine

/// A view that displays order confirmation and next steps after purchase.
/// Shows order details, escrow protection information, expected timeline, and navigation options.
struct PurchaseConfirmationView: View {
    let listing: ListingWithUser
    let order: Order?
    let paymentMethod: PaymentMethod
    let onDismiss: () -> Void
    let onViewOrder: (() -> Void)?
    let onContactSeller: (() -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var animationOffset: CGFloat = 50
    @State private var animationOpacity: Double = 0
    @State private var showingOrderDetails = false
    @State private var showingEscrowInfo = false
    
    private var orderId: String {
        order?.id.uuidString.prefix(8).description ?? "Processing..."
    }
    
    private var statusIcon: String {
        if order != nil {
            return "checkmark.circle.fill"
        } else {
            return "clock.circle"
        }
    }
    
    private var statusColor: Color {
        if order != nil {
            return .green
        } else {
            return .orange
        }
    }
    
    private var statusTitle: String {
        if order != nil {
            return "Order Confirmed!"
        } else {
            return "Processing Order..."
        }
    }
    
    private var statusMessage: String {
        if order != nil {
            return "Your order for \"\(listing.title)\" has been successfully created and is now protected by our escrow system."
        } else {
            return "Please wait while we process your order and set up escrow protection."
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    headerSection
                    
                    if let order = order {
                        orderDetailsSection(order: order)
                        verificationStepsSection
                    }
                    
                    escrowProtectionSection
                    actionButtonsSection
                }
                .padding(.vertical, 30)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        onDismiss()
                    }
                    .accessibilityLabel("Close confirmation view")
                }
            }
        }
        .sheet(isPresented: $showingOrderDetails) {
            if let order = order {
                OrderDetailView(order: order)
            }
        }
        .sheet(isPresented: $showingEscrowInfo) {
            EscrowInfoSheet()
        }
        .onAppear {
            animateIn()
            provideHapticFeedback()
        }
    }
    
    // MARK: - Computed Views
    
    private var headerSection: some View {
        VStack(spacing: 20) {
            // Status Icon with Animation
            Image(systemName: statusIcon)
                .font(.system(size: 80))
                .foregroundColor(statusColor)
                .padding()
                .scaleEffect(animationOpacity)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animationOpacity)
            
            // Status Title
            Text(statusTitle)
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            
            // Status Message
            Text(statusMessage)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
                .lineSpacing(4)
        }
        .opacity(animationOpacity)
        .offset(y: animationOffset)
    }
    
    private func orderDetailsSection(order: Order) -> some View {
        VStack(spacing: 20) {
            // Order ID Card
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "number.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                        .accessibilityHidden(true)
                    
                    Text("Order ID")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button("Copy") {
                        UIPasteboard.general.string = order.id.uuidString
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    .accessibilityLabel("Copy order ID to clipboard")
                }
                
                Text(order.id.uuidString)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .accessibilityLabel("Order ID: \(order.id.uuidString)")
            }
            .padding(20)
            .background(Color.blue.opacity(0.05))
            .cornerRadius(16)
            
            // Payment Method Card
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: paymentMethod.icon)
                        .foregroundColor(paymentMethod.color)
                        .font(.title2)
                        .accessibilityHidden(true)
                    
                    Text("Payment Method")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                }
                
                Text(paymentMethod.displayName)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            .padding(20)
            .background(Color.green.opacity(0.05))
            .cornerRadius(16)
            
            // Price Card - Show buyer price (what they paid)
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "dollarsign.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                        .accessibilityHidden(true)
                    
                    Text("Total Amount Paid")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                }
                
                Text(order.formattedBuyerPrice)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
            }
            .padding(20)
            .background(Color.green.opacity(0.05))
            .cornerRadius(16)
        }
        .padding(.horizontal, 20)
        .opacity(animationOpacity)
        .offset(y: animationOffset)
    }
    
    private var verificationStepsSection: some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "list.number")
                        .foregroundColor(Color("ThemeColor"))
                        .font(.title2)
                        .accessibilityHidden(true)
                    
                    Text("What Happens Next")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                }
                
                Text("Follow these steps to complete your transaction safely:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Verification Steps Timeline
                VStack(spacing: 16) {
                    VerificationStepRow(
                        number: "1",
                        title: "Seller Prepares Item",
                        description: "The seller will prepare and arrange delivery of your item",
                        estimatedTime: "Within 24-48 hours",
                        icon: "box.truck.fill"
                    )
                    
                    Divider()
                    
                    VerificationStepRow(
                        number: "2",
                        title: "Delivery & Photo Upload",
                        description: "Seller uploads a delivery photo and marks the order as delivered",
                        estimatedTime: "When delivered",
                        icon: "camera.fill"
                    )
                    
                    Divider()
                    
                    VerificationStepRow(
                        number: "3",
                        title: "You'll Be Notified",
                        description: "You'll receive a notification to confirm receipt of the item",
                        estimatedTime: "Immediately",
                        icon: "bell.badge.fill"
                    )
                    
                    Divider()
                    
                    VerificationStepRow(
                        number: "4",
                        title: "Confirm Receipt",
                        description: "Verify the item matches the description and confirm to release payment",
                        estimatedTime: "After inspection",
                        icon: "checkmark.shield.fill"
                    )
                }
                
                // Important notice
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your Protection")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Text("Payment is held securely in escrow until you confirm receipt. Only confirm after verifying the item is as described.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(12)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
            }
            .padding(20)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
        }
        .padding(.horizontal, 20)
        .opacity(animationOpacity)
        .offset(y: animationOffset)
    }
    
    private var escrowProtectionSection: some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "shield.checkered")
                        .foregroundColor(.green)
                        .font(.title2)
                        .accessibilityHidden(true)
                    
                    Text("Escrow Protection")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button("Learn More") {
                        showingEscrowInfo = true
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    .accessibilityLabel("Learn more about escrow protection")
                }
                
                Text("Your payment is held securely until you're satisfied with your purchase.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
                    .multilineTextAlignment(.leading)
                
                // Escrow Timeline
                VStack(spacing: 12) {
                    EscrowTimelineRow(
                        icon: "clock",
                        title: "Order Processing",
                        description: "Seller preparing your item",
                        status: .completed
                    )
                    
                    EscrowTimelineRow(
                        icon: "truck",
                        title: "Delivery",
                        description: "Item on its way to you",
                        status: .pending
                    )
                    
                    EscrowTimelineRow(
                        icon: "checkmark.shield",
                        title: "Confirm Receipt",
                        description: "Release payment to seller",
                        status: .pending
                    )
                }
            }
            .padding(20)
            .background(Color.green.opacity(0.1))
            .cornerRadius(16)
        }
        .padding(.horizontal, 20)
        .opacity(animationOpacity)
        .offset(y: animationOffset)
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 16) {
            if order != nil {
                // Success actions
                Button(action: {
                    showingOrderDetails = true
                }) {
                    HStack {
                        Image(systemName: "doc.text")
                            .font(.headline)
                            .accessibilityHidden(true)
                        
                        Text("View Order Details")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color("ThemeColor"))
                    .cornerRadius(12)
                }
                .accessibilityLabel("View detailed order information")
                
                Button(action: {
                    onContactSeller?()
                    // Don't call onDismiss() immediately - let the chat navigation happen first
                }) {
                    HStack {
                        Image(systemName: "message")
                            .font(.headline)
                            .accessibilityHidden(true)
                        
                        Text("Contact Seller")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(Color("ThemeColor"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color("ThemeColor"), lineWidth: 2)
                    )
                }
                .accessibilityLabel("Contact seller about delivery")
                
                Button(action: {
                    onDismiss()
                }) {
                    Text("Continue Shopping")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                }
                .accessibilityLabel("Return to marketplace")
            } else {
                // Processing state
                Button(action: {
                    onDismiss()
                }) {
                    Text("Continue Shopping")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.gray)
                        .cornerRadius(12)
                }
                .accessibilityLabel("Return to marketplace")
            }
        }
        .padding(.horizontal, 30)
        .opacity(animationOpacity)
        .offset(y: animationOffset)
    }
    
    // MARK: - Private Methods
    
    private func animateIn() {
        withAnimation(.easeOut(duration: 0.8)) {
            animationOffset = 0
            animationOpacity = 1
        }
    }
    
    private func provideHapticFeedback() {
        let generator = UINotificationFeedbackGenerator()
        if order != nil {
            generator.notificationOccurred(.success)
        } else {
            generator.notificationOccurred(.warning)
        }
    }
}

// MARK: - Verification Step Row

struct VerificationStepRow: View {
    let number: String
    let title: String
    let description: String
    let estimatedTime: String
    let icon: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Step number badge
            Text(number)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(Color("ThemeColor"))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(Color("ThemeColor"))
                        .font(.subheadline)
                    
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(estimatedTime)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(number): \(title). \(description). Estimated time: \(estimatedTime)")
    }
}

// MARK: - Escrow Timeline Row

struct EscrowTimelineRow: View {
    let icon: String
    let title: String
    let description: String
    let status: TimelineStatus
    
    enum TimelineStatus {
        case completed
        case pending
        case current
    }
    
    private var statusColor: Color {
        switch status {
        case .completed:
            return .green
        case .pending:
            return .gray
        case .current:
            return .blue
        }
    }
    
    private var statusIcon: String {
        switch status {
        case .completed:
            return "checkmark.circle.fill"
        case .pending:
            return "circle"
        case .current:
            return "clock.circle.fill"
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(statusColor)
                .frame(width: 24)
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: statusIcon)
                .font(.title3)
                .foregroundColor(statusColor)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(description), \(status == .completed ? "completed" : status == .current ? "in progress" : "pending")")
    }
}

// MARK: - Escrow Info Sheet

struct EscrowInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                            .accessibilityHidden(true)
                        
                        Text("How Escrow Protection Works")
                            .font(.title2)
                            .fontWeight(.bold)
                            .accessibilityAddTraits(.isHeader)
                        
                        Text("Your payment is held securely until you're satisfied with your purchase.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    
                    // Benefits
                    VStack(spacing: 16) {
                        Text("Benefits")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        VStack(spacing: 12) {
                            BenefitRow(
                                icon: "checkmark.shield",
                                title: "Buyer Protection",
                                description: "Get a refund if the item doesn't match the description"
                            )
                            
                            BenefitRow(
                                icon: "checkmark.shield",
                                title: "Seller Protection",
                                description: "Payment is guaranteed once delivery is confirmed"
                            )
                            
                            BenefitRow(
                                icon: "checkmark.shield",
                                title: "Secure Holding",
                                description: "Funds are held safely until both parties are satisfied"
                            )
                        }
                    }
                    
                    // Process
                    VStack(spacing: 16) {
                        Text("The Process")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        VStack(spacing: 12) {
                            ProcessRow(
                                number: "1",
                                title: "Payment Held",
                                description: "Your payment is securely held in escrow"
                            )
                            
                            ProcessRow(
                                number: "2",
                                title: "Item Delivered",
                                description: "Seller ships or delivers the item to you"
                            )
                            
                            ProcessRow(
                                number: "3",
                                title: "Confirm Receipt",
                                description: "You confirm the item meets your expectations"
                            )
                            
                            ProcessRow(
                                number: "4",
                                title: "Payment Released",
                                description: "Payment is automatically released to the seller"
                            )
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Escrow Protection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityLabel("Close escrow information")
                }
            }
        }
    }
}

struct BenefitRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.green)
                .font(.title3)
                .frame(width: 24)
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(description)")
    }
}

struct ProcessRow: View {
    let number: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Color("ThemeColor"))
                .clipShape(Circle())
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(number): \(title) - \(description)")
    }
}

// MARK: - Preview

struct PurchaseConfirmationView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Success state with order
            PurchaseConfirmationView(
                listing: sampleListing,
                order: sampleOrder,
                paymentMethod: .wallet,
                onDismiss: {},
                onViewOrder: {},
                onContactSeller: {}
            )
            .previewDisplayName("Success with Order")
            
            // Processing state
            PurchaseConfirmationView(
                listing: sampleListing,
                order: nil,
                paymentMethod: .card,
                onDismiss: {},
                onViewOrder: {},
                onContactSeller: {}
            )
            .previewDisplayName("Processing")
        }
    }
    
    static var sampleListing: ListingWithUser {
        ListingWithUser.sampleListing
    }
    
    static var sampleOrder: Order {
        Order(
            id: UUID(),
            listingId: UUID(),
            buyerId: UUID(),
            sellerId: UUID(),
            priceCents: 129999,
            sellerPriceCents: 129999,
            buyerPriceCents: 133000,
            paymentMethod: .wallet,
            paymentStatus: .succeeded,
            orderStatus: .placed,
            sellerConfirmedAt: nil,
            inProgressAt: nil,
            completedAt: nil,
            cancelledAt: nil,
            refundedAt: nil,
            updatedAt: Date(),
            createdAt: Date(),
            stripeEscrowAccountId: "escrow_sample_123",
            marketplaceFeeCents: 0,
            stripePaymentIntentId: "pi_sample_123",
            timeSlotId: nil,
            deliveryPhotoUrl: nil,
            verificationPin: nil,
            quantity: 1,
            listing: Listing.sampleListing
        )
    }
}
