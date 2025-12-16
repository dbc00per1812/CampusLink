import SwiftUI

struct TransactionGuideView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How Transactions Work")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Everything you need to know about buying and selling safely on CampusLink")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    Divider()
                    
                    // General Protection Section
                    generalProtectionSection
                    
                    Divider()
                    
                    // Product Transactions
                    productTransactionSection
                    
                    Divider()
                    
                    // Service Transactions
                    serviceTransactionSection
                    
                    Divider()
                    
                    // Ticket Transactions
                    ticketTransactionSection
                    
                    Divider()
                    
                    // Payment & Wallet
                    paymentWalletSection
                    
                    Divider()
                    
                    // Contact Support
                    contactSupportSection
                    
                    Spacer(minLength: 40)
                }
                .padding(.vertical)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color("ThemeColor"))
                }
            }
        }
    }
    
    // MARK: - General Protection
    
    @ViewBuilder
    private var generalProtectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                icon: "shield.checkered",
                title: "Buyer & Seller Protection",
                color: Color("ThemeColor")
            )
            
            VStack(alignment: .leading, spacing: 12) {
                Text("At CampusLink we take necessary steps and precautions surrounding all transactions so that buyers and sellers should receive what they deserve.")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                InfoCard(
                    icon: "lock.shield.fill",
                    title: "Escrow Protection",
                    description: "All payments are held in secure escrow until both parties verify the transaction is complete. This protects buyers from not receiving items and sellers from not getting paid."
                )
                
                InfoCard(
                    icon: "checkmark.seal.fill",
                    title: "Two-Way Verification",
                    description: "Both buyer and seller must confirm the transaction before funds are released. This ensures accountability on both sides."
                )
                
                InfoCard(
                    icon: "dollarsign.circle.fill",
                    title: "CampusLink Wallet",
                    description: "Sellers receive funds in their CampusLink wallet after successful verification. Funds can be withdrawn to your bank account or used for purchases."
                )
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Product Transactions
    
    @ViewBuilder
    private var productTransactionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                icon: "shippingbox.fill",
                title: "Product Transactions",
                color: .blue
            )
            
            Text("For physical items like textbooks, electronics, furniture, etc.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Buyer Steps
            VStack(alignment: .leading, spacing: 12) {
                Text("As a Buyer:")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                TransactionStep(
                    number: "1",
                    title: "Purchase & Escrow",
                    description: "When you click \"Buy Now\", you pay the required amount and your money is held in escrow until both sides verify the transaction."
                )
                
                TransactionStep(
                    number: "2",
                    title: "Coordinate Meetup",
                    description: "Use the built-in messaging to coordinate pickup or delivery details with the seller."
                )
                
                TransactionStep(
                    number: "3",
                    title: "Receive Product",
                    description: "Meet the seller to receive your product. Inspect it to ensure it matches the listing description."
                )
                
                TransactionStep(
                    number: "4",
                    title: "Confirm Delivery",
                    description: "After receiving the product, click \"Confirm Delivery\" in your order. This releases the payment to the seller."
                )
            }
            .padding()
            .background(Color.blue.opacity(0.05))
            .cornerRadius(12)
            
            // Seller Steps
            VStack(alignment: .leading, spacing: 12) {
                Text("As a Seller:")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                TransactionStep(
                    number: "1",
                    title: "Receive Order",
                    description: "You'll be notified when someone purchases your item. The buyer's payment is held in escrow."
                )
                
                TransactionStep(
                    number: "2",
                    title: "Coordinate Delivery",
                    description: "Use messaging to arrange pickup or delivery with the buyer."
                )
                
                TransactionStep(
                    number: "3",
                    title: "Deliver & Document",
                    description: "Upon delivery, take a photo of the delivered product and submit it to CampusLink. Click \"Confirm Delivery\"."
                )
                
                TransactionStep(
                    number: "4",
                    title: "Wait for Buyer Confirmation",
                    description: "Once the buyer confirms receipt by clicking \"Confirm Delivery\", the money held in escrow is transferred to your wallet."
                )
            }
            .padding()
            .background(Color.green.opacity(0.05))
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Service Transactions
    
    @ViewBuilder
    private var serviceTransactionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                icon: "person.fill.checkmark",
                title: "Service Transactions",
                color: .green
            )
            
            Text("For services like tutoring, photography, moving help, etc.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // PIN System Explanation
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "number.square.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("4-Digit PIN System")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Services use a unique PIN code for verification instead of photo proof")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
            
            // Buyer Steps
            VStack(alignment: .leading, spacing: 12) {
                Text("As a Buyer:")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                TransactionStep(
                    number: "1",
                    title: "Purchase Service",
                    description: "Click \"Buy Now\" and your payment is held in escrow until verification."
                )
                
                TransactionStep(
                    number: "2",
                    title: "Receive Your PIN",
                    description: "Upon purchase, you'll receive a unique 4-digit PIN code. Keep this secure."
                )
                
                TransactionStep(
                    number: "3",
                    title: "Receive Service",
                    description: "The seller provides the agreed-upon service. You can monitor their progress."
                )
                
                TransactionStep(
                    number: "4",
                    title: "Share PIN to Release Payment",
                    description: "Once you're satisfied with the service, give the 4-digit PIN to the seller. They'll enter it to receive payment from escrow."
                )
            }
            .padding()
            .background(Color.blue.opacity(0.05))
            .cornerRadius(12)
            
            // Seller Steps
            VStack(alignment: .leading, spacing: 12) {
                Text("As a Seller:")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                TransactionStep(
                    number: "1",
                    title: "Receive Order",
                    description: "You'll be notified when someone books your service. Payment is held in escrow."
                )
                
                TransactionStep(
                    number: "2",
                    title: "Coordinate & Provide Service",
                    description: "Use messaging to coordinate timing and location. Provide the agreed service."
                )
                
                TransactionStep(
                    number: "3",
                    title: "Request PIN",
                    description: "You have the right to ask for the 4-digit PIN at any point to ensure payment before completing the full service."
                )
                
                TransactionStep(
                    number: "4",
                    title: "Enter PIN to Get Paid",
                    description: "Once the buyer gives you the PIN, enter it in the app. The money held in escrow will be transferred to your wallet."
                )
            }
            .padding()
            .background(Color.green.opacity(0.05))
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Ticket Transactions
    
    @ViewBuilder
    private var ticketTransactionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                icon: "ticket.fill",
                title: "Ticket Transactions",
                color: .orange
            )
            
            Text("Special verification process for event tickets")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Transfer Methods Overview
            VStack(alignment: .leading, spacing: 12) {
                Text("Accepted Transfer Methods:")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                TransferMethodCard(
                    icon: "apps.iphone",
                    title: "Apple Wallet",
                    description: "Transfer via phone number using the share function"
                )
                
                TransferMethodCard(
                    icon: "ticket.fill",
                    title: "Ticketing Apps",
                    description: "Ticketmaster, SeatGeek, StubHub, and other major platforms"
                )
            }
            .padding()
            .background(Color.orange.opacity(0.05))
            .cornerRadius(12)
            
            // Buyer Steps
            VStack(alignment: .leading, spacing: 12) {
                Text("As a Buyer:")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                TransactionStep(
                    number: "1",
                    title: "Purchase Ticket",
                    description: "Click \"Buy Now\" and your payment is held in escrow until both sides verify the transaction."
                )
                
                TransactionStep(
                    number: "2",
                    title: "Seller Transfers Ticket",
                    description: "The seller will transfer the ticket to you through Apple Wallet or their ticketing app."
                )
                
                TransactionStep(
                    number: "3",
                    title: "Receive Transfer",
                    description: "You'll receive an email or app notification with the ticket transfer."
                )
                
                TransactionStep(
                    number: "4",
                    title: "Seller Provides Proof",
                    description: "Seller will upload a screenshot of the transfer confirmation (email or app receipt)."
                )
                
                TransactionStep(
                    number: "5",
                    title: "Confirm Receipt",
                    description: "After verifying you received the ticket, click \"Confirm Delivery\". Funds are then released to the seller's wallet."
                )
            }
            .padding()
            .background(Color.blue.opacity(0.05))
            .cornerRadius(12)
            
            // Seller Steps
            VStack(alignment: .leading, spacing: 12) {
                Text("As a Seller:")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                TransactionStep(
                    number: "1",
                    title: "Receive Order",
                    description: "You'll be notified when someone buys your ticket. Their payment is held in escrow."
                )
                
                TransactionStep(
                    number: "2",
                    title: "Transfer the Ticket",
                    description: "Transfer the ticket using Apple Wallet (via phone number) or your ticketing app (Ticketmaster, SeatGeek, etc.)."
                )
                
                TransactionStep(
                    number: "3",
                    title: "Screenshot Confirmation",
                    description: "Take a screenshot of the transfer confirmation email or app receipt showing the buyer's information."
                )
                
                TransactionStep(
                    number: "4",
                    title: "Submit Proof",
                    description: "Upload the screenshot to the \"Confirm Delivery\" section (accessible through wallet or messages) and click \"Confirm Delivery\"."
                )
                
                TransactionStep(
                    number: "5",
                    title: "Wait for Buyer Confirmation",
                    description: "Once the buyer confirms they received the ticket, funds held in escrow will be transferred to your wallet."
                )
            }
            .padding()
            .background(Color.green.opacity(0.05))
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Payment & Wallet
    
    @ViewBuilder
    private var paymentWalletSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                icon: "creditcard.fill",
                title: "Payments & Wallet",
                color: .purple
            )
            
            Text("Understanding how payments work on CampusLink")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 12) {
                InfoCard(
                    icon: "creditcard.fill",
                    title: "Payment Methods",
                    description: "Pay with your CampusLink wallet balance or add a debit/credit card for purchases."
                )
                
                InfoCard(
                    icon: "building.columns.fill",
                    title: "Receiving Payments (Sellers)",
                    description: "Complete Stripe Connect onboarding in the Wallet tab to receive payments. This is required before you can post listings."
                )
                
                InfoCard(
                    icon: "arrow.down.circle.fill",
                    title: "Withdrawing Funds",
                    description: "Sellers can withdraw funds from their CampusLink wallet to their linked bank account through the Wallet tab."
                )
                
                InfoCard(
                    icon: "dollarsign.circle.fill",
                    title: "Wallet Balance",
                    description: "Keep funds in your wallet to make quick purchases or to accumulate earnings before withdrawing."
                )
            }
            
            // Getting Started for Sellers
            VStack(alignment: .leading, spacing: 12) {
                Text("First Time Sellers:")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 12) {
                        Text("1.")
                            .fontWeight(.bold)
                            .foregroundColor(Color("ThemeColor"))
                        Text("Go to the Wallet tab")
                    }
                    
                    HStack(alignment: .top, spacing: 12) {
                        Text("2.")
                            .fontWeight(.bold)
                            .foregroundColor(Color("ThemeColor"))
                        Text("Complete Stripe Connect onboarding")
                    }
                    
                    HStack(alignment: .top, spacing: 12) {
                        Text("3.")
                            .fontWeight(.bold)
                            .foregroundColor(Color("ThemeColor"))
                        Text("Return to Home to start posting!")
                    }
                }
                .font(.body)
            }
            .padding()
            .background(Color.purple.opacity(0.05))
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Contact Support
    
    @ViewBuilder
    private var contactSupportSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                icon: "questionmark.circle.fill",
                title: "Need Help?",
                color: Color("ThemeColor")
            )
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Have questions or concerns about a transaction?")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Text("Our support team is here to help you with any issues related to buying, selling, payments, or disputes.")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Button(action: {
                    if let url = URL(string: "mailto:darragh.b3272@gmail.com?subject=CampusLink%20Support%20Request") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 18))
                        
                        Text("Contact Support")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color("ThemeColor"))
                    .cornerRadius(12)
                }
                
                // Quick response time indicator
                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    Text("We typically respond within 24 hours")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Supporting Views

struct SectionHeader: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(color)
            
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
        }
    }
}

struct TransactionStep: View {
    let number: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color("ThemeColor"))
                    .frame(width: 28, height: 28)
                
                Text(number)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct InfoCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(Color("ThemeColor"))
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct TransferMethodCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Color("ThemeColor"))
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    TransactionGuideView()
}

