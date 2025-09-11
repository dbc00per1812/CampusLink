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
    @State private var selectedCategory = "Electronics"
    @State private var customCategory = ""
    @State private var showingCustomCategoryField = false
    @State private var selectedListingType = ListingType.product
    @State private var serviceDuration = ""
    @State private var selectedServiceLocation = ServiceLocation.onCampus
    @State private var serviceAvailability = ""
    @State private var selectedServiceType = ServiceType.calendar
    @State private var slotsAvailable = ""
    @State private var maxBookingsPerSlot = ""
    @State private var selectedImage: PhotosPickerItem?
    @State private var listingImage: UIImage?
    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var navigateToHome = false
    @State private var userProfile: User? = nil
    @State private var isLoadingProfile = true
    @State private var shouldShowPayoutSetup = false
    @State private var stripeConnectComplete = false
    
    // Seek mode states (Phase 0)
    @State private var selectedIntent: ListingIntent = .offer
    @State private var budgetMin = ""
    @State private var budgetMax = ""
    @State private var expiresDate = Date().addingTimeInterval(7 * 24 * 60 * 60) // 7 days default
    
    // Add focus state for keyboard dismissal
    @FocusState private var isTextFieldFocused: Bool
    
    // Product categories
    let productCategories = ["Electronics", "Books", "Furniture", "Clothing", "Sports", "Tickets", "Other"]
    
    // Service categories
    let serviceCategories = ["Tutoring", "Moving", "Cleaning", "Other"]
    
    // Computed property for current categories based on listing type
    private var currentCategories: [String] {
        selectedListingType == .product ? productCategories : serviceCategories
    }
    
    // Computed property for button disabled state
    private var isDisabled: Bool {
        if isLoading || title.isEmpty || description.isEmpty {
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
            return "Post Buying"
        } else {
            return "Post Listing"
        }
    }
    
    var body: some View {
        NavigationView {
            if isLoadingProfile {
                VStack {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Checking account status...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if shouldShowPayoutSetup {
                payoutRequiredView
            } else {
                postingFormView
            }
        }
        .onAppear {
            Task { await checkStripeConnectStatus() }
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
                    Picker("Intent", selection: $selectedIntent) {
                        ForEach(ListingIntent.allCases, id: \.self) { intent in
                            Text(intent.displayName).tag(intent)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                }
                
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
                                .focused($isTextFieldFocused)
                                .padding()
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(12)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            TextField(selectedListingType == .product ? "Describe your item..." : "Describe your service...", text: $description, axis: .vertical)
                                .focused($isTextFieldFocused)
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
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Service Type")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                Picker("Service Type", selection: $selectedServiceType) {
                                    ForEach(ServiceType.allCases, id: \.self) { type in
                                        VStack(alignment: .leading) {
                                            Text(type.displayName)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            Text(type.description)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .tag(type)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .padding()
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(12)
                            }
                            
                            // Slot Configuration (only for slots service type)
                            if selectedServiceType == .slots {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Number of Time Slots Available")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    TextField("e.g., 5, 10, 20", text: $slotsAvailable)
                                        .focused($isTextFieldFocused)
                                        .keyboardType(.numberPad)
                                        .padding()
                                        .background(Color(UIColor.systemGray6))
                                        .cornerRadius(12)
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Maximum Bookings per Slot")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    TextField("e.g., 1, 2, 5 (leave empty for unlimited)", text: $maxBookingsPerSlot)
                                        .focused($isTextFieldFocused)
                                        .keyboardType(.numberPad)
                                        .padding()
                                        .background(Color(UIColor.systemGray6))
                                        .cornerRadius(12)
                                }
                            }
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
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Category")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
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
                                
                                HStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Category")
                                            .font(.headline)
                                            .foregroundColor(.secondary)
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
                            }
                        }
                        
                        // Post Button
                        Button(action: {
                            // Dismiss keyboard first
                            isTextFieldFocused = false
                            
                            // Phase 0: Block seek posts until DB is ready
                            if AppConfig.enableSeekMode && selectedIntent == .seek {
                                alertMessage = "Seek mode is coming soon! This feature is currently under development."
                                showingAlert = true
                                return
                            }
                            
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
        .onChange(of: selectedImage) { oldValue, newValue in
                Task {
                    if let newValue = newValue {
                        await loadImage(from: newValue)
                    }
                }
            }
            .alert(isPresented: $showingAlert) {
            Alert(
                title: Text(alertMessage.contains("successfully") ? "Success" : "Error"), 
                message: Text(alertMessage), 
                dismissButton: .default(Text("OK"))
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
                    createdAt: Date(),
                    campusEmailVerified: false,
                    trustScore: nil,
                    stripeConnectId: nil,
                    stripePayoutsEnabled: false,
                    stripeDetailsSubmitted: false
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
                let return_url: String = "campuslink://wallet/onboarding-complete"
                let refresh_url: String = "campuslink://wallet/onboarding-refresh"
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
                category: selectedCategory == "Other" && !customCategory.isEmpty ? customCategory : selectedCategory,
                photo: photoURL,
                listingType: selectedListingType,
                serviceDuration: selectedListingType == .service ? (serviceDuration.isEmpty ? nil : serviceDuration) : nil,
                serviceLocation: selectedListingType == .service ? selectedServiceLocation : nil,
                serviceAvailability: selectedListingType == .service ? (serviceAvailability.isEmpty ? nil : serviceAvailability) : nil,
                serviceType: selectedListingType == .service ? selectedServiceType : nil,
                slotsAvailable: selectedListingType == .service && selectedServiceType == .slots ? (slotsAvailable.isEmpty ? nil : Int(slotsAvailable)) : nil,
                maxBookingsPerSlot: selectedListingType == .service && selectedServiceType == .slots ? (maxBookingsPerSlot.isEmpty ? nil : Int(maxBookingsPerSlot)) : nil,
                archived: false,
                // Seek mode fields (Phase 2)
                intent: selectedIntent,
                budgetMin: selectedIntent == .seek ? (budgetMin.isEmpty ? nil : Double(budgetMin)) : nil,
                budgetMax: selectedIntent == .seek ? (budgetMax.isEmpty ? nil : Double(budgetMax)) : nil,
                expiresAt: selectedIntent == .seek ? expiresDate : nil
            )
            
            try await supabase
                .from("listings")
                .insert(newListing, returning: .minimal)
                .execute()
            
            await MainActor.run {
                alertMessage = "Listing posted successfully! 🎉"
                showingAlert = true
                isLoading = false
                // Auto-clear form after successful posting
                clearForm()
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
        selectedServiceType = .calendar
        slotsAvailable = ""
        maxBookingsPerSlot = ""
        listingImage = nil
        selectedImage = nil
        // Seek fields (Phase 0)
        selectedIntent = .offer
        budgetMin = ""
        budgetMax = ""
        expiresDate = Date().addingTimeInterval(7 * 24 * 60 * 60)
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
                        isSold: !listing.isSold,
                        listingType: listing.listingType,
                        serviceDuration: listing.serviceDuration,
                        serviceLocation: listing.serviceLocation,
                        serviceAvailability: listing.serviceAvailability,
                        serviceType: listing.serviceType,
                        slotsAvailable: listing.slotsAvailable,
                        maxBookingsPerSlot: listing.maxBookingsPerSlot,
                        archived: listing.archived,
                        createdAt: listing.createdAt,
                        // Seek mode fields
                        intent: listing.intent,
                        budgetMin: listing.budgetMin,
                        budgetMax: listing.budgetMax,
                        expiresAt: listing.expiresAt
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
                        VStack(alignment: .leading, spacing: 2) {
                            Text("$\(listing.price, specifier: "%.2f")")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(Color("ThemeColor"))
                            
                            Text("$\(listing.price * 1.029 + 0.30, specifier: "%.2f") total")
                                .font(.caption2)
                                .foregroundColor(.secondary)
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