import SwiftUI

struct BlockUserView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager
    
    let userId: String
    let userName: String?
    let onBlockComplete: (() -> Void)?
    
    @State private var isBlocking = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var blockSuccessful = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Warning Icon
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.red)
                        .padding(.top, 32)
                    
                    // Title
                    Text("Block \(userName ?? "this user")?")
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    // Explanation
                    VStack(alignment: .leading, spacing: 16) {
                        Text("When you block someone:")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        BlockingFeatureRow(
                            icon: "message.slash.fill",
                            text: "You won't be able to message each other"
                        )
                        
                        BlockingFeatureRow(
                            icon: "eye.slash.fill",
                            text: "You won't see each other's listings"
                        )
                        
                        BlockingFeatureRow(
                            icon: "arrow.left.arrow.right.slash",
                            text: "They won't be able to interact with you"
                        )
                        
                        BlockingFeatureRow(
                            icon: "clock.arrow.circlepath",
                            text: "You can unblock them anytime from their profile"
                        )
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        // Block Button
                        Button(action: {
                            Task {
                                await blockUser()
                            }
                        }) {
                            HStack {
                                if isBlocking {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "hand.raised.fill")
                                    Text("Block User")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(isBlocking)
                        
                        // Cancel Button
                        Button(action: {
                            dismiss()
                        }) {
                            Text("Cancel")
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray6))
                                .foregroundColor(.primary)
                                .cornerRadius(12)
                        }
                        .disabled(isBlocking)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Block User")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isBlocking)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("User Blocked", isPresented: $blockSuccessful) {
                Button("OK") {
                    onBlockComplete?()
                    dismiss()
                }
            } message: {
                Text("\(userName ?? "This user") has been blocked. You won't see each other's content or be able to message.")
            }
        }
    }
    
    @MainActor
    private func blockUser() async {
        guard let currentUserId = authManager.currentUserId else {
            errorMessage = "You must be logged in to block users"
            showingError = true
            return
        }
        
        isBlocking = true
        
        do {
            try await BlockedUsersService.blockUser(userId, currentUserId: currentUserId)
            
            // Haptic feedback
            let impactFeedback = UINotificationFeedbackGenerator()
            impactFeedback.notificationOccurred(.success)
            
            blockSuccessful = true
            
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
            
            // Haptic feedback
            let impactFeedback = UINotificationFeedbackGenerator()
            impactFeedback.notificationOccurred(.error)
        }
        
        isBlocking = false
    }
}

// MARK: - Blocking Feature Row
struct BlockingFeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.red)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

// MARK: - Preview
struct BlockUserView_Previews: PreviewProvider {
    static var previews: some View {
        BlockUserView(
            userId: "123",
            userName: "John Doe",
            onBlockComplete: nil
        )
        .environmentObject(AuthManager())
    }
}



