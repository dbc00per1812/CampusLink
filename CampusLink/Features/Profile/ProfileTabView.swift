import SwiftUI
import PhotosUI
import Supabase

struct ProfileTabView: View {
    @EnvironmentObject private var authManager: AuthManager
    
    @State private var userProfile: User?
    @State private var profileImage: UIImage?
    @State private var userListings: [ListingWithUser] = []
    @State private var isLoading = false
    @State private var showEditProfile = false
    @State private var showSettings = false
    
    // Stats
    @State private var postsCount = 0
    // Ratings
    @State private var ratingsSummary: UserRatingsSummary?
    @State private var isLoadingRatings = false

    var body: some View {
        NavigationView {
        ScrollView {
                VStack(spacing: 0) {
                    if isLoading && userProfile == nil {
                        // Show skeleton on first load
                        VStack {
                            headerView
                            ProfileSkeleton()
                            Divider()
                            ProfileListingsSkeleton()
                        }
                    } else {
                        // Header with username and menu
                        headerView
                        
                        // Profile info section (top quarter)
                        profileInfoSection
                        
                        // Posts grid (bottom three quarters)
                        postsGridSection
                        
                        Spacer()
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            Task {
                await loadUser()
                await loadUserListings()
                if AppConfig.enableRatings, let uid = authManager.currentUserId {
                    await loadRatings(userId: uid)
                }
            }
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView()
                .environmentObject(authManager)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(authManager)
        }
    }
}

// MARK: - View Components

extension ProfileTabView {
    
    private var headerView: some View {
                HStack {
                    Text("Profile")
                        .responsiveFont(.largeTitle, weight: .bold)
            
                    Spacer()
            
                    Button(action: {
                        showSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .responsiveFont(.title2)
                            .foregroundColor(Color("ThemeColor"))
                    }
                    .accessibleButton("Open settings")
                }
        .responsiveHorizontalSpacing(16)
        .responsiveSpacing(10)
    }
    
    private var profileInfoSection: some View {
        ResponsiveVStack(spacing: 20) {
            // Profile Picture
            profilePictureView
            
            // Name and Bio
            ResponsiveVStack(spacing: 8) {
                Text(userProfile?.name ?? "User Name")
                    .responsiveFont(.title2, weight: .semibold)
                
                if let bio = userProfile?.bio, !bio.isEmpty {
                    Text(bio)
                        .responsiveFont(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // University info
                HStack {
                    Image(systemName: "graduationcap")
                        .foregroundColor(.secondary)
                        .responsiveFont(.caption)
                    Text("Campus Marketplace")
                        .responsiveFont(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Ratings Summary (Phase 2)
                if AppConfig.enableRatings {
                    if let summary = ratingsSummary {
                        RatingSummaryView(summary: summary)
                    } else if isLoadingRatings {
                        ProgressView().responsiveSpacing(4)
                    }
                }
            }
            
            // Edit Profile Button
            Button(action: {
                showEditProfile = true
            }) {
                Text("Edit Profile")
                    .responsiveFont(.subheadline, weight: .medium)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .responsiveSpacing(8)
                    .background(Color(UIColor.systemGray6))
                    .responsiveCornerRadius(8)
            }
            .responsiveHorizontalSpacing(40)
            .accessibleButton("Edit profile")
            
            // My Offers Navigation
            NavigationLink(destination: AllMyOffersView().environmentObject(authManager)) {
                HStack {
                    Image(systemName: "envelope.badge")
                    Text("My Offers")
                }
                .responsiveFont(.subheadline, weight: .medium)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .responsiveSpacing(8)
                .background(Color(UIColor.systemGray6))
                .responsiveCornerRadius(8)
            }
            .responsiveHorizontalSpacing(40)
            .accessibleButton("View my offers")
            
            if AppConfig.enableRatings {
                NavigationLink(destination: RatingsHistoryView(userId: authManager.currentUserId ?? "")) {
                    HStack {
                        Image(systemName: "list.bullet.rectangle")
                        Text("View Ratings History")
                    }
                    .responsiveFont(.subheadline)
                    .foregroundColor(Color("ThemeColor"))
                }
                .accessibleButton("View ratings history")
            }
        }
        .responsiveSpacing(20)
        .responsiveHorizontalSpacing(16)
    }
    
    private var profilePictureView: some View {
        ResponsiveProfileImage(
            image: profileImage,
            size: ResponsiveImageConstants.mediumImageSize
        )
        .overlay(
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
    

    
    private var postsGridSection: some View {
        ResponsiveVStack(spacing: 0) {
            // Section Header
            HStack {
                Text("My Listings")
                    .responsiveFont(.headline, weight: .semibold)
                Spacer()
                Text("\(postsCount) posts")
                    .responsiveFont(.subheadline)
                    .foregroundColor(.secondary)
            }
            .responsiveHorizontalSpacing(16)
            .responsiveSpacing(12)
            
            Divider()
            
            // List content
            ResponsiveVStack(spacing: 8) {
                ForEach(userListings, id: \.id) { listing in
                    listingRowItem(listing)
                }
                
                if userListings.isEmpty {
                    ResponsiveVStack(spacing: 16) {
                        Image(systemName: "square.stack.3d.up")
                            .responsiveFontSize(48)
                            .foregroundColor(.gray)
                        
                        Text("No listings yet")
                            .responsiveFont(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Start selling by creating your first listing")
                            .responsiveFont(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .responsiveSpacing(40)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
    
    private func listingRowItem(_ listing: ListingWithUser) -> some View {
        NavigationLink(destination: ListingDetailView(listing: listing)) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(listing.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    if AppConfig.enableSeekMode && listing.intent == .seek {
                        // Show budget for seek posts
                        HStack(spacing: 4) {
                            if let min = listing.budgetMin, let max = listing.budgetMax {
                                Text("$\(min, specifier: "%.0f")-$\(max, specifier: "%.0f")")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.orange)
                            } else if let max = listing.budgetMax {
                                Text("Up to $\(max, specifier: "%.0f")")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.orange)
                            }
                            Text("budget")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        // Show price for offer posts - seller sees only their net price
                        Text(String(format: "$%.2f", listing.price ?? 0))
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                        
                        // Show quantity info for products with multiple units
                        if listing.listingType == .product,
                           let qtyAvailable = listing.quantityAvailable,
                           let qtySold = listing.quantitySold,
                           (qtyAvailable + qtySold) > 1 {
                            Text("\(qtySold) sold • \(qtyAvailable) left")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack(spacing: 8) {
                        // Show "Wanted" badge for seek posts
                        if AppConfig.enableSeekMode && listing.intent == .seek {
                            StatusBadge(text: "Wanted", color: .orange)
                        }
                        
                        // Status badge - assuming listing has status
                        if listing.isSold {
                            StatusBadge(text: "Sold", color: .gray)
                        } else {
                            StatusBadge(text: "Active", color: .green)
                        }
                        
                        // Date
                        Text(listing.createdAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 8) {
                    if listing.isSold {
                        Button(action: {
                            // Mark delivered action
                        }) {
                            Text("Mark Delivered")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue)
                                .cornerRadius(6)
                        }
                        .onTapGesture {
                            // Prevent navigation when button is tapped
                        }
                    }
                    
                    Button(action: {
                        // Report problem action
                    }) {
                        Text("Report Problem")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.facebookBlue)
                            .cornerRadius(6)
                    }
                    .onTapGesture {
                        // Prevent navigation when button is tapped
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(8)
            .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
    
    private struct StatusBadge: View {
        let text: String
        let color: Color
        
        var body: some View {
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color)
                .cornerRadius(4)
        }
    }
}

// MARK: - Data Loading

extension ProfileTabView {
    private func loadUser() async {
        guard let userId = authManager.session?.user.id.uuidString else { return }
        
        // Check cache first (INSTANT LOADING)
        if let cachedUser = DataCacheManager.shared.getUser(userId: userId) {
            await MainActor.run {
                self.userProfile = cachedUser
                self.isLoading = false
            }
            
            if let profilePicURL = cachedUser.profilePic {
                await loadProfileImage(from: profilePicURL)
            }
        }
        
        do {
            let response: [User] = try await supabase
                .from("users")
                .select()
                .eq("id", value: userId)
                .execute()
                .value
            
            if let profile = response.first {
                // Cache the fresh user data (10 minute TTL)
                DataCacheManager.shared.cacheUser(profile, userId: userId, ttl: 600)
                
                await MainActor.run {
                    self.userProfile = profile
                }
                
                if let profilePicURL = profile.profilePic {
                    await loadProfileImage(from: profilePicURL)
                }
            }
        } catch {
            print("Failed to load profile: \(error)")
        }
    }
    
    private func loadUserListings() async {
        guard let userId = authManager.session?.user.id.uuidString else { return }
        
        // Check cache first (INSTANT LOADING)
        if let cachedListings = DataCacheManager.shared.getUserListings(userId: userId) {
            await MainActor.run {
                self.userListings = cachedListings
                self.postsCount = cachedListings.count
                self.isLoading = false
            }
        }
        
        do {
            let response: [ListingWithUser] = try await supabase
                .from("listings")
                .select("*, user:users(*)")
                .eq("user_id", value: userId)
                .eq("status", value: "active")
                .neq("archived", value: true)  // Filter out archived listings
                .order("created_at", ascending: false)
                .limit(20)
                .execute()
                .value
            
            // Cache the fresh listings (5 minute TTL)
            DataCacheManager.shared.cacheUserListings(response, userId: userId, ttl: 300)
            
            await MainActor.run {
                self.userListings = response
                self.postsCount = response.count
            }
        } catch {
            print("Failed to load listings: \(error)")
        }
    }
    
    private func loadProfileImage(from urlString: String) async {
        guard let url = URL(string: urlString) else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                await MainActor.run {
                    self.profileImage = image
                }
            }
        } catch {
            print("Failed to load profile image: \(error)")
        }
    }
    
    private func loadRatings(userId: String) async {
        await MainActor.run { isLoadingRatings = true }
        do {
            let summary = try await RatingService.shared.getUserRatingsSummary(userId: userId)
            await MainActor.run { self.ratingsSummary = summary; self.isLoadingRatings = false }
        } catch {
            await MainActor.run { self.isLoadingRatings = false }
        }
    }
}

// MARK: - Edit Profile View

struct EditProfileView: View {
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var bio = ""
    @State private var profileImage: UIImage?
    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Picture Section
                    VStack(spacing: 16) {
                        if let profileImage = profileImage {
                            Image(uiImage: profileImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color(UIColor.systemGray5))
                                .frame(width: 120, height: 120)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 50))
                                        .foregroundColor(.gray)
                                )
                        }
                        
                        ImagePickerButton(
                            selectedImage: $profileImage,
                            label: "Change Photo",
                            icon: "camera",
                            style: .text
                        )
                    }
                    
                    // Form Fields
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Name")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            TextField("Enter your name", text: $name)
                                .padding()
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(12)
                                .autocapitalization(.words)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Bio")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            TextField("Tell us about yourself", text: $bio, axis: .vertical)
                                .lineLimit(3...6)
                                .padding()
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(12)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text(authManager.session?.user.email ?? "")
                                .padding()
                                .background(Color(UIColor.systemGray5))
                                .cornerRadius(12)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        Task {
                            await saveProfile()
                        }
                    }
                    .disabled(isLoading)
                    .fontWeight(.semibold)
                }
            }
        }
        .hideKeyboardOnTap()
        .onAppear {
            Task {
                await loadCurrentProfile()
            }
        }
        .alert(isPresented: $showingAlert) {
            Alert(title: Text("Profile Update"), message: Text(alertMessage), dismissButton: .default(Text("OK")) {
                if alertMessage.contains("successfully") {
                    dismiss()
                }
            })
        }
    }
    
    private func loadCurrentProfile() async {
        guard let userId = authManager.session?.user.id.uuidString else { return }
        
        do {
            let response: [User] = try await supabase
                .from("users")
                .select()
                .eq("id", value: userId)
                .execute()
                .value
            
            if let userProfile = response.first {
                await MainActor.run {
                    self.name = userProfile.name ?? ""
                    self.bio = userProfile.bio ?? ""
                }
                
                if let profilePicURL = userProfile.profilePic {
                    await loadProfileImage(from: profilePicURL)
                }
            }
        } catch {
            await MainActor.run {
                alertMessage = "Failed to load profile: \(error.localizedDescription)"
                showingAlert = true
            }
        }
    }
    
    private func loadProfileImage(from urlString: String) async {
        guard let url = URL(string: urlString) else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                await MainActor.run {
                    self.profileImage = image
                }
            }
        } catch {
            print("Failed to load profile image: \(error)")
        }
    }
    
    private func saveProfile() async {
        guard let userId = authManager.session?.user.id.uuidString else { return }
        
        await MainActor.run {
            isLoading = true
        }
        
        var photoURL: String? = nil
        
        // Upload image if selected
        if let profileImage = profileImage {
            do {
                guard let imageData = profileImage.jpegData(compressionQuality: 0.8) else {
                    throw NSError(domain: "ImageError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])
                }
                
                let fileName = "profile_\(userId)_\(UUID().uuidString).jpg"
                
                try await supabase.storage
                    .from("profile-pictures")
                    .upload(fileName, data: imageData)
                
                photoURL = try supabase.storage
                    .from("profile-pictures")
                    .getPublicURL(path: fileName)
                    .absoluteString
                
            } catch {
                await MainActor.run {
                    alertMessage = "Failed to upload image: \(error.localizedDescription)"
                    showingAlert = true
                    isLoading = false
                }
                return
            }
        }
        
        // Update profile
        do {
            if let photoURL = photoURL {
                // Update with photo
                try await supabase
                    .from("users")
                    .update([
                        "name": name,
                        "bio": bio,
                        "profile_pic": photoURL
                    ])
                    .eq("id", value: userId)
                    .execute()
            } else {
                // Update without photo
                try await supabase
                    .from("users")
                    .update([
                        "name": name,
                        "bio": bio
                    ])
                    .eq("id", value: userId)
                    .execute()
            }
            
            await MainActor.run {
                alertMessage = "Profile updated successfully!"
                showingAlert = true
                isLoading = false
            }
            
        } catch {
            await MainActor.run {
                alertMessage = "Failed to update profile: \(error.localizedDescription)"
                showingAlert = true
                isLoading = false
            }
        }
    }
}

struct ProfileTabView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileTabView()
            .environmentObject(AuthManager())
    }
} 