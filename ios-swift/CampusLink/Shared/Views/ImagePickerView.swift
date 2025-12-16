import SwiftUI
import UIKit
import PhotosUI

// MARK: - Image Picker View
/// A reusable component that provides options for both camera and photo library
/// Displays an action sheet with "Take Photo" and "Choose from Library" options

struct ImagePickerView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    let sourceType: UIImagePickerController.SourceType
    let allowsEditing: Bool
    
    init(selectedImage: Binding<UIImage?>, sourceType: UIImagePickerController.SourceType, allowsEditing: Bool = true) {
        self._selectedImage = selectedImage
        self.sourceType = sourceType
        self.allowsEditing = allowsEditing
    }
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        picker.allowsEditing = allowsEditing
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerView
        
        init(_ parent: ImagePickerView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.selectedImage = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.selectedImage = originalImage
            }
            
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Image Picker Button
/// A button that shows an action sheet with camera and library options

struct ImagePickerButton: View {
    @Binding var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var showActionSheet = false
    
    let label: String
    let icon: String
    let style: ButtonStyle
    
    enum ButtonStyle {
        case filled
        case outlined
        case text
    }
    
    init(
        selectedImage: Binding<UIImage?>,
        label: String = "Add Photo",
        icon: String = "photo",
        style: ButtonStyle = .filled
    ) {
        self._selectedImage = selectedImage
        self.label = label
        self.icon = icon
        self.style = style
    }
    
    var body: some View {
        Button(action: {
            showActionSheet = true
        }) {
            buttonContent
        }
        .confirmationDialog("Choose Photo Source", isPresented: $showActionSheet, titleVisibility: .visible) {
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
    
    @ViewBuilder
    private var buttonContent: some View {
        switch style {
        case .filled:
            HStack {
                Image(systemName: icon)
                    .font(.subheadline)
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(Color("ThemeColor"))
            .cornerRadius(12)
            
        case .outlined:
            HStack {
                Image(systemName: icon)
                    .font(.subheadline)
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(Color("ThemeColor"))
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color("ThemeColor"), lineWidth: 2)
            )
            
        case .text:
            HStack {
                Image(systemName: icon)
                Text(label)
            }
            .font(.subheadline)
            .foregroundColor(Color("ThemeColor"))
        }
    }
}

// MARK: - Multi-Image Picker Button
/// A button for selecting multiple images with camera and library options

struct MultiImagePickerButton: View {
    @Binding var selectedImages: [UIImage]
    @State private var showImagePicker = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var showActionSheet = false
    @State private var tempImage: UIImage?
    
    let maxSelectionCount: Int
    let label: String
    let icon: String
    let style: ImagePickerButton.ButtonStyle
    
    init(
        selectedImages: Binding<[UIImage]>,
        maxSelectionCount: Int = 10,
        label: String = "Add Photos",
        icon: String = "photo",
        style: ImagePickerButton.ButtonStyle = .filled
    ) {
        self._selectedImages = selectedImages
        self.maxSelectionCount = maxSelectionCount
        self.label = label
        self.icon = icon
        self.style = style
    }
    
    var body: some View {
        Button(action: {
            if selectedImages.count >= maxSelectionCount {
                // Could show an alert here
                return
            }
            showActionSheet = true
        }) {
            buttonContent
        }
        .confirmationDialog("Choose Photo Source", isPresented: $showActionSheet, titleVisibility: .visible) {
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
            if imageSourceType == .camera {
                ImagePickerView(selectedImage: $tempImage, sourceType: .camera)
            } else {
                PhotosPickerMultiView(selectedImages: $selectedImages, maxSelectionCount: maxSelectionCount)
            }
        }
        .onChange(of: tempImage) { _, newValue in
            if let image = newValue {
                selectedImages.append(image)
                tempImage = nil
            }
        }
        .disabled(selectedImages.count >= maxSelectionCount)
    }
    
    @ViewBuilder
    private var buttonContent: some View {
        switch style {
        case .filled:
            HStack {
                Image(systemName: icon)
                    .font(.subheadline)
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(selectedImages.count >= maxSelectionCount ? Color.gray : Color("ThemeColor"))
            .cornerRadius(12)
            
        case .outlined:
            HStack {
                Image(systemName: icon)
                    .font(.subheadline)
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(selectedImages.count >= maxSelectionCount ? .gray : Color("ThemeColor"))
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedImages.count >= maxSelectionCount ? .gray : Color("ThemeColor"), lineWidth: 2)
            )
            
        case .text:
            HStack {
                Image(systemName: icon)
                Text(label)
            }
            .font(.subheadline)
            .foregroundColor(selectedImages.count >= maxSelectionCount ? .gray : Color("ThemeColor"))
        }
    }
}

// MARK: - PhotosPicker Multi-View Wrapper
/// Wrapper for PhotosPicker to work with UIImage array

struct PhotosPickerMultiView: View {
    @Binding var selectedImages: [UIImage]
    @State private var selectedItems: [PhotosPickerItem] = []
    let maxSelectionCount: Int
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                PhotosPicker(
                    selection: $selectedItems,
                    maxSelectionCount: maxSelectionCount - selectedImages.count,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    VStack(spacing: 20) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 60))
                            .foregroundColor(Color("ThemeColor"))
                        
                        Text("Select Photos")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Choose up to \(maxSelectionCount - selectedImages.count) photos")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Image(systemName: "photo")
                                .font(.subheadline)
                            Text("Choose from Library")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 32)
                        .background(Color("ThemeColor"))
                        .cornerRadius(12)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                }
                .onChange(of: selectedItems) { _, newItems in
                    Task {
                        await loadImages(from: newItems)
                        // Auto-dismiss after loading images
                        if !newItems.isEmpty {
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Select Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func loadImages(from items: [PhotosPickerItem]) async {
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    if selectedImages.count < maxSelectionCount {
                        selectedImages.append(image)
                    }
                }
            }
        }
    }
}

// MARK: - Image Placeholder View
/// A placeholder view for when no image is selected

struct ImagePlaceholderView: View {
    let title: String
    let subtitle: String
    let icon: String
    let onTap: () -> Void
    
    init(
        title: String = "Add Photo",
        subtitle: String = "Take a photo or choose from library",
        icon: String = "photo.badge.plus",
        onTap: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.onTap = onTap
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 250)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
            )
        }
    }
}

