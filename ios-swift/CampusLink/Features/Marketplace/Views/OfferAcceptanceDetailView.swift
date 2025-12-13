import SwiftUI

struct OfferAcceptanceDetailView: View {
    let userOffer: UserOffer
    @Binding var isProcessing: Bool
    @Binding var errorMessage: String?
    let onAccept: () -> Void
    let onDecline: () -> Void
    let onDismiss: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    private var formattedPrice: String {
        userOffer.formattedPrice ?? "$0.00"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "tag.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Color("ThemeColor"))
                    
                    Text("Offer Details")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(formattedPrice)
                        .font(.largeTitle)
                        .fontWeight(.heavy)
                        .foregroundColor(Color("ThemeColor"))
                }
                .padding(.top, 20)
                .padding(.bottom, 30)
                
                // Offer details
                VStack(alignment: .leading, spacing: 16) {
                    // Seeking post info
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Your Request", systemImage: "magnifyingglass")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(userOffer.seekListingTitle)
                            .font(.body)
                            .fontWeight(.medium)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                    
                    // Seller info
                    VStack(alignment: .leading, spacing: 8) {
                        Label("From Seller", systemImage: "person.fill")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text(userOffer.sellerName)
                                .font(.body)
                                .fontWeight(.medium)
                            
                            if let offerListingTitle = userOffer.offerListingTitle {
                                Text("•")
                                    .foregroundColor(.secondary)
                                Text(offerListingTitle)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    if let message = userOffer.message, !message.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Message", systemImage: "message.fill")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text(message)
                                .font(.body)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                        }
                    }
                    
                    // Status info
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Offer Status", systemImage: "info.circle.fill")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Image(systemName: statusIcon)
                                .foregroundColor(statusColor)
                            Text(userOffer.status.capitalized)
                                .font(.body)
                                .fontWeight(.medium)
                            Spacer()
                            Text(userOffer.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(statusColor.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 12) {
                    if userOffer.canAccept {
                        Button(action: onAccept) {
                            HStack {
                                if isProcessing {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                }
                                Text(isProcessing ? "Processing..." : "Accept Offer")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color("ThemeColor"))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(isProcessing)
                        
                        Button(action: onDecline) {
                            HStack {
                                Image(systemName: "xmark.circle")
                                Text("Decline Offer")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .foregroundColor(.facebookBlue)
                            .cornerRadius(12)
                        }
                        .disabled(isProcessing)
                    }
                    
                    Text("By accepting, you agree to proceed with the purchase at the offered price.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
                .background(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 1, y: -1)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        onDismiss()
                    }
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
    }
    
    private var statusIcon: String {
        switch userOffer.status {
        case "pending":
            return "clock.circle.fill"
        case "accepted":
            return "checkmark.circle.fill"
        case "declined":
            return "xmark.circle.fill"
        default:
            return "questionmark.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch userOffer.status {
        case "pending":
            return .orange
        case "accepted":
            return .green
        case "declined":
            return .facebookBlue
        default:
            return .gray
        }
    }
}
