import SwiftUI

/// View for displaying escrow status information
/// Shows escrow account status, countdown timer, and release information
struct EscrowStatusView: View {
    let escrowStatus: EscrowStatus
    let onReleaseRequest: (() -> Void)?
    
    @State private var timeRemaining: TimeInterval?
    @State private var timer: Timer?
    
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
                
                // Auto-release countdown
                if let timeRemaining = timeRemaining, timeRemaining > 0 {
                    HStack {
                        Text("Auto-release in:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatTimeRemaining(timeRemaining))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                    }
                }
                
                // Release status
                HStack {
                    Text("Release Status:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    if escrowStatus.orderStatus == .completed {
                        Text("Funds Released")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    } else if escrowStatus.canBeReleased {
                        Text("Ready to Release")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    } else {
                        Text("Held in Escrow")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Release button (if applicable)
            if escrowStatus.canBeReleased, let onReleaseRequest = onReleaseRequest {
                Button(action: onReleaseRequest) {
                    HStack {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title3)
                        Text("Release Funds")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .cornerRadius(12)
                }
                .accessibilityLabel("Release escrow funds to seller")
                .accessibilityHint("Tap to release funds from escrow to the seller's wallet")
            }
            
            // Info text
            if escrowStatus.orderStatus == .completed {
                Text("Funds have been automatically released to the seller upon order completion.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            } else {
                Text("Funds are held securely in escrow until delivery is confirmed or the 3-day auto-release period expires.")
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
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    // MARK: - Timer Management
    
    private func startTimer() {
        guard escrowStatus.isEscrowActive else { return }
        
        // Update immediately
        updateTimeRemaining()
        
        // Start timer for updates
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            updateTimeRemaining()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateTimeRemaining() {
        Task {
            do {
                let escrowService = EscrowService.shared
                timeRemaining = try await escrowService.getTimeUntilAutoRelease(for: escrowStatus.orderId)
            } catch {
                timeRemaining = nil
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatTimeRemaining(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60
        
        if hours > 24 {
            let days = hours / 24
            return "\(days) day\(days == 1 ? "" : "s")"
        } else if hours > 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        } else {
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        }
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
                        autoReleaseAt: Date().addingTimeInterval(2 * 24 * 60 * 60), // 2 days from now
                        orderStatus: .placed,
                        paymentStatus: .succeeded
                    ),
                    onReleaseRequest: nil
                )
                
                // Ready to release
                EscrowStatusView(
                    escrowStatus: EscrowStatus(
                        orderId: UUID(),
                        escrowAccountId: "escrow_123456789",
                        paymentIntentId: "pi_123456789",
                        autoReleaseAt: Date().addingTimeInterval(-1 * 60 * 60), // 1 hour ago
                        orderStatus: .placed,
                        paymentStatus: .succeeded
                    ),
                    onReleaseRequest: {
                        print("Release requested")
                    }
                )
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
}
