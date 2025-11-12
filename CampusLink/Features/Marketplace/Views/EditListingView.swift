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
    let deliveryMethod: DeliveryMethod?
    let quantityAvailable: Int?
    let acceptsOffers: Bool?

    enum CodingKeys: String, CodingKey {
        case title, description, price, category, photo, photos
        case listingType = "listing_type"
        case serviceDuration = "service_duration"
        case serviceLocation = "service_location"
        case serviceAvailability = "service_availability"
        case deliveryMethod = "delivery_method"
        case quantityAvailable = "quantity_available"
        case acceptsOffers = "accepts_offers"
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
    @State private var deliveryMethod: DeliveryMethod
    @State private var newImages: [UIImage] = []
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showingImageCropper = false
    @State private var imageToCrop: UIImage?
    @State private var cropperIndex: Int = 0
    @State private var quantity: Int
    @State private var acceptsOffers: Bool

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
        _deliveryMethod = State(initialValue: listing.deliveryMethod ?? .pickup)
        _quantity = State(initialValue: listing.quantityAvailable ?? 1)
        _acceptsOffers = State(initialValue: listing.acceptsOffers ?? false)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Multiple Images picker
                    VStack(spacing: 12) {
                        if !newImages.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    Spacer(minLength: 0)
                                    ForEach(Array(newImages.enumerated()), id: \.offset) { index, image in
                                        ZStack(alignment: .topTrailing) {
                                            Image(uiImage: image)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 120, height: 120)
                                                .clipped()
                                                .cornerRadius(12)
                                            
                                            HStack {
                                                Button(action: {
                                                    cropperIndex = index
                                                    imageToCrop = image
                                                    showingImageCropper = true
                                                }) {
                                                    Image(systemName: "crop")
                                                        .foregroundColor(.blue)
                                                        .background(Color.white)
                                                        .clipShape(Circle())
                                                }
                                                .offset(x: -16, y: -8)
                                                
                                                Button(action: {
                                                    newImages.remove(at: index)
                                                }) {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .foregroundColor(.facebookBlue)
                                                        .background(Color.white)
                                                        .clipShape(Circle())
                                                }
                                                .offset(x: 8, y: -8)
                                            }
                                        }
                                    }
                                    
                                    // Add more photos button
                                    if newImages.count < 10 {
                                        MultiImagePickerButton(
                                            selectedImages: $newImages,
                                            maxSelectionCount: 10,
                                            label: "",
                                            icon: "plus",
                                            style: .outlined
                                        )
                                        .frame(width: 120, height: 120)
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
                                    MultiImagePickerButton(
                                        selectedImages: $newImages,
                                        maxSelectionCount: 10,
                                        label: "",
                                        icon: "plus",
                                        style: .outlined
                                    )
                                    .frame(width: 120, height: 120)
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
                                
                                MultiImagePickerButton(
                                    selectedImages: $newImages,
                                    maxSelectionCount: 10,
                                    label: "Add Photos",
                                    icon: "camera",
                                    style: .text
                                )
                            }
                        } else {
                            // No photos - show add photos button
                            ImagePlaceholderView(
                                title: "Add Photos",
                                subtitle: "Take photos or choose from library",
                                icon: "photo",
                                onTap: {}
                            )
                            .frame(height: 200)
                            .overlay(
                                MultiImagePickerButton(
                                    selectedImages: $newImages,
                                    maxSelectionCount: 10,
                                    label: "",
                                    icon: "",
                                    style: .text
                                )
                                .opacity(0)
                            )
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
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("$")
                                        .foregroundColor(.secondary)
                                    TextField("0.00", text: $priceText)
                                        .keyboardType(.decimalPad)
                                }
                                .padding()
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(10)
                                
                                Text("Amount you'll receive")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 4)
                            }
                        }
                        
                        // Accept Offers Toggle (only for regular listings with intent='offer')
                        if listing.intent == .offer {
                            VStack(alignment: .leading, spacing: 8) {
                                Toggle(isOn: $acceptsOffers) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Accept Offers")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Text("Let buyers negotiate the price with you")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding()
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(10)
                            }
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
                        
                        // Show ticket guarantee info when Tickets category is selected
                        if category == "Tickets" {
                            TicketGuaranteeInfoView(isOwnListing: true)
                        }
                        
                        // Show product verification info for products
                        if listingType == .product {
                            ProductVerificationInfoView(isForSeller: true)
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
                            
                            // Service Verification Info for sellers
                            ServiceVerificationInfoView(isForSeller: true)
                                .padding(.top, 4)
                        }
                        
                        // Delivery Method Picker (for products only)
                        if listingType == .product {
                            LabeledField(title: "Delivery Method") {
                                VStack(spacing: 8) {
                                    Picker("Delivery Method", selection: $deliveryMethod) {
                                        ForEach(DeliveryMethod.allCases, id: \.self) { method in
                                            Text(method.displayName).tag(method)
                                        }
                                    }
                                    .pickerStyle(SegmentedPickerStyle())
                                    
                                    Text(deliveryMethod.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        // Quantity selector (for products only)
                        if listingType == .product {
                            LabeledField(title: "Quantity Available") {
                                VStack(spacing: 8) {
                                    HStack {
                                        Button(action: {
                                            if quantity > 1 {
                                                quantity -= 1
                                            }
                                        }) {
                                            Image(systemName: "minus.circle.fill")
                                                .font(.title2)
                                                .foregroundColor(quantity > 1 ? Color("ThemeColor") : .gray)
                                        }
                                        .disabled(quantity <= 1)
                                        
                                        Text("\(quantity)")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .frame(minWidth: 50)
                                        
                                        Button(action: {
                                            if quantity < 999 {
                                                quantity += 1
                                            }
                                        }) {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.title2)
                                                .foregroundColor(Color("ThemeColor"))
                                        }
                                    }
                                    .padding()
                                    .background(Color(UIColor.systemGray6))
                                    .cornerRadius(10)
                                    
                                    Text("How many units are available?")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
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
                        // Replace the image at the cropper index
                        newImages[cropperIndex] = croppedImage
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
            if !newImages.isEmpty {
                for (index, image) in newImages.enumerated() {
                    guard let data = image.resizedForUpload(maxDimension: 1080, compressionQuality: 0.8) else {
                        await MainActor.run {
                            errorMessage = "Failed to process image \(index + 1)"
                            isSaving = false
                        }
                        return
                    }
                    
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
            }
            // If no new images, keep existing photos

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
                serviceAvailability: listingType == .service ? (serviceAvailability.isEmpty ? nil : serviceAvailability) : nil,
                deliveryMethod: listingType == .product ? deliveryMethod : nil,
                quantityAvailable: listingType == .product ? quantity : nil,
                acceptsOffers: listing.intent == .offer ? acceptsOffers : nil
            )

            #if DEBUG
            print("🔍 EditListingView: Saving listing update")
            print("   - Listing ID: \(listing.id.uuidString)")
            print("   - Listing intent: \(listing.intent)")
            print("   - acceptsOffers toggle value: \(acceptsOffers)")
            print("   - acceptsOffers being sent: \(listing.intent == .offer ? String(describing: acceptsOffers) : "nil")")
            #endif

            do {
                // Extra safety: ensure the owner matches
                try await supabase
                    .from("listings")
                    .update(update)
                    .eq("id", value: listing.id.uuidString)
                    .eq("user_id", value: userId)
                    .execute()

                #if DEBUG
                print("✅ EditListingView: Update successful")
                #endif

                await MainActor.run {
                    isSaving = false
                    onUpdated()
                    dismiss()
                }
            } catch {
                #if DEBUG
                print("❌ EditListingView: Update failed - \(error.localizedDescription)")
                print("   Full error: \(error)")
                #endif
                
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
