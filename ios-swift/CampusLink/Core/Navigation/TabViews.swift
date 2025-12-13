import SwiftUI
import PhotosUI
import Supabase

struct SearchView: View {
    var body: some View {
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
    }
}


struct PostView: View {
    @EnvironmentObject private var authManager: AuthManager
    
    @State private var title = ""
    @State private var description = ""
    @State private var price = ""
    @State private var selectedCategory = ""
    @State private var customCategory = ""
    @State private var showingCustomCategoryField = false
    @State private var selectedListingType = ListingType.product
    @State private var serviceDuration = ""
    @State private var selectedServiceLocation = ServiceLocation.onCampus
    @State private var serviceAvailability = ""
    @State private var listingImages: [UIImage] = []
    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var navigateToHome = false
    
    // Share sheet states
    @State private var showingShareSheet = false
    @State private var sharedListingId = ""
    @State private var sharedListingTitle = ""
    @State private var sharedListingDescription = ""
    @State private var sharedListingPrice = ""
    @State private var sharedListingImageURL: String? = nil
    @State private var userProfile: User? = nil
    @State private var isLoadingProfile = true
    @State private var shouldShowPayoutSetup = false
    @State private var stripeConnectComplete = false
    
    // Seek mode states (Phase 0)
    @State private var selectedIntent: ListingIntent = .offer
    @State private var budgetMin = ""
    @State private var budgetMax = ""
    @State private var expiresDate = Date().addingTimeInterval(7 * 24 * 60 * 60) // 7 days default
    
    // Ticket event date (required for ticket listings)
    @State private var eventDate = Date().addingTimeInterval(24 * 60 * 60) // Tomorrow by default
    
    // Delivery method
    @State private var selectedDeliveryMethod: DeliveryMethod = .pickup
    
    // Quantity for products
    @State private var quantity: Int = 1
    
    // Accept offers toggle
    @State private var acceptsOffers: Bool = false
    
    // Add focus state for keyboard dismissal
    @FocusState private var isTextFieldFocused: Bool
    
    // Product categories
    let productCategories = ["Choose", "Electronics", "Books", "Furniture", "Clothing", "Sports", "Tickets", "Other"]
    
    // Service categories
    let serviceCategories = ["Choose", "Tutoring", "Moving", "Cleaning", "Other"]
    
    // Computed property for current categories based on listing type
    private var currentCategories: [String] {
        selectedListingType == .product ? productCategories : serviceCategories
    }
    
    // Computed property for title placeholder
    private var titlePlaceholder: String {
        if selectedIntent == .seek {
            return selectedListingType == .product ? "What do you want to buy?" : "What service do you need?"
        } else {
            return selectedListingType == .product ? "What are you selling?" : "What service are you offering?"
        }
    }
    
    // Computed property for description placeholder
    private var descriptionPlaceholder: String {
        if selectedIntent == .seek {
            return selectedListingType == .product ? "Describe what you're looking for..." : "Describe the service you need..."
        } else {
            return selectedListingType == .product ? "Describe your item..." : "Describe your service..."
        }
    }
    
    // Computed property for button disabled state
    private var isDisabled: Bool {
        if isLoading || title.isEmpty || description.isEmpty {
            return true
        }
        
        // Require at least one photo
        if listingImages.isEmpty {
            return true
        }
        
        // Require category selection
        if selectedCategory.isEmpty || selectedCategory == "Choose" {
            return true
        }
        
        // For "Other" category, require custom category text
        if selectedCategory == "Other" && customCategory.isEmpty {
            return true
        }
        
        // For "Tickets" category, require event date to be in the future
        if selectedCategory == "Tickets" && eventDate <= Date() {
            return true
        }
        
        if AppConfig.enableSeekMode && selectedIntent == .seek {
            // For seeks, require at least max budget
            return budgetMax.isEmpty
        } else {
            // For offers, require price
            return price.isEmpty
        }
    }
    
