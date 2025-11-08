import Foundation
import SwiftUI
import UserNotifications

/// Monitors active orders and sends periodic notifications for orders requiring user action
@MainActor
class ActiveOrderMonitor: ObservableObject {
    static let shared = ActiveOrderMonitor()
    
    @Published var ordersRequiringAction: Int = 0
    @Published var buyerPendingCount: Int = 0
    @Published var sellerPendingCount: Int = 0
    
    private var monitoringTimer: Timer?
    private var lastNotificationTime: [UUID: Date] = [:]
    
    // Notification interval: 5 minutes for in-app checks, 24 hours for push notifications
    private let checkInterval: TimeInterval = 300 // 5 minutes
    private let notificationInterval: TimeInterval = 86400 // 24 hours
    
    private init() {}
    
    // MARK: - Monitoring Control
    
    /// Start monitoring active orders
    func startMonitoring(userId: UUID) {
        stopMonitoring()
        
        // Immediate check
        Task {
            await checkActiveOrders(userId: userId)
        }
        
        // Schedule periodic checks
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkActiveOrders(userId: userId)
            }
        }
        
        print("📊 ActiveOrderMonitor: Started monitoring for user \(userId)")
    }
    
    /// Stop monitoring
    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        ordersRequiringAction = 0
        buyerPendingCount = 0
        sellerPendingCount = 0
        print("📊 ActiveOrderMonitor: Stopped monitoring")
    }
    
    // MARK: - Order Checking
    
    /// Check for active orders requiring user action
    func checkActiveOrders(userId: UUID) async {
        do {
            // Check orders where user is buyer and needs to confirm receipt
            let buyerOrders: [Order] = try await supabase
                .from("orders")
                .select("""
                    *,
                    listing:listings(*)
                """)
                .eq("buyer_id", value: userId.uuidString)
                .eq("order_status", value: "seller_confirmed")
                .eq("payment_status", value: "requires_capture")
                .neq("order_status", value: "cancelled")
                .neq("order_status", value: "completed")
                .execute()
                .value
            
            // Check orders where user is seller and needs to deliver
            let sellerOrders: [Order] = try await supabase
                .from("orders")
                .select("""
                    *,
                    listing:listings(*)
                """)
                .eq("seller_id", value: userId.uuidString)
                .`in`("order_status", values: ["placed", "in_progress"])
                .neq("order_status", value: "cancelled")
                .neq("order_status", value: "completed")
                .execute()
                .value
            
            await MainActor.run {
                self.buyerPendingCount = buyerOrders.count
                self.sellerPendingCount = sellerOrders.count
                self.ordersRequiringAction = buyerOrders.count + sellerOrders.count
            }
            
            print("📊 ActiveOrderMonitor: Found \(buyerOrders.count) buyer orders, \(sellerOrders.count) seller orders")
            
            // Send notifications for orders waiting too long
            await sendRemindersIfNeeded(buyerOrders: buyerOrders, sellerOrders: sellerOrders)
            
        } catch {
            print("❌ ActiveOrderMonitor: Error checking active orders: \(error)")
        }
    }
    
    // MARK: - Notifications
    
    /// Send reminder notifications for orders waiting too long
    private func sendRemindersIfNeeded(buyerOrders: [Order], sellerOrders: [Order]) async {
        let now = Date()
        
        // Notify buyers about pending confirmations (after 24 hours)
        for order in buyerOrders {
            guard let sellerConfirmedAt = order.sellerConfirmedAt else { continue }
            
            let timeSinceConfirmed = now.timeIntervalSince(sellerConfirmedAt)
            
            // If more than 24 hours and we haven't sent a notification recently
            if timeSinceConfirmed > notificationInterval {
                if let lastNotified = lastNotificationTime[order.id] {
                    // Don't spam - only notify once per day
                    if now.timeIntervalSince(lastNotified) < notificationInterval {
                        continue
                    }
                }
                
                // Send reminder notification
                await sendBuyerReminder(order: order)
                lastNotificationTime[order.id] = now
            }
        }
        
        // Notify sellers about pending deliveries (after 48 hours)
        for order in sellerOrders {
            let timeSinceOrder = now.timeIntervalSince(order.createdAt)
            
            // If more than 48 hours and we haven't sent a notification recently
            if timeSinceOrder > (notificationInterval * 2) {
                if let lastNotified = lastNotificationTime[order.id] {
                    // Don't spam - only notify once per day
                    if now.timeIntervalSince(lastNotified) < notificationInterval {
                        continue
                    }
                }
                
                // Send reminder notification
                await sendSellerReminder(order: order)
                lastNotificationTime[order.id] = now
            }
        }
    }
    
    /// Send reminder to buyer to confirm receipt
    private func sendBuyerReminder(order: Order) async {
        guard let listing = order.listing else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "⏰ Confirm Your Order"
        content.body = "Your order for \"\(listing.title)\" is waiting for confirmation. The seller has marked it as delivered."
        content.sound = .default
        content.badge = NSNumber(value: ordersRequiringAction)
        content.userInfo = [
            "type": "order_reminder",
            "order_id": order.id.uuidString,
            "action": "confirm_receipt"
        ]
        
        let request = UNNotificationRequest(
            identifier: "order_reminder_\(order.id.uuidString)",
            content: content,
            trigger: nil // Deliver immediately
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("📲 ActiveOrderMonitor: Sent buyer reminder for order \(order.id)")
        } catch {
            print("❌ ActiveOrderMonitor: Failed to send buyer reminder: \(error)")
        }
    }
    
    /// Send reminder to seller to deliver item
    private func sendSellerReminder(order: Order) async {
        guard let listing = order.listing else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "📦 Deliver Your Order"
        content.body = "Your buyer is waiting! Please deliver \"\(listing.title)\" and mark it as delivered."
        content.sound = .default
        content.badge = NSNumber(value: ordersRequiringAction)
        content.userInfo = [
            "type": "order_reminder",
            "order_id": order.id.uuidString,
            "action": "mark_delivered"
        ]
        
        let request = UNNotificationRequest(
            identifier: "order_reminder_\(order.id.uuidString)",
            content: content,
            trigger: nil // Deliver immediately
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("📲 ActiveOrderMonitor: Sent seller reminder for order \(order.id)")
        } catch {
            print("❌ ActiveOrderMonitor: Failed to send seller reminder: \(error)")
        }
    }
    
    // MARK: - Manual Refresh
    
    /// Manually trigger a check for active orders
    func refreshCount(userId: UUID) async {
        await checkActiveOrders(userId: userId)
    }
}

