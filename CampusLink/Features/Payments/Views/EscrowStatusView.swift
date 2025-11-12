import SwiftUI

/// View for displaying escrow status information
/// Shows escrow account status, countdown timer, and release information
struct EscrowStatusView: View {
    let escrowStatus: EscrowStatus
    let onReleaseRequest: (() -> Void)?
    
    private var statusColor: Color {
        switch escrowStatus.displayStatus {
        case "Funds Released":
            return .green
        case "Held in Escrow":
            return .blue
        case "Disputed":
            return .red
        case "Ready to Release":
            return .orange
        default:
            return .gray
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "shield.checkered")
                    .font(.title2)
                    .foregroundColor(.green)
                    .accessibilityHidden(true)
                
                Text("Escrow Protection")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Status badge
                Text(escrowStatus.isEscrowActive ? "Active" : "Inactive")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(escrowStatus.isEscrowActive ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                    .foregroundColor(escrowStatus.isEscrowActive ? .green : .gray)
                    .cornerRadius(8)
            }
            
            // Escrow details
            VStack(spacing: 12) {
                // Escrow account info
                if let escrowAccountId = escrowStatus.escrowAccountId {
                    HStack {
                        Text("Escrow Account:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(escrowAccountId.prefix(12) + "...")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .font(.system(.subheadline, design: .monospaced))
                    }
                }
                
                // Payment intent info
                if let paymentIntentId = escrowStatus.paymentIntentId {
                    HStack {
                        Text("Payment Intent:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(paymentIntentId.prefix(12) + "...")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .font(.system(.subheadline, design: .monospaced))
                    }
                }
                
                
                // Release status
                HStack {
                    Text("Release Status:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(escrowStatus.displayStatus)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(statusColor)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            
            // Info text
            if escrowStatus.orderStatus == .completed {
                Text("Funds have been automatically released to the seller upon order completion.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            } else {
                Text("Funds are held securely in escrow until delivery is confirmed by the buyer.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
    
}

// MARK: - Preview

struct EscrowStatusView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Active escrow
                EscrowStatusView(
                    escrowStatus: EscrowStatus(
                        orderId: UUID(),
                        escrowAccountId: "escrow_123456789",
                        paymentIntentId: "pi_123456789",
                        orderStatus: .placed,
                        paymentStatus: .succeeded,
                        escrowReleaseStatus: "held"
                    ),
                    onReleaseRequest: nil
                )
                
                // Completed order
                EscrowStatusView(
                    escrowStatus: EscrowStatus(
                        orderId: UUID(),
                        escrowAccountId: "escrow_123456789",
                        paymentIntentId: "pi_123456789",
                        orderStatus: .completed,
                        paymentStatus: .succeeded,
                        escrowReleaseStatus: "released"
                    ),
                    onReleaseRequest: nil
                )
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
}
