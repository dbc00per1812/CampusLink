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

    var body: some View {
        NavigationView {
        ScrollView {
                VStack(spacing: 0) {
                    // Header with username and menu
                    headerView
                    
                    // Profile info section (top quarter)
                    profileInfoSection
                    
                    // Posts grid (bottom three quarters)
                    postsGridSection
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            Task {
                await loadUser()
                await loadUserListings()
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
                        .font(.largeTitle)
                        .fontWeight(.bold)
            
                    Spacer()
            
                    Button(action: {
                        showSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.title2)
                            .foregroundColor(Color("ThemeColor"))
                    }
                }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }
    
    private var profileInfoSection: some View {
        VStack(spacing: 20) {
            // Profile Picture
            profilePictureView
            
            // Name and Bio
            VStack(spacing: 8) {
                Text(userProfile?.name ?? "User Name")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                if let bio = userProfile?.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // University info
                HStack {
                    Image(systemName: "graduationcap")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Text("Campus Marketplace")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // Edit Profile Button
            Button(action: {
                showEditProfile = true
            }) {
                Text("Edit Profile")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(8)
            }
            .padding(.horizontal, 40)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
    }
    
    private var profilePictureView: some View {
        Group {
            if let profileImage = profileImage {
                Image(uiImage: profileImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color(UIColor.systemGray5))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 35))
                            .foregroundColor(.gray)
                    )
            }
        }
        .overlay(
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
    

    
    private var postsGridSection: some View {
        VStack(spacing: 0) {
            // Section Header
            HStack {
                Text("My Listings")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(postsCount) posts")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
            
            // List content
            LazyVStack(spacing: 8) {
                ForEach(userListings, id: \.id) { listing in
                    listingRowItem(listing)
                }
                
                if userListings.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "square.stack.3d.up")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        
                        Text("No listings yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Start selling by creating your first listing")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 40)
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
                    
                    Text(String(format: "$%.2f", listing.price))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                    
                    HStack(spacing: 8) {
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
                            .background(Color.red)
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
            .background(Color(UIColor.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(UIColor.separator), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            .cornerRadius(8)
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
        
        do {
            let response: [User] = try await supabase
                .from("users")
                .select()
                .eq("id", value: userId)
                .execute()
                .value
            
            if let profile = response.first {
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
        
        do {
            let response: [ListingWithUser] = try await supabase
                .from("listings")
                .select("*, user:users(*)")
                .eq("user_id", value: userId)
                .eq("status", value: "active")
                .order("created_at", ascending: false)
                .limit(20)
                .execute()
                .value
            
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
}

// MARK: - Edit Profile View

struct EditProfileView: View {
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var bio = ""
    @State private var selectedImage: PhotosPickerItem?
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
                        
                        PhotosPicker(
                            selection: $selectedImage,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            Text("Change Photo")
                                .font(.subheadline)
                                .foregroundColor(Color("ThemeColor"))
                        }
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
        .onChange(of: selectedImage) { oldValue, newValue in
            Task {
                if let newValue = newValue {
                    await loadImage(from: newValue)
                }
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
    
    private func loadImage(from item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        
        await MainActor.run {
            self.profileImage = image
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