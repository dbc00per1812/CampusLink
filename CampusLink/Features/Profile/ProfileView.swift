import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var name = ""
    @State private var bio = ""
    @State private var selectedImage: PhotosPickerItem?
    @State private var profileImage: UIImage?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title)
                            .foregroundColor(Color.primary)
                    }
                    Spacer()
                    
                    Button(action: {
                        Task {
                            await saveProfile()
                        }
                    }) {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Save")
                                .fontWeight(.bold)
                                .foregroundColor(Color("ThemeColor"))
                        }
                    }
                    .disabled(isLoading)
                }
                .padding()
                
                ScrollView {
                    VStack(spacing: 20) {
                        Text("Profile")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .padding(.bottom, 20)
                        
                        // Profile Picture Section
                        VStack {
                            if let profileImage = profileImage {
                                Image(uiImage: profileImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 120, height: 120)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color("ThemeColor"), lineWidth: 3))
                            } else {
                                Circle()
                                    .fill(Color(UIColor.systemGray5))
                                    .frame(width: 120, height: 120)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 50))
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
                                    .font(.caption)
                                    .foregroundColor(Color("ThemeColor"))
                                    .padding(.top, 8)
                            }
                        }
                        
                        // User Information
                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Name")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                TextField("Enter your name", text: $name)
                                    .padding()
                                    .background(Color(UIColor.systemGray6))
                                    .cornerRadius(10)
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
                                    .cornerRadius(10)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Email")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                Text(authManager.session?.user.email ?? "")
                                    .padding()
                                    .background(Color(UIColor.systemGray5))
                                    .cornerRadius(10)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal)
                        
                        Spacer()
                    }
                }
            }
            .navigationBarHidden(true)
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
    
    private func loadUserProfile() async {
        guard let userId = authManager.session?.user.id else { return }
        
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
                
                // Load profile image if URL exists
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
        guard let userId = authManager.session?.user.id else { return }
        
        await MainActor.run {
            isLoading = true
        }
        
        var profilePicURL: String? = nil
        
        // Upload profile image if one was selected
        if let profileImage = profileImage,
           let imageData = profileImage.jpegData(compressionQuality: 0.8) {
            
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
        
        // Update user profile in database
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
    
    enum CodingKeys: String, CodingKey {
        case id, name, bio, email
        case profilePic = "profile_pic"
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

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(AuthManager())
    }
} 