import SwiftUI
import PhotosUI
import Supabase

private struct ListingUpdate: Codable {
    let title: String?
    let description: String?
    let price: Double?
    let category: String?
    let photo: String?
    let photos: [String]?
    let listingType: ListingType?
    let serviceDuration: String?
    let serviceLocation: ServiceLocation?
    let serviceAvailability: String?

    enum CodingKeys: String, CodingKey {
        case title, description, price, category, photo, photos
        case listingType = "listing_type"
        case serviceDuration = "service_duration"
        case serviceLocation = "service_location"
        case serviceAvailability = "service_availability"
    }
}

struct EditListingView: View {
    let listing: ListingWithUser
    let onUpdated: () -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager

    @State private var title: String
    @State private var description: String
    @State private var priceText: String
    @State private var category: String
    @State private var listingType: ListingType
    @State private var serviceDuration: String
    @State private var serviceLocation: ServiceLocation
    @State private var serviceAvailability: String
    @State private var selectedImage: PhotosPickerItem?
    @State private var selectedImages: [PhotosPickerItem] = []
    @State private var imageData: Data?
    @State private var imageDatas: [Data] = []
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showingImageCropper = false
    @State private var imageToCrop: UIImage?
    @State private var cropperIndex: Int = 0

    // Product categories
    private let productCategories = ["Electronics", "Books", "Furniture", "Clothing", "Sports", "Tickets", "Other"]
    
    // Service categories
    private let serviceCategories = ["Tutoring", "Moving", "Cleaning", "Other"]
    
    // Computed property for current categories based on listing type
    private var currentCategories: [String] {
        listingType == .product ? productCategories : serviceCategories
    }

