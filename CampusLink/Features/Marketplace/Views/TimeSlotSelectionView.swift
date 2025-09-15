import SwiftUI

struct TimeSlotSelectionView: View {
    let listing: ListingWithUser
    let timeSlots: [TimeSlot]
    let onSlotSelected: (TimeSlot) -> Void
    let onCancel: () -> Void
    
    @State private var selectedSlot: TimeSlot?
    @State private var isLoading = false
    @State private var showingConfirmation = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerSection
                
                // Time Slots List
                if timeSlots.isEmpty {
                    emptyStateView
                } else {
                    slotsListView
                }
                
                // Bottom Action
                bottomActionView
            }
            .navigationTitle("Select Time Slot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                AsyncImage(url: listing.photo.flatMap(URL.init)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color(.systemGray5))
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(listing.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("$\((listing.price ?? 0), specifier: "%.2f")")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color("ThemeColor"))
                    
                    if let duration = listing.serviceDuration {
                        Text(duration)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            Text("Select a time slot for your booking:")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Available Time Slots")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("There are currently no available time slots for this service. Please check back later or contact the seller directly.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Slots List
    private var slotsListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(timeSlots) { slot in
                    TimeSlotCard(
                        slot: slot,
                        isSelected: selectedSlot?.id == slot.id,
                        onTap: {
                            if slot.isAvailable {
                                selectedSlot = slot
                            }
                        }
                    )
                }
            }
            .padding()
        }
    }
    
    // MARK: - Bottom Action
    private var bottomActionView: some View {
        VStack(spacing: 12) {
            if let selectedSlot = selectedSlot {
                VStack(spacing: 8) {
                    HStack {
                        Text("Selected:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(selectedSlot.dayAndTimeString)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Spots remaining:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(selectedSlot.spotsRemaining)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(selectedSlot.spotsRemaining <= 2 ? .orange : .primary)
                    }
                }
                .padding(.horizontal)
            }
            
            Button(action: {
                guard let slot = selectedSlot else { return }
                showingConfirmation = true
            }) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .foregroundColor(.white)
                    }
                    Text(isLoading ? "Reserving..." : "Reserve & Continue")
                }
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(selectedSlot != nil ? Color("ThemeColor") : Color(.systemGray4))
                .cornerRadius(12)
            }
            .disabled(selectedSlot == nil || isLoading)
            .padding(.horizontal)
        }
        .padding(.bottom)
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: -2)
        .alert("Confirm Reservation", isPresented: $showingConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reserve") {
                guard let slot = selectedSlot else { return }
                reserveSlot(slot)
            }
        } message: {
            if let slot = selectedSlot {
                Text("Reserve your spot for \(slot.dayAndTimeString)? You'll have 10 minutes to complete your payment.")
            }
        }
    }
    
    // MARK: - Actions
    private func reserveSlot(_ slot: TimeSlot) {
        isLoading = true
        
        // Add a small delay to show loading state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isLoading = false
            onSlotSelected(slot)
        }
    }
}

// MARK: - Time Slot Card
struct TimeSlotCard: View {
    let slot: TimeSlot
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Date & Time
                VStack(alignment: .leading, spacing: 4) {
                    Text(slot.dateString)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(slot.timeRange)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Availability Info
                VStack(alignment: .trailing, spacing: 4) {
                    availabilityBadge
                    
                    if slot.isAvailable {
                        Text("\(slot.spotsRemaining)/\(slot.maxBookings) spots")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Selection Indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(Color("ThemeColor"))
                } else if slot.isAvailable {
                    Image(systemName: "circle")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: isSelected ? 2 : 1)
            )
            .cornerRadius(12)
        }
        .disabled(!slot.isAvailable)
        .buttonStyle(PlainButtonStyle())
    }
    
    private var availabilityBadge: some View {
        Text(slot.isFull ? "FULL" : slot.status.displayName.uppercased())
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(slot.status.badgeColor.opacity(0.15))
            .foregroundColor(slot.status.badgeColor)
            .cornerRadius(6)
    }
    
    private var backgroundColor: Color {
        if !slot.isAvailable {
            return Color(.systemGray6)
        } else if isSelected {
            return Color("ThemeColor").opacity(0.1)
        } else {
            return Color(.systemBackground)
        }
    }
    
    private var borderColor: Color {
        if isSelected {
            return Color("ThemeColor")
        } else if !slot.isAvailable {
            return Color(.systemGray4)
        } else {
            return Color(.systemGray5)
        }
    }
}

// MARK: - Previews
struct TimeSlotSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        TimeSlotSelectionView(
            listing: ListingWithUser.sampleListing,
            timeSlots: TimeSlot.sampleSlots,
            onSlotSelected: { _ in },
            onCancel: { }
        )
    }
}

struct TimeSlotCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            TimeSlotCard(
                slot: TimeSlot.sampleSlots[0],
                isSelected: false,
                onTap: { }
            )
            
            TimeSlotCard(
                slot: TimeSlot.sampleSlots[1],
                isSelected: true,
                onTap: { }
            )
        }
        .padding()
    }
}
