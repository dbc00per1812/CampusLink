import SwiftUI
import Supabase

struct InterestSelectionView: View {
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedInterests: Set<InterestOption> = []
    @State private var isSaving = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    // Completion handler called when user finishes (either saves or skips)
    let onComplete: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Content
                ScrollView {
                    VStack(spacing: 24) {
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
                    .padding(.top, 20)
                    .padding(.bottom, 100) // Space for floating button
                }
                
                // Floating action buttons
                floatingButtons
            }
            .navigationBarHidden(true)
            .onAppear {
                print("🎨 InterestSelectionView appeared!")
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()
                Button(action: {
                    // Skip - activate session first, then complete
                    Task {
                        await MainActor.run {
                            authManager.activatePendingSession()
                        }
                        // Small delay to ensure session is active
                        try? await Task.sleep(nanoseconds: 100_000_000)
                        await MainActor.run {
                            onComplete()
                        }
                    }
                }) {
                    Text("Skip")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color("ThemeColor"))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            VStack(spacing: 8) {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Color("ThemeColor"))
                
                Text("What are you interested in?")
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)
                
                Text("Select categories you'd like to see in your For You feed. You can always change this later.")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
            .padding(.bottom, 8)
        }
        .background(Color(UIColor.systemBackground))
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
                    InterestCard(
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
            if !selectedInterests.isEmpty {
                Text("\(selectedInterests.count) interest\(selectedInterests.count == 1 ? "" : "s") selected")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
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
                    Text(selectedInterests.isEmpty ? "Continue" : "Save & Continue")
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
    
    private func saveInterests() async {
        await MainActor.run {
            isSaving = true
        }
        
        // Activate session first so user is authenticated for RLS policies
        await MainActor.run {
            print("🔓 Activating pending session for interest save...")
            authManager.activatePendingSession()
        }
        
        // Longer delay to ensure session is fully propagated to Supabase
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
        
        guard let userId = authManager.session?.user.id.uuidString else {
            print("❌ No session found after activation!")
            await MainActor.run {
                errorMessage = "Unable to save interests. Please try again."
                showingError = true
                isSaving = false
            }
            return
        }
        
        print("✅ Session active, user ID: \(userId)")
        
        do {
            // If no interests selected, just complete without saving
            if selectedInterests.isEmpty {
                await MainActor.run {
                    isSaving = false
                    // Session already activated, just complete
                    onComplete()
                }
                return
            }
            
            // Convert selected interests to database format
            let interests = selectedInterests.map { option in
                [
                    "user_id": userId,
                    "category": option.category,
                    "listing_type": option.type.rawValue
                ]
            }
            
            // Save to database
            try await supabase
                .from("user_interests")
                .insert(interests)
                .execute()
            
            print("✅ Saved \(interests.count) user interests")
            
            await MainActor.run {
                isSaving = false
                // Session already activated, just complete
                onComplete()
            }
        } catch {
            print("❌ Error saving interests: \(error)")
            print("❌ Error type: \(type(of: error))")
            print("❌ Error description: \(error.localizedDescription)")
            
            // Print detailed Postgrest error if available
            if let postgrestError = error as? PostgrestError {
                print("❌ Postgrest error details: \(postgrestError)")
            }
            
            await MainActor.run {
                isSaving = false
                errorMessage = "Failed to save interests: \(error.localizedDescription)"
                showingError = true
            }
        }
    }
}

// MARK: - Interest Card Component

struct InterestCard: View {
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
    InterestSelectionView(onComplete: {
        print("Completed")
    })
    .environmentObject(AuthManager())
}