    // Helper for button text
    private func getButtonText() -> String {
        if AppConfig.enableSeekMode && selectedIntent == .seek {
            return "Post Wanted"
        } else {
            return "Post Listing"
        }
    }
    
    var body: some View {
        NavigationView {
            // Always show posting form - no onboarding required upfront!
            // Sellers will be prompted to complete onboarding when they make their first sale
            postingFormView
        }
    }
    
    private var payoutRequiredView: some View {
        VStack(spacing: 24) {
            Image(systemName: "creditcard.circle")
                .font(.system(size: 80))
                .foregroundColor(Color("ThemeColor"))
            
            VStack(spacing: 12) {
                Text("Payout Setup Required")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("To protect buyers and ensure secure transactions, you must set up payouts before posting listings.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 16) {
                Text("How to get started:")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        Text("1.")
                            .fontWeight(.bold)
                            .foregroundColor(Color("ThemeColor"))
                        Text("Go to the Wallet tab")
                    }
                    
                    HStack(alignment: .top, spacing: 12) {
                        Text("2.")
                            .fontWeight(.bold)
                            .foregroundColor(Color("ThemeColor"))
                        Text("Complete Stripe Connect onboarding")
                    }
                    
                    HStack(alignment: .top, spacing: 12) {
                        Text("3.")
                            .fontWeight(.bold)
                            .foregroundColor(Color("ThemeColor"))
                        Text("Return here to start posting!")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
            
            Text("Tap the Wallet tab at the bottom to get started")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(Color("ThemeColor"))
                .multilineTextAlignment(.center)
                .padding()
                .background(Color("ThemeColor").opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal, 32)
            
            Button("Refresh Status") {
                Task { 
                    print("🔄 User clicked Refresh Status button")
                    await checkStripeConnectStatus()
                }
            }
            .foregroundColor(Color("ThemeColor"))
            .padding(.top, 8)
            
            // Stripe Payment Processing Note
            stripeNote
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var postingFormView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Title
                Text("Create Listing")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                // Intent Picker (Phase 0 - hidden by default)
                if AppConfig.enableSeekMode {
                    VStack(spacing: 8) {
                        Picker("Intent", selection: $selectedIntent) {
                            ForEach(ListingIntent.allCases, id: \.self) { intent in
                                Text(intent.displayName).tag(intent)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        
                        // Descriptive text below tabs
                        Text(selectedIntent == .offer ? "I want to sell something" : "I want to buy something")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(.horizontal)
                }
                
                    // Form Fields
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Title")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            TextField(titlePlaceholder, text: $title)
                                .focused($isTextFieldFocused)
                                .padding()
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(12)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            TextField(descriptionPlaceholder, text: $description, axis: .vertical)
                                .focused($isTextFieldFocused)
                                .lineLimit(4...8)
                                .padding()
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(12)
                        }
                        
                        // Photo Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 4) {
                                Text("Photos")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                + Text(" *")
                                    .font(.headline)
                                    .foregroundColor(.red)
                                Text("(Required)")
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                            }
                            
                            if !listingImages.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(Array(listingImages.enumerated()), id: \.offset) { index, image in
                                            ZStack(alignment: .topTrailing) {
                                                Image(uiImage: image)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 120, height: 120)
                                                    .clipped()
                                                    .cornerRadius(12)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .stroke(Color("ThemeColor"), lineWidth: 2)
                                                    )
                                                
                                                Button(action: {
                                                    listingImages.remove(at: index)
                                                }) {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .foregroundColor(.facebookBlue)
                                                        .background(Color.white)
                                                        .clipShape(Circle())
                                                }
                                                .offset(x: 8, y: -8)
                                            }
                                        }
                                        
                                        // Add more photos button
                                        if listingImages.count < 10 {
                                            ZStack {
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
                                                
                                                MultiImagePickerButton(
                                                    selectedImages: $listingImages,
                                                    maxSelectionCount: 10,
                                                    label: "",
                                                    icon: "",
                                                    style: .text
                                                )
                                                .opacity(0.01)
                                            }
                                        }
                                    }
                                }
                            }
                            
