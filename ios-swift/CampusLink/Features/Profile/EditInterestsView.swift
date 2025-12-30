import SwiftUI
import Supabase

/// View for editing user interests from Settings
/// Allows existing users (who signed up before this feature) to set or update their interests
struct EditInterestsView: View {
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedInterests: Set<InterestOption> = []
    @State private var isSaving = false
    @State private var isLoading = true
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingSuccess = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if isLoading {
                    VStack {
                        Spacer()
                        ProgressView("Loading interests...")
                        Spacer()
                    }
                } else {
                    // Content
                    ScrollView {
                        VStack(spacing: 24) {
                            // Header info
                            VStack(spacing: 8) {
                                Image(systemName: "star.circle.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(Color("ThemeColor"))
                                
                                Text("Your Interests")
                                    .font(.system(size: 24, weight: .bold))
                                
                                Text("Select categories you'd like to see prioritized in your For You feed.")
                                    .font(.system(size: 15))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)
                            }
                            .padding(.top, 16)
                            
                            // Products Section
                            categorySection(
                                title: "Products",
                                icon: "bag.fill",
                                options: InterestOptions.productCategories
                            )
                            
                            // Services Section
                            categorySection(
                                title: "Services",
                                icon: "wrench.and.screwdriver.fill",
                                options: InterestOptions.serviceCategories
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100) // Space for floating button
                    }
                    
                    // Floating save button
                    floatingButtons
                }
            }
            .navigationTitle("Manage Interests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                Task {
                    await loadExistingInterests()
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Success", isPresented: $showingSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your interests have been updated!")
            }
        }
    }
    
    // MARK: - Category Section
    
    @ViewBuilder
    private func categorySection(title: String, icon: String, options: [InterestOption]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color("ThemeColor"))
                
                Text(title)
                    .font(.system(size: 22, weight: .bold))
                
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(options) { option in
                    InterestEditCard(
                        option: option,
                        isSelected: selectedInterests.contains(option),
                        onTap: {
                            toggleInterest(option)
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Floating Buttons
    
    private var floatingButtons: some View {
        VStack(spacing: 12) {
            Text("\(selectedInterests.count) interest\(selectedInterests.count == 1 ? "" : "s") selected")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            Button(action: {
                Task {
                    await saveInterests()
                }
            }) {
                HStack(spacing: 8) {
                    if isSaving {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Text("Save Interests")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Color("ThemeColor")
                        .opacity(isSaving ? 0.7 : 1.0)
                )
                .cornerRadius(12)
            }
            .disabled(isSaving)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            Color(UIColor.systemBackground)
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: -5)
        )
    }
    
    // MARK: - Actions
    
    private func toggleInterest(_ option: InterestOption) {
        if selectedInterests.contains(option) {
            selectedInterests.remove(option)
        } else {
            selectedInterests.insert(option)
        }
    }
    
    private func loadExistingInterests() async {
        guard let userId = authManager.session?.user.id.uuidString else {
            await MainActor.run {
                isLoading = false
            }
            return
        }
        
        do {
            let interests = try await UserInterestService.shared.fetchUserInterests(userId: userId)
            
            // Convert database interests to InterestOptions
            var existingInterests = Set<InterestOption>()
            for interest in interests {
                // Find matching InterestOption
                if let matchingOption = InterestOptions.allCategories.first(where: { 
                    $0.category == interest.category && $0.type.rawValue == interest.listingType 
                }) {
                    existingInterests.insert(matchingOption)
                }
            }
            
            await MainActor.run {
                self.selectedInterests = existingInterests
                self.isLoading = false
            }
            
            print("✅ Loaded \(existingInterests.count) existing interests")
            
        } catch {
            print("❌ Error loading existing interests: \(error)")
            await MainActor.run {
                self.isLoading = false
                // Don't show error - just start with empty selection
            }
        }
    }
    
    private func saveInterests() async {
        await MainActor.run {
            isSaving = true
        }
        
        guard let userId = authManager.session?.user.id.uuidString else {
            await MainActor.run {
                errorMessage = "Unable to save interests. Please try again."
                showingError = true
                isSaving = false
            }
            return
        }
        
        do {
            // Delete existing interests
            try await supabase
                .from("user_interests")
                .delete()
                .eq("user_id", value: userId)
                .execute()
            
            print("✅ Deleted existing interests for user")
            
            // Insert new interests if any selected
            if !selectedInterests.isEmpty {
                let interests = selectedInterests.map { option in
                    [
                        "user_id": userId,
                        "category": option.category,
                        "listing_type": option.type.rawValue
                    ]
                }
                
                try await supabase
                    .from("user_interests")
                    .insert(interests)
                    .execute()
                
                print("✅ Saved \(interests.count) user interests")
            }
            
            // Clear the cache so new interests take effect
            UserInterestService.shared.clearCache(userId: userId)
            
            await MainActor.run {
                isSaving = false
                showingSuccess = true
            }
            
        } catch {
            print("❌ Error saving interests: \(error)")
            await MainActor.run {
                isSaving = false
                errorMessage = "Failed to save interests: \(error.localizedDescription)"
                showingError = true
            }
        }
    }
}

// MARK: - Interest Edit Card Component

struct InterestEditCard: View {
    let option: InterestOption
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            isSelected 
                                ? Color("ThemeColor").opacity(0.15)
                                : Color(UIColor.systemGray6)
                        )
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: option.icon)
                        .font(.system(size: 28))
                        .foregroundColor(
                            isSelected 
                                ? Color("ThemeColor")
                                : .secondary
                        )
                    
                    if isSelected {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(Color("ThemeColor"))
                                    .background(
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 16, height: 16)
                                    )
                                    .offset(x: 8, y: -8)
                            }
                            Spacer()
                        }
                        .frame(width: 60, height: 60)
                    }
                }
                
                Text(option.displayName)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        isSelected 
                            ? Color("ThemeColor").opacity(0.08)
                            : Color(UIColor.secondarySystemBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected 
                                    ? Color("ThemeColor")
                                    : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    EditInterestsView()
        .environmentObject(AuthManager())
}










