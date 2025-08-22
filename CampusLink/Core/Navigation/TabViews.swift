import SwiftUI
import PhotosUI

struct SearchView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Search")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Search for items on campus")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding()
                
                Spacer()
            }
            .navigationTitle("Search")
        }
    }
}

struct PostView: View {
    @EnvironmentObject private var authManager: AuthManager
    
    @State private var title = ""
    @State private var description = ""
    @State private var price = ""
    @State private var selectedCategory = "Electronics"
    @State private var selectedListingType = ListingType.product
    @State private var serviceDuration = ""
    @State private var selectedServiceLocation = ServiceLocation.onCampus
    @State private var serviceAvailability = ""
    @State private var selectedImage: PhotosPickerItem?
    @State private var listingImage: UIImage?
    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    let categories = ["Electronics", "Books", "Furniture", "Clothing", "Sports", "Other"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Photo Section
                    VStack(spacing: 12) {
                        if let listingImage = listingImage {
                            Image(uiImage: listingImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 200)
                                .frame(maxWidth: .infinity)
                                .clipped()
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color("ThemeColor"), lineWidth: 2)
                                )
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(UIColor.systemGray6))
                                .frame(height: 200)
                                .overlay(
                                    VStack {
                                        Image(systemName: "photo")
                                            .font(.system(size: 40))
                                            .foregroundColor(.gray)
                                        Text("Add Photo")
                                            .font(.headline)
                                            .foregroundColor(.gray)
                                    }
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color("ThemeColor"), lineWidth: 2)
                                )
                        }
                        
                        PhotosPicker(
                            selection: $selectedImage,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            Text(listingImage == nil ? "Choose Photo" : "Change Photo")
                                .font(.subheadline)
                                .foregroundColor(Color("ThemeColor"))
                        }
                    }
                    
                    // Form Fields
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Title")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            TextField(selectedListingType == .product ? "What are you selling?" : "What service are you offering?", text: $title)
                                .padding()
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(12)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            TextField(selectedListingType == .product ? "Describe your item..." : "Describe your service...", text: $description, axis: .vertical)
                                .lineLimit(4...8)
                                .padding()
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(12)
                        }
                        
                        // Listing Type Selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Type")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Picker("Listing Type", selection: $selectedListingType) {
                                ForEach(ListingType.allCases, id: \.self) { type in
                                    Text(type.displayName).tag(type)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                        
                        // Service-Specific Fields
                        if selectedListingType == .service {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Service Duration")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                TextField("e.g., 1 hour, 2-3 hours, Half day", text: $serviceDuration)
                                    .padding()
                                    .background(Color(UIColor.systemGray6))
                                    .cornerRadius(12)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Service Location")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                Picker("Location", selection: $selectedServiceLocation) {
                                    ForEach(ServiceLocation.allCases, id: \.self) { location in
                                        Text(location.displayName).tag(location)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .padding()
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(12)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Availability")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                TextField("e.g., Mon-Fri 9AM-5PM, Weekends only, Flexible schedule", text: $serviceAvailability, axis: .vertical)
                                    .lineLimit(2...4)
                                    .padding()
                                    .background(Color(UIColor.systemGray6))
                                    .cornerRadius(12)
                            }
                        }
                        
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Price")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                HStack {
                                    Text("$")
                                        .font(.title2)
                                        .foregroundColor(.secondary)
                                    TextField("0.00", text: $price)
                                        .keyboardType(.decimalPad)
                                }
                                .padding()
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(12)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Category")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                Picker("Category", selection: $selectedCategory) {
                                    ForEach(categories, id: \.self) { category in
                                        Text(category).tag(category)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .padding()
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(12)
                            }
                        }
                        
                        // Post Button
                        Button(action: {
                            Task {
                                await createListing()
                            }
                        }) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .foregroundColor(.white)
                                }
                                Text(isLoading ? "Posting..." : "Post Listing")
                            }
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color("ThemeColor"))
                            .cornerRadius(25)
                        }
                        .disabled(isLoading || title.isEmpty || description.isEmpty || price.isEmpty)
                        .opacity((title.isEmpty || description.isEmpty || price.isEmpty) ? 0.6 : 1.0)
                    }
                    .padding(.horizontal)
                }
                .padding()
            }
            .navigationTitle("Create Listing")
            .onChange(of: selectedImage) { oldValue, newValue in
                Task {
                    if let newValue = newValue {
                        await loadImage(from: newValue)
                    }
                }
            }
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("Post Listing"), message: Text(alertMessage), dismissButton: .default(Text("OK")) {
                    if alertMessage.contains("successfully") {
                        clearForm()
                    }
                })
            }
        }
    }
    
    private func loadImage(from item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        
        await MainActor.run {
            self.listingImage = image
        }
    }
    
    private func createListing() async {
        guard let userId = authManager.session?.user.id.uuidString,
              let priceValue = Double(price) else { return }
        
        await MainActor.run {
            isLoading = true
        }
        
        var photoURL: String? = nil
        
        // Upload photo if one was selected
        if let listingImage = listingImage,
           let imageData = listingImage.resizedForUpload() {
            
            do {
                let fileName = "\(UUID())_listing.jpg"
                try await supabase.storage
                    .from("listings")
                    .upload(fileName, data: imageData)
                
                photoURL = try supabase.storage
                    .from("listings")
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
        
        // Create listing in database
        do {
            let newListing = ListingCreate(
                userId: userId,
                title: title,
                description: description,
                price: priceValue,
                category: selectedCategory,
                photo: photoURL,
                listingType: selectedListingType,
                serviceDuration: selectedListingType == .service ? (serviceDuration.isEmpty ? nil : serviceDuration) : nil,
                serviceLocation: selectedListingType == .service ? selectedServiceLocation : nil,
                serviceAvailability: selectedListingType == .service ? (serviceAvailability.isEmpty ? nil : serviceAvailability) : nil
            )
            
            try await supabase
                .from("listings")
                .insert(newListing, returning: .minimal)
                .execute()
            
            await MainActor.run {
                alertMessage = "Listing posted successfully!"
                showingAlert = true
                isLoading = false
            }
            
        } catch {
            await MainActor.run {
                alertMessage = "Failed to post listing: \(error.localizedDescription)"
                showingAlert = true
                isLoading = false
            }
        }
    }
    
    private func clearForm() {
        title = ""
        description = ""
        price = ""
        selectedCategory = "Electronics"
        selectedListingType = .product
        serviceDuration = ""
        selectedServiceLocation = .onCampus
        serviceAvailability = ""
        listingImage = nil
        selectedImage = nil
    }
}

struct PostView_Previews: PreviewProvider {
    static var previews: some View {
        PostView()
            .environmentObject(AuthManager())
    }
}

struct PaymentsView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var myListings: [Listing] = []
    @State private var isLoading = true

    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    Spacer()
                    ProgressView("Loading your listings...")
                    Spacer()
                } else if myListings.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "tag")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No listings yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Post your first item using the Post tab!")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(myListings) { listing in
                                MyListingCard(listing: listing, onDelete: {
                                    Task {
                                        await deleteListing(listing)
                                    }
                                }, onToggleSold: {
                                    Task {
                                        await toggleSoldStatus(listing)
                                    }
                                })
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("My Listings")
            .onAppear {
                Task {
                    await loadMyListings()
                }
            }
        }
    }
    
    private func loadMyListings() async {
        guard let userId = authManager.session?.user.id.uuidString else { return }
        
        do {
            let response: [Listing] = try await supabase
                .from("listings")
                .select()
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            await MainActor.run {
                self.myListings = response
                self.isLoading = false
            }
            
        } catch {
            print("Failed to load my listings: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    private func deleteListing(_ listing: Listing) async {
        do {
            try await supabase
                .from("listings")
                .delete()
                .eq("id", value: listing.id)
                .execute()
            
            await MainActor.run {
                myListings.removeAll { $0.id == listing.id }
            }
        } catch {
            print("Failed to delete listing: \(error)")
        }
    }
    
    private func toggleSoldStatus(_ listing: Listing) async {
        do {
            try await supabase
                .from("listings")
                .update(["is_sold": !listing.isSold])
                .eq("id", value: listing.id)
                .execute()
            
            await MainActor.run {
                if let index = myListings.firstIndex(where: { $0.id == listing.id }) {
                    myListings[index] = Listing(
                        id: listing.id,
                        userId: listing.userId,
                        title: listing.title,
                        description: listing.description,
                        price: listing.price,
                        category: listing.category,
                        photo: listing.photo,
                        isSold: !listing.isSold,
                        listingType: listing.listingType,
                        serviceDuration: listing.serviceDuration,
                        serviceLocation: listing.serviceLocation,
                        serviceAvailability: listing.serviceAvailability,
                        createdAt: listing.createdAt
                    )
                }
            }
        } catch {
            print("Failed to update listing: \(error)")
        }
    }
}

struct MyListingCard: View {
    let listing: Listing
    let onDelete: () -> Void
    let onToggleSold: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Photo
            if let photoURL = listing.photo, let url = URL(string: photoURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color(UIColor.systemGray5))
                        .overlay(
                            ProgressView()
                        )
                }
                .frame(height: 150)
                .frame(maxWidth: .infinity)
                .clipped()
                .cornerRadius(12)
                .overlay(
                    // Sold overlay
                    listing.isSold ? 
                    Rectangle()
                        .fill(Color.black.opacity(0.6))
                        .cornerRadius(12)
                        .overlay(
                            Text("SOLD")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        ) : nil
                )
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(listing.title)
                            .font(.headline)
                            .lineLimit(2)
                        Text("$\(listing.price, specifier: "%.2f")")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(Color("ThemeColor"))
                    }
                    Spacer()
                    
                    // Status badge
                    Text(listing.isSold ? "Sold" : "Active")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(listing.isSold ? Color.gray : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                Text(listing.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                Text(listing.category)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color("ThemeColor").opacity(0.2))
                    .foregroundColor(Color("ThemeColor"))
                    .cornerRadius(6)
                
                // Action buttons
                HStack(spacing: 12) {
                    Button(action: onToggleSold) {
                        Text(listing.isSold ? "Mark Available" : "Mark as Sold")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(listing.isSold ? Color.green : Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    
                    Spacer()
                    
                    Button(action: onDelete) {
                        Text("Delete")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        SearchView()
    }
}

struct PaymentsView_Previews: PreviewProvider {
    static var previews: some View {
        PaymentsView()
            .environmentObject(AuthManager())
    }
} 