                            MultiImagePickerButton(
                                selectedImages: $listingImages,
                                maxSelectionCount: 10,
                                label: listingImages.isEmpty ? "Add Photo" : "Add More Photos",
                                icon: "photo",
                                style: .filled
                            )
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
                                    .focused($isTextFieldFocused)
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
                                    .focused($isTextFieldFocused)
                                    .lineLimit(2...4)
                                    .padding()
                                    .background(Color(UIColor.systemGray6))
                                    .cornerRadius(12)
                            }
                            
                            // Service Verification Info for sellers creating services
                            ServiceVerificationInfoView(isForSeller: true)
                                .padding(.top, 4)
                        }
                        
                        // Price for Offer or Budget for Seek
                        if !AppConfig.enableSeekMode || selectedIntent == .offer {
                            // Original price field for selling
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
                                            .focused($isTextFieldFocused)
                                        .keyboardType(.decimalPad)
                                }
                                .padding()
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(12)
                                
                                // Helper text for seller net pricing
                                Text("Amount you'll receive")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Category")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                + Text(" *")
                                    .font(.headline)
                                    .foregroundColor(.red)
                                Picker("Category", selection: $selectedCategory) {
                                    ForEach(currentCategories, id: \.self) { category in
                                        Text(category).tag(category)
                                    }
                                }
                                .onChange(of: selectedCategory) { newValue in
                                    showingCustomCategoryField = (newValue == "Other")
                                    if newValue != "Other" {
                                        customCategory = ""
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .padding()
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(12)
                                
                                // Custom category text field (appears when "Other" is selected)
                                if showingCustomCategoryField {
                                    TextField("Enter custom category", text: $customCategory)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .padding(.top, 8)
                                }
                                }
                            }
                            
                            // Accept Offers Toggle (only for sell mode)
                            if selectedIntent == .offer {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Accept Offers")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Text("Allow buyers to negotiate")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Toggle("", isOn: $acceptsOffers)
                                        .labelsHidden()
                                }
                                .padding()
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(12)
                            }
                            
                            // Show ticket guarantee info when Tickets category is selected
                            if selectedCategory == "Tickets" {
                                TicketGuaranteeInfoView(isOwnListing: true)
                                
                                // Event Date Picker for Tickets (REQUIRED)
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Event Date")
                                            .font(.headline)
                                            .foregroundColor(.secondary)
                                        Text("*")
                                            .foregroundColor(.red)
                                            .font(.headline)
                                    }
                                    
                                    DatePicker(
                                        "Event Date",
                                        selection: $eventDate,
                                        in: Date()...,
                                        displayedComponents: [.date, .hourAndMinute]
                                    )
                                    .datePickerStyle(.compact)
                                    .padding()
                                    .background(Color(UIColor.systemGray6))
                                    .cornerRadius(12)
                                    .labelsHidden()
                                    
                                    HStack(spacing: 4) {
                                        Image(systemName: "info.circle.fill")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                        Text("Ticket will automatically expire after the event")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.top, 4)
                                }
                                .padding(.top, 8)
                            }
                            
                            // Show product verification info for products
                            if selectedListingType == .product {
                                ProductVerificationInfoView(isForSeller: true)
                            }
                            
                            // Delivery Method Picker (for products only)
                            if selectedListingType == .product {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Delivery Method")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    Picker("Delivery Method", selection: $selectedDeliveryMethod) {
                                        ForEach(DeliveryMethod.allCases, id: \.self) { method in
                                            Text(method.displayName).tag(method)
                                        }
                                    }
                                    .pickerStyle(SegmentedPickerStyle())
                                    
                                    // Description text
                                    Text(selectedDeliveryMethod.description)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                }
                            }
                            
                            // Quantity selector (for products only)
                            if selectedListingType == .product {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Quantity Available")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    
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
                                    .cornerRadius(12)
                                    
                                    Text("How many units are you selling?")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        } else {
                            // Budget fields for seeking
                            VStack(spacing: 16) {
                                HStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Min Budget (Optional)")
                                            .font(.headline)
                                            .foregroundColor(.secondary)
                                        HStack {
                                            Text("$")
                                                .font(.title2)
                                                .foregroundColor(.secondary)
                                            TextField("0.00", text: $budgetMin)
                                                .focused($isTextFieldFocused)
                                                .keyboardType(.decimalPad)
                                        }
                                        .padding()
                                        .background(Color(UIColor.systemGray6))
                                        .cornerRadius(12)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Max Budget")
                                            .font(.headline)
                                            .foregroundColor(.secondary)
                                        HStack {
                                            Text("$")
                                                .font(.title2)
                                                .foregroundColor(.secondary)
                                            TextField("0.00", text: $budgetMax)
                                                .focused($isTextFieldFocused)
                                                .keyboardType(.decimalPad)
                                        }
                                        .padding()
                                        .background(Color(UIColor.systemGray6))
                                        .cornerRadius(12)
                                    }
                                }
                                
                                // Budget validation warning
                                if !budgetMin.isEmpty && !budgetMax.isEmpty,
                                   let min = Double(budgetMin), let max = Double(budgetMax),
                                   min > max {
                                    HStack(spacing: 8) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                        Text("Minimum budget cannot be greater than maximum budget")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(8)
                                }
                                
                                // Fee notice for seek posts
                                HStack(spacing: 8) {
                                    Image(systemName: "info.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Stripe processing fees apply when accepting offers")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("You'll see the exact fee breakdown before payment")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color.blue.opacity(0.05))
                                .cornerRadius(8)
                                
                                HStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Category")
                                            .font(.headline)
                                            .foregroundColor(.secondary)
                                        + Text(" *")
                                            .font(.headline)
                                            .foregroundColor(.red)
                                        Picker("Category", selection: $selectedCategory) {
                                            ForEach(currentCategories, id: \.self) { category in
                                                Text(category).tag(category)
                                            }
                                        }
                                        .onChange(of: selectedCategory) { newValue in
                                            showingCustomCategoryField = (newValue == "Other")
                                            if newValue != "Other" {
                                                customCategory = ""
                                            }
                                        }
                                        .pickerStyle(MenuPickerStyle())
                                        .padding()
                                        .background(Color(UIColor.systemGray6))
                                        .cornerRadius(12)
                                        
                                        // Custom category text field (appears when "Other" is selected)
                                        if showingCustomCategoryField {
                                            TextField("Enter custom category", text: $customCategory)
                                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                                .padding(.top, 8)
                                        }
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Expires")
                                            .font(.headline)
                                            .foregroundColor(.secondary)
                                        DatePicker("", selection: $expiresDate, in: Date()..., displayedComponents: .date)
                                            .labelsHidden()
                                            .padding()
                                            .background(Color(UIColor.systemGray6))
                                            .cornerRadius(12)
                                    }
                                }
                                
                                // Show ticket guarantee info when Tickets category is selected
                                if selectedCategory == "Tickets" {
                                    TicketGuaranteeInfoView(isOwnListing: false)
                                }
                                
                                // Show product verification info for products
                                if selectedListingType == .product {
                                    ProductVerificationInfoView(isForSeller: false)
                                }
                                
                                // Delivery Method Picker for Seek mode (for products only)
                                if selectedListingType == .product {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Delivery Method")
                                            .font(.headline)
                                            .foregroundColor(.secondary)
                                        Picker("Delivery Method", selection: $selectedDeliveryMethod) {
                                            ForEach(DeliveryMethod.allCases, id: \.self) { method in
                                                Text(method.displayName).tag(method)
                                            }
                                        }
                                        .pickerStyle(SegmentedPickerStyle())
                                        
                                        // Description text
                                        Text(selectedDeliveryMethod.description)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                    }
                                }
                            }
                        }
                        
                        // Post Button
                        Button(action: {
                            // Dismiss keyboard first
                            isTextFieldFocused = false
                            
                            // Seek mode is now fully implemented and ready
                            
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
                                Text(isLoading ? "Posting..." : getButtonText())
                            }
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color("ThemeColor"))
                            .cornerRadius(25)
                        }
                        .disabled(isDisabled)
                        .opacity(isDisabled ? 0.6 : 1.0)
                    }
                    .padding(.horizontal)
                }
                .padding()
        }
        .hideKeyboardOnTap()
        .onTapGesture {
            // Dismiss keyboard when tapping outside text fields
            isTextFieldFocused = false
        }
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text(alertMessage.contains("successfully") ? "Success" : "Error"), 
                message: Text(alertMessage), 
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareListingSheet(
                listingId: sharedListingId,
                listingTitle: sharedListingTitle,
                listingDescription: sharedListingDescription,
                listingPrice: sharedListingPrice,
                listingImageURL: sharedListingImageURL,
                isPresented: $showingShareSheet
            )
        }
    }
    
    private func loadUserProfile() async {
        guard let userId = authManager.session?.user.id.uuidString else { 
            print("❌ No user ID found in session")
            return 
        }
        
        print("🔄 Loading user profile for ID: \(userId)")
        
        await MainActor.run {
            isLoadingProfile = true
        }
        
        do {
            let profile: User = try await supabase
                .from("users")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            
            print("✅ User profile loaded:")
            print("   - ID: \(profile.id)")
            print("   - Name: \(profile.name ?? "nil")")
            print("   - Stripe Connect ID: \(profile.stripeConnectId ?? "nil")")
            print("   - Stripe Payouts Enabled: \(profile.stripePayoutsEnabled ?? false)")
            print("   - Stripe Details Submitted: \(profile.stripeDetailsSubmitted ?? false)")
            
            await MainActor.run {
                self.userProfile = profile
                self.isLoadingProfile = false
            }
        } catch {
            print("❌ Failed to load user profile: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            await MainActor.run {
                self.isLoadingProfile = false
                // Set userProfile to a default state so we don't block the user completely
                self.userProfile = User(
                    id: userId,
                    name: nil,
                    bio: nil,
                    profilePic: nil,
                    email: nil,
                    campus: nil,
                    createdAt: Date(),
                    campusEmailVerified: false,
                    trustScore: nil,
                    stripeConnectId: nil,
                    stripePayoutsEnabled: false,
                    stripeDetailsSubmitted: false,
                    verificationStatus: nil,
                    studentIdImageUrl: nil,
                    verificationSubmittedAt: nil,
                    verificationReviewedAt: nil,
                    verificationNotes: nil
                )
            }
        }
    }
    
    private func checkStripeConnectStatus() async {
        print("🔄 Checking Stripe Connect status...")
        
        await MainActor.run {
            isLoadingProfile = true
            shouldShowPayoutSetup = false
        }
        
        // First, load the user profile to get stripe_connect_id
        guard let userId = authManager.session?.user.id.uuidString else {
            print("❌ No user ID found")
            await MainActor.run {
                isLoadingProfile = false
                shouldShowPayoutSetup = true
            }
            return
        }
        
        do {
            // Load user profile
            let profile: User = try await supabase
                .from("users")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            
            self.userProfile = profile
            
            print("✅ User profile loaded: stripe_connect_id = \(profile.stripeConnectId ?? "nil")")
            
            // Call connect_onboarding to check status
            struct OnboardingReq: Encodable { 
                let return_url: String = "https://stripe-redirect.netlify.app/stripe-return.html"
                let refresh_url: String = "https://stripe-redirect.netlify.app/stripe-refresh.html"
            }
            struct OnboardingRes: Decodable { 
                let onboarding_url: String?
                let account_id: String?
                let onboarding_complete: Bool?
                let payouts_enabled: Bool?
            }
            
            let response: OnboardingRes = try await supabase.functions.invoke(
                "connect_onboarding",
                options: FunctionInvokeOptions(
                    method: .post,
                    body: OnboardingReq()
                )
            )
            
            print("✅ Connect onboarding response:")
            print("   - onboarding_complete: \(response.onboarding_complete ?? false)")
            print("   - payouts_enabled: \(response.payouts_enabled ?? false)")
            print("   - account_id: \(response.account_id ?? "nil")")
            print("   - has onboarding_url: \(response.onboarding_url != nil)")
            
            // The Edge Function returns onboarding_complete: true when ready
            let isComplete = response.onboarding_complete == true
            
            if isComplete {
                print("✅ Stripe Connect is complete!")
                
                // Always update the database when Stripe says it's complete
                print("🔄 Updating user profile with Stripe status...")
                
                struct UserUpdate: Encodable {
                    let stripe_payouts_enabled: Bool = true
                    let stripe_details_submitted: Bool = true
                }
                
                try await supabase
                    .from("users")
                    .update(UserUpdate())
                    .eq("id", value: userId)
                    .execute()
                
                print("✅ User profile updated successfully")
                
                // Reload the profile to get the updated data
                let updatedProfile: User = try await supabase
                    .from("users")
                    .select()
                    .eq("id", value: userId)
                    .single()
                    .execute()
                    .value
                
                self.userProfile = updatedProfile
                print("✅ Reloaded profile: stripe_payouts_enabled = \(updatedProfile.stripePayoutsEnabled ?? false)")
            } else {
                print("⚠️ Stripe Connect is NOT complete")
            }
            
            await MainActor.run {
                self.stripeConnectComplete = isComplete
                self.shouldShowPayoutSetup = !isComplete
                self.isLoadingProfile = false
                
                if !isComplete {
                    print("⚠️ Showing payout setup screen because Stripe Connect is not complete")
                }
            }
            
        } catch {
            print("❌ Error checking Stripe status: \(error)")
            await MainActor.run {
                // Default to showing payout setup on error
                self.shouldShowPayoutSetup = true
                self.isLoadingProfile = false
                self.alertMessage = "Failed to verify payout status. Please try again."
                self.showingAlert = true
            }
        }
    }
    
    private func createListing() async {
        guard let userId = authManager.session?.user.id.uuidString else { return }
        
        // For offers, price is required. For seeks, price is nil and budget is used instead.
        var priceValue: Double? = nil
        if selectedIntent == .offer {
            guard let price = Double(price) else { return }
            priceValue = price
        }
        
        // Validate budget constraints for seek posts
        if selectedIntent == .seek {
            let minBudget = budgetMin.isEmpty ? nil : Double(budgetMin)
            let maxBudget = budgetMax.isEmpty ? nil : Double(budgetMax)
            
            // Check if both budgets are provided and min > max
            if let min = minBudget, let max = maxBudget, min > max {
                await MainActor.run {
                    alertMessage = "Minimum budget ($\(String(format: "%.0f", min))) cannot be greater than maximum budget ($\(String(format: "%.0f", max))). Please adjust your budget range."
                    showingAlert = true
                }
                return
            }
            
            // Check for negative or zero budgets
            if let min = minBudget, min < 0 {
                await MainActor.run {
                    alertMessage = "Minimum budget cannot be negative."
                    showingAlert = true
                }
                return
            }
            
            if let max = maxBudget, max <= 0 {
                await MainActor.run {
                    alertMessage = "Maximum budget must be greater than zero."
                    showingAlert = true
                }
                return
            }
        }
        
        await MainActor.run {
            isLoading = true
        }
        
        var photoURL: String? = nil
        var photoURLs: [String] = []
        
        // Upload multiple photos if selected
        if !listingImages.isEmpty {
            for (index, image) in listingImages.enumerated() {
                guard let imageData = image.resizedForUpload() else { continue }
                
                do {
                    let fileName = "\(UUID())_listing_\(index).jpg"
                    try await supabase.storage
                        .from("listings")
                        .upload(fileName, data: imageData)
                    
                    let url = try supabase.storage
                        .from("listings")
                        .getPublicURL(path: fileName)
                        .absoluteString
                    
                    photoURLs.append(url)
                    
                    // Set the first photo as the main photo for backward compatibility
                    if index == 0 {
                        photoURL = url
                    }
                    
                } catch {
                    await MainActor.run {
                        alertMessage = "Failed to upload image \(index + 1): \(error.localizedDescription)"
                        showingAlert = true
                        isLoading = false
                    }
                    return
                }
            }
        }
        // No photos case - photoURL and photoURLs remain nil/empty
        
        // Create listing in database
        do {
            // Determine expiration date based on listing type
            var expirationDate: Date? = nil
            if selectedIntent == .seek {
                expirationDate = expiresDate
            } else if selectedCategory == "Tickets" {
                // Tickets expire at the event date
                expirationDate = eventDate
            }
            
            let newListing = ListingCreate(
                userId: userId,
                title: title,
                description: description,
                price: priceValue,
                category: selectedCategory == "Other" && !customCategory.isEmpty ? customCategory : selectedCategory,
                photo: photoURL,
                photos: photoURLs,
                listingType: selectedListingType,
                serviceDuration: selectedListingType == .service ? (serviceDuration.isEmpty ? nil : serviceDuration) : nil,
                serviceLocation: selectedListingType == .service ? selectedServiceLocation : nil,
                serviceAvailability: selectedListingType == .service ? (serviceAvailability.isEmpty ? nil : serviceAvailability) : nil,
                archived: false,
                // Seek mode fields (Phase 2)
                intent: selectedIntent,
                budgetMin: selectedIntent == .seek ? (budgetMin.isEmpty ? nil : Double(budgetMin)) : nil,
                budgetMax: selectedIntent == .seek ? (budgetMax.isEmpty ? nil : Double(budgetMax)) : nil,
                expiresAt: expirationDate,
                deliveryMethod: selectedListingType == .product ? selectedDeliveryMethod : nil,
                quantityAvailable: selectedListingType == .product ? quantity : nil,
                acceptsOffers: selectedIntent == .offer ? acceptsOffers : nil
            )
            
            // Insert and retrieve the created listing to get its ID
            let createdListing: Listing = try await supabase
                .from("listings")
                .insert(newListing)
                .select()
                .single()
                .execute()
                .value
            
            await MainActor.run {
                // Analytics: Track listing creation
                if selectedIntent == .seek {
                    print("📊 Analytics: Seek posted - Category: \(newListing.category), Budget: \(newListing.budgetMin ?? 0)-\(newListing.budgetMax ?? 0)")
                } else {
                    print("📊 Analytics: Listing posted - Category: \(newListing.category), Type: \(newListing.listingType), Price: \(newListing.price)")
                }
                
                // Prepare share sheet data
                sharedListingId = createdListing.id.uuidString
                sharedListingTitle = title
                sharedListingDescription = description
                sharedListingImageURL = photoURL // First photo from upload
                
                if selectedIntent == .seek {
                    if let min = newListing.budgetMin, let max = newListing.budgetMax {
                        sharedListingPrice = "Budget: $\(String(format: "%.0f", min)) - $\(String(format: "%.0f", max))"
                    }
                } else {
                    sharedListingPrice = "$\(String(format: "%.2f", newListing.price ?? 0.0))"
                }
                
                isLoading = false
                // Auto-clear form after successful posting
                clearForm()
                
                // Show share sheet instead of alert
                showingShareSheet = true
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
        customCategory = ""
        showingCustomCategoryField = false
        selectedListingType = .product
        serviceDuration = ""
        selectedServiceLocation = .onCampus
        serviceAvailability = ""
        listingImages = []
        // Seek fields (Phase 0)
        selectedIntent = .offer
        budgetMin = ""
        budgetMax = ""
        expiresDate = Date().addingTimeInterval(7 * 24 * 60 * 60)
        // Reset ticket event date
        eventDate = Date().addingTimeInterval(24 * 60 * 60)
        // Delivery method
        selectedDeliveryMethod = .pickup
        // Reset quantity
        quantity = 1
    }
    
    // MARK: - Stripe Note
    private var stripeNote: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "shield.checkered")
                    .foregroundColor(Color("ThemeColor"))
                    .font(.caption)
                
                Text("We use Stripe for payment processing")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            Text("The #1 payment processor for mobile apps")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
        .padding(.top, 16)
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
        VStack {
            // Title
            Text("My Listings")
                .font(.largeTitle)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top)
            
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
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding()
                    }
                }
        }
        .onAppear {
            Task {
                await loadMyListings()
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
                .eq("status", value: "active")
                .order("created_at", ascending: false)
                .execute()
                .value
            
            await MainActor.run {
                self.myListings = response
                self.isLoading = false
            }
            
        } catch {
            #if DEBUG
            print("Failed to load my listings: \(error)")
            #endif
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
            #if DEBUG
            print("Failed to delete listing: \(error)")
            #endif
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
                        photos: listing.photos,
                        isSold: !listing.isSold,
                        listingType: listing.listingType,
                        serviceDuration: listing.serviceDuration,
                        serviceLocation: listing.serviceLocation,
                        serviceAvailability: listing.serviceAvailability,
                        archived: listing.archived,
                        createdAt: listing.createdAt,
                        // Seek mode fields
                        intent: listing.intent,
                        budgetMin: listing.budgetMin,
                        budgetMax: listing.budgetMax,
                        expiresAt: listing.expiresAt,
                        deliveryMethod: listing.deliveryMethod,
                        quantityAvailable: listing.quantityAvailable,
                        quantitySold: listing.quantitySold,
                        acceptsOffers: listing.acceptsOffers
                    )
                }
            }
        } catch {
            #if DEBUG
            print("Failed to update listing: \(error)")
            #endif
        }
    }
}

