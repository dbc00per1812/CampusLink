import Foundation
import Supabase

// MARK: - Time Slot Service
final class TimeSlotService: ObservableObject {
    static let shared = TimeSlotService()
    private init() {}
    
    // MARK: - Fetch Time Slots
    func getTimeSlotsForListing(_ listingId: UUID) async throws -> [TimeSlot] {
        let slots: [TimeSlot] = try await supabase
            .from("time_slots")
            .select()
            .eq("listing_id", value: listingId.uuidString)
            .gte("start_time", value: ISO8601DateFormatter().string(from: Date())) // Only future slots
            .order("start_time", ascending: true)
            .execute()
            .value
        
        return slots
    }
    
    // MARK: - Reserve Time Slot
    func reserveTimeSlot(_ timeSlotId: UUID, userId: UUID) async throws -> TimeSlotBooking {
        // Check if slot is still available
        let slot: TimeSlot = try await supabase
            .from("time_slots")
            .select()
            .eq("id", value: timeSlotId.uuidString)
            .single()
            .execute()
            .value
        
        guard slot.isAvailable else {
            throw TimeSlotError.slotNotAvailable
        }
        
        // Check if user already has a reservation for this slot
        let existingBookings: [TimeSlotBooking] = try await supabase
            .from("time_slot_bookings")
            .select()
            .eq("time_slot_id", value: timeSlotId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .in("status", values: ["reserved", "confirmed"])
            .execute()
            .value
        
        if !existingBookings.isEmpty {
            throw TimeSlotError.alreadyBooked
        }
        
        // Create reservation
        let bookingCreate = SlotBookingCreate(
            timeSlotId: timeSlotId,
            userId: userId
        )
        
        let booking: TimeSlotBooking = try await supabase
            .from("time_slot_bookings")
            .insert(bookingCreate)
            .select()
            .single()
            .execute()
            .value
        
        // Update slot current bookings count
        try await updateSlotBookingCount(timeSlotId)
        
        return booking
    }
    
    // MARK: - Confirm Booking (after payment)
    func confirmBooking(_ bookingId: UUID, orderId: UUID) async throws -> TimeSlotBooking {
        let booking: TimeSlotBooking = try await supabase
            .from("time_slot_bookings")
            .update([
                "status": "confirmed",
                "order_id": orderId.uuidString,
                "confirmed_at": ISO8601DateFormatter().string(from: Date())
            ])
            .eq("id", value: bookingId.uuidString)
            .select()
            .single()
            .execute()
            .value
        
        return booking
    }
    
    // MARK: - Cancel Reservation
    func cancelReservation(_ bookingId: UUID) async throws {
        let booking: TimeSlotBooking = try await supabase
            .from("time_slot_bookings")
            .update([
                "status": "cancelled",
                "cancelled_at": ISO8601DateFormatter().string(from: Date())
            ])
            .eq("id", value: bookingId.uuidString)
            .select()
            .single()
            .execute()
            .value
        
        // Update slot current bookings count
        try await updateSlotBookingCount(booking.timeSlotId)
    }
    
    // MARK: - Clean up expired reservations
    func cleanupExpiredReservations() async throws {
        let expirationTime = Calendar.current.date(byAdding: .minute, value: -10, to: Date()) ?? Date()
        
        try await supabase
            .from("time_slot_bookings")
            .update(["status": "cancelled"])
            .eq("status", value: "reserved")
            .lt("reserved_at", value: ISO8601DateFormatter().string(from: expirationTime))
            .execute()
    }
    
    // MARK: - Helper Methods
    private func updateSlotBookingCount(_ timeSlotId: UUID) async throws {
        // Count confirmed bookings for this slot
        let confirmedBookings: [TimeSlotBooking] = try await supabase
            .from("time_slot_bookings")
            .select()
            .eq("time_slot_id", value: timeSlotId.uuidString)
            .eq("status", value: "confirmed")
            .execute()
            .value
        
        // Update the slot's current booking count
        try await supabase
            .from("time_slots")
            .update(["current_bookings": confirmedBookings.count])
            .eq("id", value: timeSlotId.uuidString)
            .execute()
        
        // Update slot status if full
        let slot: TimeSlot = try await supabase
            .from("time_slots")
            .select()
            .eq("id", value: timeSlotId.uuidString)
            .single()
            .execute()
            .value
        
        if slot.currentBookings >= slot.maxBookings {
            try await supabase
                .from("time_slots")
                .update(["status": "full"])
                .eq("id", value: timeSlotId.uuidString)
                .execute()
        }
    }
    
    // MARK: - Get User's Bookings
    func getUserBookings(userId: UUID) async throws -> [TimeSlotBooking] {
        let bookings: [TimeSlotBooking] = try await supabase
            .from("time_slot_bookings")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("reserved_at", ascending: false)
            .execute()
            .value
        
        return bookings
    }
}

// MARK: - Time Slot Errors
enum TimeSlotError: LocalizedError {
    case slotNotAvailable
    case alreadyBooked
    case reservationExpired
    case invalidSlot
    
    var errorDescription: String? {
        switch self {
        case .slotNotAvailable:
            return "This time slot is no longer available."
        case .alreadyBooked:
            return "You already have a booking for this time slot."
        case .reservationExpired:
            return "Your reservation has expired. Please try again."
        case .invalidSlot:
            return "Invalid time slot selected."
        }
    }
}
