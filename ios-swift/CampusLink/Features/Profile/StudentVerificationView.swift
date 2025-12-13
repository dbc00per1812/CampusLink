import SwiftUI
import PhotosUI
import Supabase

struct StudentVerificationView: View {
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedImage: UIImage?
    @State private var isUploading = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var verificationStatus: String = "unverified"
    @State private var verificationNotes: String?
    @State private var submittedDate: Date?
    @State private var showImageSourcePicker = false
    @State private var showImagePicker = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 60))
                            .foregroundColor(statusColor)
                        
                        Text(statusTitle)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(statusDescription)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top)
                    
                    // Status-specific content
                    if verificationStatus == "verified" {
                        verifiedContent
                    } else if verificationStatus == "pending" {
                        pendingContent
                    } else if verificationStatus == "rejected" {
                        rejectedContent
                    } else {
                        unverifiedContent
                    }
                }
                .padding()
            }
            .navigationTitle("Student Verification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            Task {
                await loadVerificationStatus()
            }
        }
        .alert("Verification Status", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .confirmationDialog("Choose Photo Source", isPresented: $showImageSourcePicker, titleVisibility: .visible) {
            Button("Take Photo") {
                imageSourceType = .camera
                showImagePicker = true
            }
            
            Button("Choose from Library") {
                imageSourceType = .photoLibrary
                showImagePicker = true
            }
            
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePickerView(selectedImage: $selectedImage, sourceType: imageSourceType)
        }
    }
    
    // MARK: - Status-Specific Views
    
    private var verifiedContent: some View {
        VStack(spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                Text("You are a verified student!")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
            
            Text("Your verified student badge will appear on all your listings, helping build trust with buyers and sellers.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var pendingContent: some View {
        VStack(spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "clock.fill")
                    .foregroundColor(.orange)
                    .font(.title2)
                Text("Verification pending")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
            
            if let date = submittedDate {
                Text("Submitted \(date.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("We're reviewing your student ID. This usually takes 1-2 business days. You'll be notified once your verification is complete.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var rejectedContent: some View {
        VStack(spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.facebookBlue)
                    .font(.title2)
                Text("Verification unsuccessful")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(Color.facebookBlue.opacity(0.1))
            .cornerRadius(12)
            
            if let notes = verificationNotes {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reason:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(notes)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(8)
            }
            
            Text("Please upload a clear photo of your valid student ID and try again.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            uploadSection
        }
    }
    
    private var unverifiedContent: some View {
        VStack(spacing: 24) {
            // Benefits section
            VStack(alignment: .leading, spacing: 16) {
                Text("Why verify?")
                    .font(.headline)
                
                VerificationBenefit(
                    icon: "checkmark.shield.fill",
                    title: "Build Trust",
                    description: "Show buyers and sellers you're a real student"
                )
                
                VerificationBenefit(
                    icon: "person.badge.plus",
                    title: "Stand Out",
                    description: "Get the verified student badge on all your listings"
                )
                
                VerificationBenefit(
                    icon: "lock.shield.fill",
                    title: "Safe & Secure",
                    description: "Your ID is encrypted and only used for verification"
                )
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            
            // Upload section
            uploadSection
            
            // Requirements
            VStack(alignment: .leading, spacing: 12) {
                Text("Requirements:")
                    .font(.headline)
                
                RequirementItem(text: "Valid student ID from your campus")
                RequirementItem(text: "Clear, readable photo showing your name and school")
                RequirementItem(text: "ID must not be expired")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var uploadSection: some View {
        VStack(spacing: 16) {
            // Photo picker
            if let image = selectedImage {
                VStack(spacing: 12) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .cornerRadius(12)
                    
                    Button(action: { showImageSourcePicker = true }) {
                        HStack {
                            Image(systemName: "arrow.circlepath")
                            Text("Choose Different Photo")
                        }
                        .font(.subheadline)
                        .foregroundColor(Color("ThemeColor"))
                    }
                }
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("Upload Student ID")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Take a photo or choose from library")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button(action: { showImageSourcePicker = true }) {
                        HStack {
                            Image(systemName: "photo")
                                .font(.subheadline)
                            Text("Add Photo")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(Color("ThemeColor"))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 300)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                )
            }
            
            // Submit button
            if selectedImage != nil {
                Button(action: {
                    Task {
                        await submitVerification()
                    }
                }) {
                    HStack {
                        if isUploading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        Text(isUploading ? "Uploading..." : "Submit for Verification")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color("ThemeColor"))
                    .cornerRadius(10)
                }
                .disabled(isUploading)
            }
        }
    }
    
    // MARK: - Helper Views
    
    private var statusColor: Color {
        switch verificationStatus {
        case "verified": return .green
        case "pending": return .orange
        case "rejected": return .facebookBlue
        default: return Color("ThemeColor")
        }
    }
    
    private var statusTitle: String {
        switch verificationStatus {
        case "verified": return "Verified Student"
        case "pending": return "Under Review"
        case "rejected": return "Verification Failed"
        default: return "Become a Verified Student"
        }
    }
    
    private var statusDescription: String {
        switch verificationStatus {
        case "verified": return "Your student status has been verified"
        case "pending": return "We're reviewing your student ID"
        case "rejected": return "We couldn't verify your student ID"
        default: return "Get the verified badge on your listings"
        }
    }
    
    // MARK: - Data Operations
    
    private func loadVerificationStatus() async {
        guard let userId = authManager.session?.user.id.uuidString else { return }
        
        do {
            let user: User = try await supabase
                .from("users")
                .select("verification_status, verification_notes, verification_submitted_at")
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            
            await MainActor.run {
                self.verificationStatus = user.verificationStatus ?? "unverified"
                self.verificationNotes = user.verificationNotes
                self.submittedDate = user.verificationSubmittedAt
            }
        } catch {
            print("❌ Error loading verification status: \(error)")
        }
    }
    
    private func submitVerification() async {
        guard let userId = authManager.session?.user.id.uuidString,
              let image = selectedImage else { return }
        
        await MainActor.run {
            isUploading = true
        }
        
        do {
            // Compress image
            guard let imageData = image.jpegData(compressionQuality: 0.7) else {
                throw NSError(domain: "Verification", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to compress image"])
            }
            
            // Upload to Supabase Storage
            let fileName = "\(userId)_student_id_\(Date().timeIntervalSince1970).jpg"
            let filePath = try await supabase.storage
                .from("student-ids")
                .upload(
                    path: fileName,
                    file: imageData,
                    options: FileOptions(contentType: "image/jpeg")
                )
            
            // Get public URL
            let publicURL = try supabase.storage
                .from("student-ids")
                .getPublicURL(path: fileName)
            
            // Update user record
            try await supabase
                .from("users")
                .update([
                    "verification_status": "pending",
                    "student_id_image_url": publicURL.absoluteString,
                    "verification_submitted_at": ISO8601DateFormatter().string(from: Date())
                ])
                .eq("id", value: userId)
                .execute()
            
            await MainActor.run {
                isUploading = false
                verificationStatus = "pending"
                submittedDate = Date()
                selectedImage = nil
                alertMessage = "Your student ID has been submitted for verification. We'll review it within 1-2 business days and notify you of the result."
                showingAlert = true
            }
            
        } catch {
            await MainActor.run {
                isUploading = false
                alertMessage = "Failed to submit verification: \(error.localizedDescription)"
                showingAlert = true
            }
            print("❌ Error submitting verification: \(error)")
        }
    }
}

// MARK: - Supporting Views

struct VerificationBenefit: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(Color("ThemeColor"))
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct RequirementItem: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    StudentVerificationView()
        .environmentObject(AuthManager())
}