struct MyListingCard: View {
    let listing: Listing
    let onDelete: () -> Void
    let onToggleSold: () -> Void
    @State private var currentImageIndex: Int = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Single centered square with paging between photos
            let urls: [String] = !listing.photos.isEmpty ? listing.photos : (listing.photo != nil ? [listing.photo!] : [])
            ZStack {
                if urls.isEmpty {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.systemGray6))
                        .aspectRatio(1, contentMode: .fit)
                } else {
                    TabView(selection: $currentImageIndex) {
                        ForEach(Array(urls.enumerated()), id: \.offset) { index, photoURL in
                            if let url = URL(string: photoURL) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    Rectangle()
                                        .fill(Color(UIColor.systemGray5))
                                        .overlay(ProgressView())
                                }
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                                .clipped()
                                .tag(index)
                            }
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: urls.count > 1 ? .automatic : .never))
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .cornerRadius(12)
                }

                // Sold overlay
                if listing.isSold {
                    Rectangle()
                        .fill(Color.black.opacity(0.6))
                        .cornerRadius(12)
                        .overlay(
                            Text("SOLD")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                        .allowsHitTesting(false)
                        .aspectRatio(1, contentMode: .fit)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(listing.title)
                            .font(.headline)
                            .lineLimit(2)
                        VStack(alignment: .leading, spacing: 2) {
                            // Seller viewing their own listing - show only their net price
                            Text("$\((listing.price ?? 0), specifier: "%.2f")")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
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
                            .background(Color.facebookBlue)
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
        .frame(maxWidth: .infinity, alignment: .leading)
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
