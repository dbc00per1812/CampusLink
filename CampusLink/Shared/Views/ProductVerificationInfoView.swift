import SwiftUI

struct ProductVerificationInfoView: View {
    @State private var isExpanded = false
    let isForSeller: Bool // true for sellers, false for buyers
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(Color("ThemeColor"))
                    
                    Text(isForSeller ? "How do I make sure I get paid for my product?" : "How do I make sure I receive the product?")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Color("ThemeColor"))
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(Color("ThemeColor"))
                        .font(.caption)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Text("At CampusLink we take necessary steps and precautions surrounding all transactions so that buyers and sellers should receive what they deserve.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("The process for verifying a product transaction:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        InfoBulletPoint(
                            icon: "lock.shield.fill",
                            text: "When the buyer clicks \"Buy Now\" on an offered product, they pay the required amount and their money is held in escrow until both sides verify the transaction."
                        )
                        
                        InfoBulletPoint(
                            icon: "camera.fill",
                            text: "Upon the moment of the product's delivery, whether the buyer picks up or the seller delivers, the seller must take a photo of the delivered product and submit it to CampusLink and click \"Confirm Delivery\"."
                        )
                        
                        InfoBulletPoint(
                            icon: "checkmark.seal.fill",
                            text: "Once the buyer receives the product, they then click \"Confirm Delivery\" on their end and the money held in escrow is transferred into the seller's wallet."
                        )
                    }
                }
                .padding(12)
                .background(Color(UIColor.systemGray6).opacity(0.5))
                .cornerRadius(8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color("ThemeColor").opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color("ThemeColor").opacity(0.3), lineWidth: 1)
        )
    }
}

private struct InfoBulletPoint: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(Color("ThemeColor"))
                .frame(width: 16)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        ProductVerificationInfoView(isForSeller: true)
        ProductVerificationInfoView(isForSeller: false)
    }
    .padding()
}

