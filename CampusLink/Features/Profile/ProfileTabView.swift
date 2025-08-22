import SwiftUI
import PhotosUI

struct ProfileTabView: View {
    @EnvironmentObject private var authManager: AuthManager
    
    @State private var name = ""
    @State private var bio = ""
    @State private var selectedImage: PhotosPickerItem?
    @State private var profileImage: UIImage?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    @State private var showSettings = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    VStack(spacing: 16) {
                        if let profileImage = profileImage {
                            Image(uiImage: profileImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color("ThemeColor"), lineWidth: 3))
                        } else {
                            Circle()
                                .fill(Color(UIColor.systemGray5))
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.gray)
                                )
                                .overlay(Circle().stroke(Color("ThemeColor"), lineWidth: 3))
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
                    
                    // Profile Information
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
                        
                        // Save Button
                        Button(action: {
                            Task {
                                await saveProfile()
                            }
                        }) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .foregroundColor(.white)
                                }
                                Text(isLoading ? "Saving..." : "Save Changes")
                            }
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color("ThemeColor"))
                            .cornerRadius(25)
                        }
                        .disabled(isLoading)
                        
                        // My Transactions
                        NavigationLink(destination: MyTransactionsView().environmentObject(authManager)) {
                            Text("My Transactions")
                                .fontWeight(.bold)
                                .foregroundColor(Color("ThemeColor"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 25)
                                        .stroke(Color("ThemeColor"), lineWidth: 2)
                                )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding()
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(Color("ThemeColor"))
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(authManager)
            }
            .onAppear {
                Task {
                    await loadUserProfile()
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
                Alert(title: Text("Profile Update"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }
    
    // Include all the existing profile functions from ProfileView
    private func loadUserProfile() async {
        guard let userId = authManager.session?.user.id.uuidString else { return }
        
        do {
            let response: [UserProfile] = try await supabase
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
        
        var profilePicURL: String? = nil
        
        if let profileImage = profileImage,
           let imageData = profileImage.resizedForProfile() {
            
            do {
                let fileName = "\(userId)_profile.jpg"
                try await supabase.storage
                    .from("profiles")
                    .upload(fileName, data: imageData)
                
                profilePicURL = try supabase.storage
                    .from("profiles")
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
        
        do {
            if let profilePicURL = profilePicURL {
                let updateData = UserProfileUpdate(name: name, bio: bio, profilePic: profilePicURL)
                try await supabase
                    .from("users")
                    .update(updateData, returning: .minimal)
                    .eq("id", value: userId)
                    .execute()
            } else {
                let updateData = UserProfileUpdateWithoutPic(name: name, bio: bio)
                try await supabase
                    .from("users")
                    .update(updateData, returning: .minimal)
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

struct UserProfile: Codable {
    let id: String
    let name: String?
    let bio: String?
    let profilePic: String?
    let email: String?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, name, bio, email
        case profilePic = "profile_pic"
        case createdAt = "created_at"
    }
}

struct UserProfileUpdate: Codable {
    let name: String
    let bio: String
    let profilePic: String
    
    enum CodingKeys: String, CodingKey {
        case name, bio
        case profilePic = "profile_pic"
    }
}

struct UserProfileUpdateWithoutPic: Codable {
    let name: String
    let bio: String
}

struct ProfileTabView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileTabView()
            .environmentObject(AuthManager())
    }
} 