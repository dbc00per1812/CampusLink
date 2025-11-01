import SwiftUI
import PhotosUI
import Supabase

struct DeliveryPhotoUploadView: View {
    let orderId: UUID
    let onPhotoUploaded: (String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedImage: UIImage?
    @State private var isUploading = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showImageSourcePicker = false
    @State private var showImagePicker = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 50))
                        .foregroundColor(Color("ThemeColor"))
                    
                    Text("Upload Delivery Photo")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Take or select a photo showing proof of delivery")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 20)
                
                // Photo Preview or Picker
                if let selectedImage = selectedImage {
                    VStack(spacing: 16) {
                        Image(uiImage: selectedImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 300)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                        
                        Button(action: { showImageSourcePicker = true }) {
                            HStack {
                                Image(systemName: "photo.on.rectangle.angled")
                                Text("Change Photo")
                            }
                            .font(.subheadline)
                            .foregroundColor(Color("ThemeColor"))
                        }
                    }
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("Select Photo")
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
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    if isUploading {
                        ProgressView("Uploading photo...")
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Button(action: uploadPhoto) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Confirm & Mark Delivered")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(selectedImage != nil ? Color.green : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(selectedImage == nil)
                        
                        Button(action: { dismiss() }) {
                            Text("Cancel")
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray6))
                                .foregroundColor(.primary)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(.bottom, 20)
            }
            .padding(.horizontal)
            .navigationTitle("Delivery Proof")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Upload Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
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
    }
    
    private func uploadPhoto() {
        guard let image = selectedImage else {
            errorMessage = "Please select a photo first"
            showError = true
            return
        }
        
        Task {
            await MainActor.run {
                isUploading = true
                errorMessage = nil
            }
            
            do {
                print("🔵 Starting photo upload for order: \(orderId)")
                
                // Resize and compress image
                guard let imageData = image.resizedForUpload() else {
                    throw NSError(domain: "ImageError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to process image"])
                }
                
                print("🔵 Image processed, size: \(imageData.count) bytes")
                
                // Generate unique filename with timestamp to avoid conflicts
                let timestamp = Int(Date().timeIntervalSince1970)
                let fileName = "\(orderId.uuidString)_\(timestamp)_delivery.jpg"
                
                print("🔵 Uploading to delivery-photos bucket with filename: \(fileName)")
                
                // Upload to Supabase storage with upsert option
                let uploadPath = try await supabase.storage
                    .from("delivery-photos")
                    .upload(
                        path: fileName,
                        file: imageData,
                        options: FileOptions(upsert: true)
                    )
                
                print("✅ Upload successful, path: \(uploadPath)")
                
                // Get public URL
                let photoURL = try supabase.storage
                    .from("delivery-photos")
                    .getPublicURL(path: fileName)
                    .absoluteString
                
                print("✅ Public URL generated: \(photoURL)")
                
                // Notify parent view with the URL
                await MainActor.run {
                    onPhotoUploaded(photoURL)
                    dismiss()
                }
                
            } catch {
                print("❌ Upload failed: \(error)")
                print("❌ Error details: \(error.localizedDescription)")
                await MainActor.run {
                    isUploading = false
                    errorMessage = "Failed to upload photo: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
}

#Preview {
    DeliveryPhotoUploadView(orderId: UUID()) { url in
        print("Photo uploaded: \(url)")
    }
}

