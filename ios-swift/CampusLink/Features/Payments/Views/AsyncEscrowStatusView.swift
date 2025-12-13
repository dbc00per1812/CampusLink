import SwiftUI

/// Async wrapper for EscrowStatusView that fetches escrow status
/// Handles loading states and errors while fetching escrow information
struct AsyncEscrowStatusView: View {
    let orderId: UUID
    
    @State private var escrowStatus: EscrowStatus?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if let errorMessage = errorMessage {
                errorView(message: errorMessage)
            } else if let escrowStatus = escrowStatus {
                EscrowStatusView(
                    escrowStatus: escrowStatus,
                    onReleaseRequest: {
                        Task { await handleReleaseRequest() }
                    }
                )
            } else {
                Text("No escrow information available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .onAppear {
            Task { await loadEscrowStatus() }
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading escrow status...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    // MARK: - Error View
    private func errorView(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundColor(.orange)
            
            Text("Error loading escrow status")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Retry") {
                Task { await loadEscrowStatus() }
            }
            .font(.caption)
            .foregroundColor(.blue)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    // MARK: - Data Loading
    
    private func loadEscrowStatus() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let escrowService = EscrowService.shared
            escrowStatus = try await escrowService.getEscrowStatus(for: orderId)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Actions
    
    private func handleReleaseRequest() async {
        do {
            let escrowService = EscrowService.shared
            try await escrowService.releaseEscrowFunds(for: orderId)
            
            // Refresh escrow status after release
            await loadEscrowStatus()
            
        } catch {
            errorMessage = "Failed to release escrow: \(error.localizedDescription)"
        }
    }
}

// MARK: - Preview

struct AsyncEscrowStatusView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                AsyncEscrowStatusView(orderId: UUID())
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
}
