import SwiftUI

/// A reusable avatar view that displays either a user's profile picture or their initials
/// Initials are displayed with consistent but varied colors based on the user's ID
struct UserAvatarView: View {
    let user: User
    let size: CGFloat
    
    init(user: User, size: CGFloat = 24) {
        self.user = user
        self.size = size
    }
    
    var body: some View {
        Group {
            if let profilePicUrl = user.profilePic, !profilePicUrl.isEmpty,
               let url = URL(string: profilePicUrl) {
                // Show profile picture
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                    case .failure(_), .empty:
                        // Fallback to initials if image fails to load
                        initialsView
                    @unknown default:
                        initialsView
                    }
                }
            } else {
                // Show initials if no profile picture
                initialsView
            }
        }
    }
    
    private var initialsView: some View {
        Circle()
            .fill(avatarColor)
            .frame(width: size, height: size)
            .overlay(
                Text(userInitials)
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundColor(.white)
            )
    }
    
    /// Get the first initial of the user's name
    private var userInitials: String {
        let name = user.name ?? user.email ?? "?"
        
        // Get first character of the name
        if let firstChar = name.first {
            return String(firstChar).uppercased()
        }
        
        return "?"
    }
    
    /// Generate a consistent color for the user based on their ID
    /// This ensures the same user always gets the same color
    private var avatarColor: Color {
        // Use the user's ID to generate a consistent hash
        let hash = abs(user.id.hashValue)
        
        // Define a palette of pleasant colors for avatars
        let colorPalette: [Color] = [
            Color(red: 0.26, green: 0.52, blue: 0.96), // Blue
            Color(red: 0.40, green: 0.71, blue: 0.38), // Green
            Color(red: 0.96, green: 0.49, blue: 0.29), // Orange
            Color(red: 0.61, green: 0.35, blue: 0.71), // Purple
            Color(red: 0.91, green: 0.30, blue: 0.40), // Red
            Color(red: 0.00, green: 0.67, blue: 0.76), // Cyan
            Color(red: 0.96, green: 0.76, blue: 0.19), // Yellow
            Color(red: 0.47, green: 0.33, blue: 0.28), // Brown
            Color(red: 0.91, green: 0.12, blue: 0.39), // Pink
            Color(red: 0.20, green: 0.60, blue: 0.86), // Light Blue
            Color(red: 0.56, green: 0.69, blue: 0.26), // Lime
            Color(red: 0.85, green: 0.37, blue: 0.01)  // Deep Orange
        ]
        
        // Use modulo to select a color from the palette
        let colorIndex = hash % colorPalette.count
        return colorPalette[colorIndex]
    }
}

// MARK: - Preview Provider
struct UserAvatarView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Preview with different sizes
            HStack(spacing: 15) {
                UserAvatarView(user: User.sampleUser, size: 24)
                UserAvatarView(user: User.sampleUser, size: 32)
                UserAvatarView(user: User.sampleUser, size: 48)
                UserAvatarView(user: User.sampleUser, size: 64)
            }
            
            // Preview with different users (showing color variation)
            HStack(spacing: 15) {
                ForEach(0..<8, id: \.self) { index in
                    UserAvatarView(
                        user: User(
                            id: "user-\(index)",
                            name: "User \(index)",
                            bio: nil,
                            profilePic: nil,
                            email: "user\(index)@example.com",
                            campus: nil,
                            createdAt: Date(),
                            campusEmailVerified: nil,
                            trustScore: nil,
                            stripeConnectId: nil,
                            stripePayoutsEnabled: nil,
                            stripeDetailsSubmitted: nil,
                            verificationStatus: nil,
                            studentIdImageUrl: nil,
                            verificationSubmittedAt: nil,
                            verificationReviewedAt: nil,
                            verificationNotes: nil
                        ),
                        size: 40
                    )
                }
            }
        }
        .padding()
    }
}

