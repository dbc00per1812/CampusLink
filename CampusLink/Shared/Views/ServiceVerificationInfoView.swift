import SwiftUI

struct ServiceVerificationInfoView: View {
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
                    
                    Text(isForSeller ? "How do I make sure I get paid for my service?" : "How do I make sure I receive the service?")
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
                    
                    Text("The process for verifying a service transaction:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        InfoBulletPoint(
                            icon: "lock.shield.fill",
                            text: "When the buyer clicks \"Buy Now\", they pay the required amount and their money is held in escrow until both sides verify the transaction."
                        )
                        
                        InfoBulletPoint(
                            icon: "number.square.fill",
                            text: "Upon purchase, the buyer is given a 4 digit unique code."
                        )
                        
                        InfoBulletPoint(
                            icon: "checkmark.seal.fill",
                            text: "Once they feel the service has been adequately provided or at any point at their discretion, they will give the 4 digit code over to the seller."
                        )
                        
                        InfoBulletPoint(
                            icon: "hand.raised.fill",
                            text: "The seller has a right to ask for this code at any point of their choosing to assure they do not provide full service without payment."
                        )
                        
                        InfoBulletPoint(
                            icon: "banknote.fill",
                            text: "Upon receiving the 4 digit code from the buyer, the seller will enter it into the app and the money held in escrow will be transferred into the seller's wallet."
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
        ServiceVerificationInfoView(isForSeller: true)
        ServiceVerificationInfoView(isForSeller: false)
    }
    .padding()
}

