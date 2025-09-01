import SwiftUI
import PhotosUI
import Supabase

private struct ListingUpdate: Codable {
    let title: String?
    let description: String?
    let price: Double?
    let category: String?
    let photo: String?
    let listingType: ListingType?
    let serviceDuration: String?
    let serviceLocation: ServiceLocation?
    let serviceAvailability: String?

    enum CodingKeys: String, CodingKey {
        case title, description, price, category, photo
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
    @State private var imageData: Data?
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let categories = ["Electronics", "Books", "Furniture", "Clothing", "Sports", "Other"]

    init(listing: ListingWithUser, onUpdated: @escaping () -> Void) {
        self.listing = listing
        self.onUpdated = onUpdated
        _title = State(initialValue: listing.title)
        _description = State(initialValue: listing.description)
        _priceText = State(initialValue: String(format: "%.2f", listing.price))
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
                    // Image picker
                    VStack(spacing: 12) {
                        if let photo = imageData, let ui = UIImage(data: photo) {
                            Image(uiImage: ui)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 200)
                                .frame(maxWidth: .infinity)
                                .clipped()
                                .cornerRadius(12)
                        } else if let photoURL = listing.photo, let url = URL(string: photoURL) {
                            AsyncImage(url: url) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle().fill(Color(UIColor.systemGray5))
                            }
                            .frame(height: 200)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .cornerRadius(12)
                        }

                        PhotosPicker(selection: $selectedImage, matching: .images) {
                            Text("Change Photo")
                                .font(.subheadline)
                                .foregroundColor(Color("ThemeColor"))
                        }
                        .onChange(of: selectedImage) { _, newValue in
                            Task { await loadImage(from: newValue) }
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
                                ForEach(categories, id: \.self) { Text($0).tag($0) }
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
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) { Button("OK") { errorMessage = nil } } message: { Text(errorMessage ?? "") }
    }

    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item = item, let data = try? await item.loadTransferable(type: Data.self) else { return }
        await MainActor.run { imageData = data }
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
            if let data = imageData {
                do {
                    let fileName = "\(listing.id.uuidString)_\(UUID().uuidString).jpg"
                    try await supabase.storage.from("listings").upload(fileName, data: data)
                    photoURL = try supabase.storage.from("listings").getPublicURL(path: fileName).absoluteString
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


