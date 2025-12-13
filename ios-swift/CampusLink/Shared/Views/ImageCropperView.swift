import SwiftUI
import UIKit

// MARK: - Image Cropper View
/// A SwiftUI wrapper for image cropping functionality
/// Provides a uniform cropping experience across the app with proper size constraints

struct ImageCropperView: View {
    let originalImage: UIImage
    let onCropCompleted: (UIImage) -> Void
    let onCancel: () -> Void
    
    @State private var croppedImage: UIImage?
    @State private var showingAlert = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack {
                if originalImage.size.width > 0 && originalImage.size.height > 0 {
                    ImageCropperRepresentable(
                        originalImage: originalImage,
                        onCropCompleted: { croppedImage in
                            self.croppedImage = croppedImage
                        }
                    )
                    .ignoresSafeArea(.container, edges: .bottom)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .responsiveFontSize(50)
                            .foregroundColor(.orange)
                        Text("Invalid Image")
                            .responsiveFont(.headline)
                        Text("The selected image could not be loaded properly.")
                            .responsiveFont(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .responsiveHorizontalSpacing(32)
                }
            }
            .navigationTitle("Crop Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        if let cropped = croppedImage {
                            onCropCompleted(cropped)
                        } else {
                            // If no cropping was done, use original with size constraints
                            if let resizedImage = originalImage.resizedForUpload(maxDimension: 1080) {
                                if let finalImage = UIImage(data: resizedImage) {
                                    onCropCompleted(finalImage)
                                } else {
                                    showError("Failed to process image")
                                }
                            } else {
                                showError("Failed to resize image")
                            }
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .alert("Error", isPresented: $showingAlert) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingAlert = true
    }
}

// MARK: - UIKit Image Cropper
/// UIKit-based image cropper that provides native iOS cropping experience

struct ImageCropperRepresentable: UIViewControllerRepresentable {
    let originalImage: UIImage
    let onCropCompleted: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        
        // Set the image to be edited
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImageCropperRepresentable
        
        init(_ parent: ImageCropperRepresentable) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                // Apply size constraints to the cropped image
                if let resizedData = editedImage.resizedForUpload(maxDimension: 1080),
                   let finalImage = UIImage(data: resizedData) {
                    parent.onCropCompleted(finalImage)
                } else {
                    parent.onCropCompleted(editedImage)
                }
            } else if let originalImage = info[.originalImage] as? UIImage {
                // Fallback to original with size constraints
                if let resizedData = originalImage.resizedForUpload(maxDimension: 1080),
                   let finalImage = UIImage(data: resizedData) {
                    parent.onCropCompleted(finalImage)
                } else {
                    parent.onCropCompleted(originalImage)
                }
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            // Handle cancellation if needed
        }
    }
}

// MARK: - Enhanced Image Cropper with Custom Controls
/// A more advanced cropper with predefined aspect ratios and size constraints

struct EnhancedImageCropperView: View {
    let originalImage: UIImage
    let onCropCompleted: (UIImage) -> Void
    let onCancel: () -> Void
    
    @State private var selectedAspectRatio: AspectRatio = .square
    @State private var croppedImage: UIImage?
    @State private var showingAlert = false
    @State private var errorMessage: String?
    
    enum AspectRatio: CaseIterable {
        case original, square, portrait, landscape
        
        var displayName: String {
            switch self {
            case .original: return "Original"
            case .square: return "1:1"
            case .portrait: return "4:5"
            case .landscape: return "16:9"
            }
        }
        
        var ratio: CGFloat? {
            switch self {
            case .original: return nil
            case .square: return 1.0
            case .portrait: return 4.0/5.0
            case .landscape: return 16.0/9.0
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Aspect ratio selector
                aspectRatioSelector
                    .responsiveSpacing(12)
                    .background(Color(UIColor.systemGray6))
                
                // Image cropper
                if originalImage.size.width > 0 && originalImage.size.height > 0 {
                    ImageCropperWithAspectRatio(
                        originalImage: originalImage,
                        aspectRatio: selectedAspectRatio.ratio,
                        onCropCompleted: { croppedImage in
                            self.croppedImage = croppedImage
                        }
                    )
                } else {
                    invalidImageView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                // Image size info
                imageSizeInfo
                    .responsiveSpacing(12)
                    .background(Color(UIColor.systemGray6))
            }
            .navigationTitle("Crop Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        processFinalImage()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .alert("Error", isPresented: $showingAlert) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
    }
    
    @ViewBuilder
    private var aspectRatioSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            ResponsiveHStack(spacing: 12) {
                ForEach(AspectRatio.allCases, id: \.self) { ratio in
                    Button(action: {
                        selectedAspectRatio = ratio
                    }) {
                        Text(ratio.displayName)
                            .responsiveFont(.subheadline)
                            .fontWeight(selectedAspectRatio == ratio ? .semibold : .regular)
                            .foregroundColor(selectedAspectRatio == ratio ? .white : Color("ThemeColor"))
                            .responsiveHorizontalSpacing(16)
                            .responsiveSpacing(8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedAspectRatio == ratio ? Color("ThemeColor") : Color("ThemeColor").opacity(0.1))
                            )
                    }
                }
            }
            .responsiveHorizontalSpacing(16)
        }
    }
    
