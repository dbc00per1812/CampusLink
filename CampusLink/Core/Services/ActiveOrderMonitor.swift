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
            // First, let's check ALL orders for this user to debug
            let allBuyerOrders: [Order] = try await supabase
                .from("orders")
                .select("""
                    *,
                    listing:listings(*)
                """)
                .eq("buyer_id", value: userId.uuidString)
                .execute()
                .value
            
            let allSellerOrders: [Order] = try await supabase
                .from("orders")
                .select("""
                    *,
                    listing:listings(*)
                """)
                .eq("seller_id", value: userId.uuidString)
                .execute()
                .value
            
            print("📊 ActiveOrderMonitor: Total orders - Buyer: \(allBuyerOrders.count), Seller: \(allSellerOrders.count)")
            
            // Log all orders with their statuses
            for order in allBuyerOrders {
                print("   Buyer Order \(order.id): status=\(order.orderStatus.rawValue), payment=\(order.paymentStatus.rawValue)")
            }
            for order in allSellerOrders {
                print("   Seller Order \(order.id): status=\(order.orderStatus.rawValue), payment=\(order.paymentStatus.rawValue)")
            }
            
            // Check orders where user is buyer and needs to take action
            // 1. Buyer needs to PAY (order_status=placed, payment_status=pending)
            // 2. Buyer needs to CONFIRM RECEIPT (order_status=seller_confirmed, payment_status=requires_capture)
            let buyerOrdersNeedPay: [Order] = try await supabase
                .from("orders")
                .select("""
                    *,
                    listing:listings(*)
                """)
                .eq("buyer_id", value: userId.uuidString)
                .eq("order_status", value: "placed")
                .eq("payment_status", value: "pending")
                .execute()
                .value
            
            let buyerOrdersNeedConfirm: [Order] = try await supabase
                .from("orders")
                .select("""
                    *,
                    listing:listings(*)
                """)
                .eq("buyer_id", value: userId.uuidString)
                .eq("order_status", value: "seller_confirmed")
                .eq("payment_status", value: "requires_capture")
                .execute()
                .value
            
            let buyerOrders = buyerOrdersNeedPay + buyerOrdersNeedConfirm
            
            print("📊 ActiveOrderMonitor: Buyer breakdown - \(buyerOrdersNeedPay.count) need payment, \(buyerOrdersNeedConfirm.count) need confirmation")
            
            // Check orders where user is seller and needs to deliver
            // ONLY when payment is completed (payment_status = succeeded OR requires_capture)
            // NOT when payment is still pending (buyer hasn't paid yet)
            let sellerOrders: [Order] = try await supabase
                .from("orders")
                .select("""
                    *,
                    listing:listings(*)
                """)
                .eq("seller_id", value: userId.uuidString)
                .`in`("order_status", values: ["placed", "in_progress"])
                .`in`("payment_status", values: ["succeeded", "requires_capture"])
                .execute()
                .value
            
            print("📊 ActiveOrderMonitor: Seller breakdown - \(sellerOrders.count) need delivery (payment completed)")
            
            // Log which specific orders are being counted
            for order in buyerOrdersNeedPay {
                print("   📍 BUYER NEEDS TO PAY: Order \(order.id)")
            }
            for order in buyerOrdersNeedConfirm {
                print("   📍 BUYER NEEDS TO CONFIRM: Order \(order.id)")
            }
            for order in sellerOrders {
                print("   📍 SELLER NEEDS TO DELIVER: Order \(order.id)")
            }
            
            await MainActor.run {
                self.buyerPendingCount = buyerOrders.count
                self.sellerPendingCount = sellerOrders.count
                self.ordersRequiringAction = buyerOrders.count + sellerOrders.count
            }
            
            print("📊 ActiveOrderMonitor: TOTAL requiring action = \(buyerOrders.count + sellerOrders.count)")
            
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

