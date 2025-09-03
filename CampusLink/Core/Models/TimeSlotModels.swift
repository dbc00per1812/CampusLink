import Foundation
import SwiftUI

// MARK: - Time Slot Models
struct TimeSlot: Codable, Identifiable {
    let id: UUID
    let listingId: UUID
    let startTime: Date
    let endTime: Date
    let maxBookings: Int
    let currentBookings: Int
    let price: Double? // Optional: override listing price for specific slots
    let status: SlotStatus
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, price, status
        case listingId = "listing_id"
        case startTime = "start_time"
        case endTime = "end_time"
        case maxBookings = "max_bookings"
        case currentBookings = "current_bookings"
        case createdAt = "created_at"
    }
    
    // Computed properties
    var isAvailable: Bool {
        status == .available && currentBookings < maxBookings && startTime > Date()
    }
    
    var isFull: Bool {
        currentBookings >= maxBookings
    }
    
    var spotsRemaining: Int {
        max(0, maxBookings - currentBookings)
    }
    
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
    
    // Formatted display strings
    var timeRange: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"
    }
    
    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: startTime)
    }
    
    var dayAndTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E, MMM d - h:mm a"
        let endFormatter = DateFormatter()
        endFormatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: startTime)) - \(endFormatter.string(from: endTime))"
    }
}

enum SlotStatus: String, Codable, CaseIterable {
    case available = "available"
    case full = "full"
    case cancelled = "cancelled"
    case completed = "completed"
    
    var displayName: String {
        switch self {
        case .available:
            return "Available"
        case .full:
            return "Full"
        case .cancelled:
            return "Cancelled"
        case .completed:
            return "Completed"
        }
    }
    
    var badgeColor: Color {
        switch self {
        case .available:
            return .green
        case .full:
            return .orange
        case .cancelled:
            return .red
        case .completed:
            return .blue
        }
    }
}

// MARK: - Time Slot Booking
struct TimeSlotBooking: Codable, Identifiable {
    let id: UUID
    let timeSlotId: UUID
    let orderId: UUID?
    let userId: UUID
    let status: BookingStatus
    let reservedAt: Date
    let confirmedAt: Date?
    let cancelledAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, status
        case timeSlotId = "time_slot_id"
        case orderId = "order_id"
        case userId = "user_id"
        case reservedAt = "reserved_at"
        case confirmedAt = "confirmed_at"
        case cancelledAt = "cancelled_at"
    }
}

enum BookingStatus: String, Codable, CaseIterable {
    case reserved = "reserved"    // Temporarily held (5-10 mins)
    case confirmed = "confirmed"  // Payment completed
    case cancelled = "cancelled"  // Booking cancelled
    case completed = "completed"  // Service completed
    
    var displayName: String {
        switch self {
        case .reserved:
            return "Reserved"
        case .confirmed:
            return "Confirmed"
        case .cancelled:
            return "Cancelled"
        case .completed:
            return "Completed"
        }
    }
}

// MARK: - API Models
struct TimeSlotCreate: Codable {
    let listingId: UUID
    let startTime: Date
    let endTime: Date
    let maxBookings: Int
    let price: Double?
    
    enum CodingKeys: String, CodingKey {
        case price
        case listingId = "listing_id"
        case startTime = "start_time"
        case endTime = "end_time"
        case maxBookings = "max_bookings"
    }
}

struct SlotBookingCreate: Codable {
    let timeSlotId: UUID
    let userId: UUID
    
    enum CodingKeys: String, CodingKey {
        case timeSlotId = "time_slot_id"
        case userId = "user_id"
    }
}

// MARK: - Sample Data
extension TimeSlot {
    static let sampleSlots = [
        TimeSlot(
            id: UUID(),
            listingId: UUID(),
            startTime: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date(),
            endTime: Calendar.current.date(byAdding: .hour, value: 2, to: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()) ?? Date(),
            maxBookings: 8,
            currentBookings: 3,
            price: nil,
            status: .available,
            createdAt: Date()
        ),
        TimeSlot(
            id: UUID(),
            listingId: UUID(),
            startTime: Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date(),
            endTime: Calendar.current.date(byAdding: .hour, value: 2, to: Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()) ?? Date(),
            maxBookings: 8,
            currentBookings: 8,
            price: nil,
            status: .full,
            createdAt: Date()
        )
    ]
}