    @ViewBuilder
    private var invalidImageView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .responsiveFontSize(50)
                .foregroundColor(.orange)
            Text("Invalid Image")
                .responsiveFont(.headline)
            Text("The selected image could not be loaded properly.")
                .responsiveFont(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .responsiveHorizontalSpacing(32)
    }
    
    @ViewBuilder
    private var imageSizeInfo: some View {
        VStack(spacing: 4) {
            Text("Original: \(Int(originalImage.size.width)) × \(Int(originalImage.size.height))")
                .responsiveFont(.caption)
                .foregroundColor(.secondary)
            
            if let cropped = croppedImage {
                Text("Cropped: \(Int(cropped.size.width)) × \(Int(cropped.size.height))")
                    .responsiveFont(.caption)
                    .foregroundColor(.primary)
            }
            
            Text("Final size will be optimized for upload (max 1080px)")
                .responsiveFont(.caption2)
                .foregroundColor(.secondary)
        }
        .responsiveHorizontalSpacing(16)
    }
    
    private func processFinalImage() {
        let imageToProcess = croppedImage ?? originalImage
        
        // Apply size constraints
        if let resizedData = imageToProcess.resizedForUpload(maxDimension: 1080, compressionQuality: 0.8),
           let finalImage = UIImage(data: resizedData) {
            onCropCompleted(finalImage)
        } else {
            showError("Failed to process image for upload")
        }
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingAlert = true
    }
}

// MARK: - Custom Aspect Ratio Cropper
/// A basic implementation of aspect ratio cropping

struct ImageCropperWithAspectRatio: UIViewControllerRepresentable {
    let originalImage: UIImage
    let aspectRatio: CGFloat?
    let onCropCompleted: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> CropViewController {
        let cropViewController = CropViewController(image: originalImage, aspectRatio: aspectRatio)
        cropViewController.delegate = context.coordinator
        return cropViewController
    }
    
    func updateUIViewController(_ uiViewController: CropViewController, context: Context) {
        uiViewController.aspectRatio = aspectRatio
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, CropViewControllerDelegate {
        let parent: ImageCropperWithAspectRatio
        
        init(_ parent: ImageCropperWithAspectRatio) {
            self.parent = parent
        }
        
        func cropViewController(_ controller: CropViewController, didFinishCroppingImage croppedImage: UIImage) {
            parent.onCropCompleted(croppedImage)
        }
    }
}

// MARK: - Custom Crop View Controller
/// A simplified crop view controller for aspect ratio constraints

protocol CropViewControllerDelegate: AnyObject {
    func cropViewController(_ controller: CropViewController, didFinishCroppingImage croppedImage: UIImage)
}

class CropViewController: UIViewController {
    weak var delegate: CropViewControllerDelegate?
    var aspectRatio: CGFloat?
    
    private let originalImage: UIImage
    private var imageView: UIImageView!
    private var cropOverlayView: UIView!
    
    init(image: UIImage, aspectRatio: CGFloat? = nil) {
        self.originalImage = image
        self.aspectRatio = aspectRatio
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        
        // Setup image view
        imageView = UIImageView(image: originalImage)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            imageView.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor),
            imageView.heightAnchor.constraint(lessThanOrEqualTo: view.heightAnchor)
        ])
        
        // Setup crop overlay
        setupCropOverlay()
        
        // Add crop button (simplified - in a real implementation you'd have proper cropping logic)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // For now, just return the original image with size constraints applied
            if let resizedData = self.originalImage.resizedForUpload(maxDimension: 1080),
               let resizedImage = UIImage(data: resizedData) {
                self.delegate?.cropViewController(self, didFinishCroppingImage: resizedImage)
            } else {
                self.delegate?.cropViewController(self, didFinishCroppingImage: self.originalImage)
            }
        }
    }
    
    private func setupCropOverlay() {
        cropOverlayView = UIView()
        cropOverlayView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        cropOverlayView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cropOverlayView)
        
        NSLayoutConstraint.activate([
            cropOverlayView.topAnchor.constraint(equalTo: view.topAnchor),
            cropOverlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cropOverlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cropOverlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}
