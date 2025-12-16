import SwiftUI

struct TicketGuaranteeInfoView: View {
    let isOwnListing: Bool
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header button to toggle expand/collapse
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(Color("ThemeColor"))
                        .font(.system(size: 16))
                    
                    Text("Ticket Transaction Protection")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14, weight: .semibold))
                }
                .padding()
                .background(Color("ThemeColor").opacity(0.1))
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expandable content
            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    // Section 1: Guarantee question (buyer vs seller)
                    VStack(alignment: .leading, spacing: 8) {
                        if isOwnListing {
                            // Seller view
                            Text("How do I guarantee I get paid for the ticket?")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(Color("ThemeColor"))
                        } else {
                            // Buyer view
                            Text("How do I guarantee I receive the ticket?")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(Color("ThemeColor"))
                        }
                        
                        Text("At CampusLink we take necessary steps and precautions surrounding all transactions so that buyers and sellers should receive what they deserve.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Divider()
                    
                    // Section 2: The verification process
                    VStack(alignment: .leading, spacing: 12) {
                        Text("The verification process:")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        if isOwnListing {
                            // Seller view - focus on what the seller needs to do
                            VStack(alignment: .leading, spacing: 10) {
                                StepRow(
                                    number: "1",
                                    text: "When the buyer clicks \"Buy Now\" on your offered ticket, they pay the required amount and their money is held in escrow until both sides verify the transaction."
                                )
                                
                                StepRow(
                                    number: "2",
                                    text: "You will then be required to transfer the ticket to the buyer using one of the methods below."
                                )
                                
                                StepRow(
                                    number: "3",
                                    text: "Screenshot the transfer confirmation (email for Apple Wallet, or receipt from Ticketmaster, SeatGeek, Stubhub, etc.)."
                                )
                                
                                StepRow(
                                    number: "4",
                                    text: "Submit the photo to the confirm delivery section of the original posting (accessible through wallet or messages) and click \"Confirm Delivery\"."
                                )
                                
                                StepRow(
                                    number: "5",
                                    text: "Buyer will then click confirm delivery on their end, acknowledging the ticket has been transferred. Funds held in escrow will then be transferred to your CampusLink wallet."
                                )
                            }
                        } else {
                            // Buyer view - focus on what the buyer can expect
                            VStack(alignment: .leading, spacing: 10) {
                                StepRow(
                                    number: "1",
                                    text: "When you click \"Buy Now\" on an offered ticket, you pay the required amount and your money is held in escrow until both sides verify the transaction."
                                )
                                
                                StepRow(
                                    number: "2",
                                    text: "The seller will then be required to transfer the ticket to you using one of the methods below."
                                )
                                
                                StepRow(
                                    number: "3",
                                    text: "Seller will screenshot the transfer confirmation (email for Apple Wallet, or receipt from Ticketmaster, SeatGeek, Stubhub, etc.)."
                                )
                                
                                StepRow(
                                    number: "4",
                                    text: "Seller will submit the photo to the confirm delivery section of the original posting (accessible through wallet or messages) and click \"Confirm Delivery\"."
                                )
                                
                                StepRow(
                                    number: "5",
                                    text: "You can then click confirm delivery on your end, acknowledging the ticket has been transferred. Funds held in escrow will then be transferred to seller's CampusLink wallet."
                                )
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Section 3: Ticket transfer options
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Options for ticket transfer:")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        if isOwnListing {
                            // Seller view - detailed transfer instructions
                            VStack(alignment: .leading, spacing: 12) {
                                TransferMethodRow(
                                    icon: "apps.iphone",
                                    title: "Apple Wallet",
                                    description: "Click the \"more\" or \"share\" icons and follow the given steps to transfer the ticket using the buyer's phone number. An email should be sent including buyer information, screenshot this email and submit it when confirming delivery."
                                )
                                
                                TransferMethodRow(
                                    icon: "ticket.fill",
                                    title: "Ticketmaster, SeatGeek, Stubhub, etc.",
                                    description: "Transfer tickets according to the steps provided within each respective app. An email should be sent including buyer information, if not transfer should be recorded on the respective app, screenshot this and submit it to \"Confirm Delivery\"."
                                )
                            }
                        } else {
                            // Buyer view - what to expect from seller
                            VStack(alignment: .leading, spacing: 12) {
                                TransferMethodRow(
                                    icon: "apps.iphone",
                                    title: "Apple Wallet",
                                    description: "Seller will use the \"more\" or \"share\" icons to transfer the ticket to your phone number. You'll receive an email with the ticket transfer."
                                )
                                
                                TransferMethodRow(
                                    icon: "ticket.fill",
                                    title: "Ticketmaster, SeatGeek, Stubhub, etc.",
                                    description: "Seller will transfer the ticket through the respective app. You'll receive an email or app notification with the ticket transfer."
                                )
                            }
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Supporting Views

private struct StepRow: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color("ThemeColor").opacity(0.2))
                    .frame(width: 24, height: 24)
                
                Text(number)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(Color("ThemeColor"))
            }
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct TransferMethodRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(Color("ThemeColor"))
                .font(.system(size: 20))
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

struct TicketGuaranteeInfoView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Buyer View")
                    .font(.headline)
                TicketGuaranteeInfoView(isOwnListing: false)
                    .padding()
                
                Divider()
                    .padding()
                
                Text("Seller View")
                    .font(.headline)
                TicketGuaranteeInfoView(isOwnListing: true)
                    .padding()
            }
        }
    }
}