    init(listing: ListingWithUser, onUpdated: @escaping () -> Void) {
        self.listing = listing
        self.onUpdated = onUpdated
        _title = State(initialValue: listing.title)
        _description = State(initialValue: listing.description)
        _priceText = State(initialValue: String(format: "%.2f", listing.price ?? 0))
        _category = State(initialValue: listing.category)
        _listingType = State(initialValue: listing.listingType)
        _serviceDuration = State(initialValue: listing.serviceDuration ?? "")
        _serviceLocation = State(initialValue: listing.serviceLocation ?? .onCampus)
        _serviceAvailability = State(initialValue: listing.serviceAvailability ?? "")
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Multiple Images picker
                    VStack(spacing: 12) {
                        if !imageDatas.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    Spacer(minLength: 0)
                                    ForEach(Array(imageDatas.enumerated()), id: \.offset) { index, data in
                                        if let ui = UIImage(data: data) {
                                            ZStack(alignment: .topTrailing) {
                                                Image(uiImage: ui)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 120, height: 120)
                                                    .clipped()
                                                    .cornerRadius(12)
                                                
                                                HStack {
                                                    Button(action: {
                                                        cropperIndex = index
                                                        imageToCrop = ui
                                                        showingImageCropper = true
                                                    }) {
                                                        Image(systemName: "crop")
                                                            .foregroundColor(.blue)
                                                            .background(Color.white)
                                                            .clipShape(Circle())
                                                    }
                                                    .offset(x: -16, y: -8)
                                                    
                                                    Button(action: {
                                                        imageDatas.remove(at: index)
                                                    }) {
                                                        Image(systemName: "xmark.circle.fill")
                                                            .foregroundColor(.red)
                                                            .background(Color.white)
                                                            .clipShape(Circle())
                                                    }
                                                    .offset(x: 8, y: -8)
                                                }
                                            }
                                        }
                                    }
                                    
                                    // Add more photos button
                                    if imageDatas.count < 10 {
                                        PhotosPicker(selection: $selectedImages, maxSelectionCount: 10, matching: .images) {
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color(UIColor.systemGray6))
                                                .frame(width: 120, height: 120)
                                                .overlay(
                                                    VStack {
                                                        Image(systemName: "plus")
                                                            .font(.system(size: 30))
                                                            .foregroundColor(.gray)
                                                        Text("Add More")
                                                            .font(.caption)
                                                            .foregroundColor(.gray)
                                                    }
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(Color("ThemeColor"), lineWidth: 2)
                                                )
                                        }
                                    }
                                    Spacer(minLength: 0)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 16)
                            }
                        } else if !listing.photos.isEmpty {
                            // Display existing photos from database
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    Spacer(minLength: 0)
                                    ForEach(Array(listing.photos.enumerated()), id: \.offset) { index, photoURL in
                                        if let url = URL(string: photoURL) {
                                            AsyncImage(url: url) { image in
                                                image
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                            } placeholder: {
                                                Rectangle().fill(Color(UIColor.systemGray5))
                                            }
                                            .frame(width: 120, height: 120)
                                            .clipped()
                                            .cornerRadius(12)
                                        }
                                    }
                                    
                                    // Add photos button
                                    PhotosPicker(selection: $selectedImages, maxSelectionCount: 10, matching: .images) {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color(UIColor.systemGray6))
                                            .frame(width: 120, height: 120)
                                            .overlay(
                                                VStack {
                                                    Image(systemName: "plus")
                                                        .font(.system(size: 30))
                                                        .foregroundColor(.gray)
                                                    Text("Add Photos")
                                                        .font(.caption)
                                                        .foregroundColor(.gray)
                                                }
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color("ThemeColor"), lineWidth: 2)
                                            )
                                    }
                                    Spacer(minLength: 0)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 16)
                            }
                        } else if let photoURL = listing.photo, let url = URL(string: photoURL) {
                            // Fallback to single photo for backward compatibility
                            VStack(spacing: 12) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                } placeholder: {
                                    Rectangle().fill(Color(UIColor.systemGray5))
                                }
                                .frame(height: 200)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .clipped()
                                .cornerRadius(12)
                                
                                PhotosPicker(selection: $selectedImages, maxSelectionCount: 10, matching: .images) {
                                    Text("Add Photos")
                                        .font(.subheadline)
                                        .foregroundColor(Color("ThemeColor"))
                                }
                            }
                        } else {
                            // No photos - show add photos button
                            PhotosPicker(selection: $selectedImages, maxSelectionCount: 10, matching: .images) {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(UIColor.systemGray6))
                                    .frame(height: 200)
                                    .overlay(
                                        VStack {
                                            Image(systemName: "photo")
                                                .font(.system(size: 40))
                                                .foregroundColor(.gray)
                                            Text("Add Photos")
                                                .font(.headline)
                                                .foregroundColor(.gray)
                                            Text("Tap to select multiple photos")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color("ThemeColor"), lineWidth: 2)
                                    )
                            }
                        }

                        PhotosPicker(selection: $selectedImage, matching: .images) {
                            Text("Change Single Photo")
                                .font(.subheadline)
                                .foregroundColor(Color("ThemeColor"))
                        }
                        .onChange(of: selectedImage) { _, newValue in
                            Task { await loadImage(from: newValue) }
                        }
                        .onChange(of: selectedImages) { _, newValue in
                            Task { await loadImages(from: newValue) }
                        }
                    }

                    // Fields
                    VStack(alignment: .leading, spacing: 12) {
                        LabeledField(title: "Title") {
                            TextField("Title", text: $title)
                                .padding()
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(10)
                        }

                        LabeledField(title: "Description") {
                            TextField("Description", text: $description, axis: .vertical)
                                .lineLimit(3...6)
                                .padding()
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(10)
                        }

                        LabeledField(title: "Price") {
                            HStack {
                                Text("$")
                                    .foregroundColor(.secondary)
                                TextField("0.00", text: $priceText)
                                    .keyboardType(.decimalPad)
                            }
                            .padding()
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(10)
                        }

                        LabeledField(title: "Category") {
                            Picker("Category", selection: $category) {
                                ForEach(currentCategories, id: \.self) { Text($0).tag($0) }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .padding()
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(10)
                        }

                        LabeledField(title: "Type") {
                            Picker("Type", selection: $listingType) {
                                ForEach(ListingType.allCases, id: \.self) { Text($0.displayName).tag($0) }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }

                        if listingType == .service {
                            LabeledField(title: "Service Duration") {
                                TextField("e.g., 1 hour", text: $serviceDuration)
                                    .padding()
                                    .background(Color(UIColor.systemGray6))
                                    .cornerRadius(10)
                            }

                            LabeledField(title: "Service Location") {
                                Picker("Location", selection: $serviceLocation) {
                                    ForEach(ServiceLocation.allCases, id: \.self) { Text($0.displayName).tag($0) }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .padding()
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(10)
                            }

                            LabeledField(title: "Availability") {
                                TextField("Schedule details", text: $serviceAvailability, axis: .vertical)
                                    .lineLimit(2...4)
                                    .padding()
                                    .background(Color(UIColor.systemGray6))
                                    .cornerRadius(10)
                            }
                        }
                    }

                    Button(action: save) {
                        HStack {
                            if isSaving { ProgressView().scaleEffect(0.9) }
                            Text(isSaving ? "Saving..." : "Save Changes")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundColor(.white)
                        .background(Color("ThemeColor"))
                        .cornerRadius(12)
                    }
                    .disabled(isSaving)
                }
                .padding()
            }
            .navigationTitle("Edit Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .hideKeyboardOnTap()
        .sheet(isPresented: $showingImageCropper) {
            if let imageToCrop = imageToCrop {
                EnhancedImageCropperView(
                    originalImage: imageToCrop,
                    onCropCompleted: { croppedImage in
                        // Replace the image data at the cropper index
                        if let croppedData = croppedImage.resizedForUpload(maxDimension: 1080, compressionQuality: 0.8) {
                            imageDatas[cropperIndex] = croppedData
                        }
                        showingImageCropper = false
                        self.imageToCrop = nil
                    },
                    onCancel: {
                        showingImageCropper = false
                        self.imageToCrop = nil
                    }
                )
            }
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) { Button("OK") { errorMessage = nil } } message: { Text(errorMessage ?? "") }
    }

    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item = item, 
              let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else { return }
        
        // Apply size constraints immediately
        let resizedData = uiImage.resizedForUpload(maxDimension: 1080, compressionQuality: 0.8) ?? data
        
        await MainActor.run { 
            imageData = resizedData 
        }
    }
    
    private func loadImages(from items: [PhotosPickerItem]) async {
        var newImageDatas: [Data] = []
        
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            
            // Apply size constraints to each image
            if let uiImage = UIImage(data: data) {
                let resizedData = uiImage.resizedForUpload(maxDimension: 1080, compressionQuality: 0.8) ?? data
                newImageDatas.append(resizedData)
            } else {
                newImageDatas.append(data)
            }
        }
        
        await MainActor.run {
            self.imageDatas = newImageDatas
        }
    }

    private func save() {
        Task {
            guard let userId = authManager.session?.user.id.uuidString else { return }
            guard let price = Double(priceText) else {
                await MainActor.run { errorMessage = "Invalid price value" }
                return
            }

            await MainActor.run { isSaving = true }

            var photoURL: String? = listing.photo
            var photoURLs: [String] = listing.photos
            
            // Upload multiple photos if selected
            if !imageDatas.isEmpty {
                for (index, data) in imageDatas.enumerated() {
                    do {
                        let fileName = "\(listing.id.uuidString)_\(UUID().uuidString)_\(index).jpg"
                        try await supabase.storage.from("listings").upload(fileName, data: data)
                        let url = try supabase.storage.from("listings").getPublicURL(path: fileName).absoluteString
                        photoURLs.append(url)
                        
                        // Set the first photo as the main photo for backward compatibility
                        if index == 0 {
                            photoURL = url
                        }
                    } catch {
                        await MainActor.run {
                            errorMessage = "Failed to upload image \(index + 1): \(error.localizedDescription)"
                            isSaving = false
                        }
                        return
                    }
                }
            } else if let data = imageData {
                // Fallback to single photo for backward compatibility
                do {
                    let fileName = "\(listing.id.uuidString)_\(UUID().uuidString).jpg"
                    try await supabase.storage.from("listings").upload(fileName, data: data)
                    photoURL = try supabase.storage.from("listings").getPublicURL(path: fileName).absoluteString
                    photoURLs = [photoURL!]
                } catch {
                    await MainActor.run {
                        errorMessage = "Failed to upload image: \(error.localizedDescription)"
                        isSaving = false
                    }
                    return
                }
            }

            let update = ListingUpdate(
                title: title,
                description: description,
                price: price,
                category: category,
                photo: photoURL,
                photos: photoURLs,
                listingType: listingType,
                serviceDuration: listingType == .service ? (serviceDuration.isEmpty ? nil : serviceDuration) : nil,
                serviceLocation: listingType == .service ? serviceLocation : nil,
                serviceAvailability: listingType == .service ? (serviceAvailability.isEmpty ? nil : serviceAvailability) : nil
            )

            do {
                // Extra safety: ensure the owner matches
                try await supabase
                    .from("listings")
                    .update(update)
                    .eq("id", value: listing.id.uuidString)
                    .eq("user_id", value: userId)
                    .execute()

                await MainActor.run {
                    isSaving = false
                    onUpdated()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "Failed to save changes: \(error.localizedDescription)"
                }
            }
        }
    }
}

private struct LabeledField<Content: View>: View {
    let title: String
    let content: () -> Content
    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline).foregroundColor(.secondary)
            content()
        }
    }
}
