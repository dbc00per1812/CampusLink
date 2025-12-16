import Foundation

/// Service for calculating Stripe processing fees and marketplace pricing
/// Calculates Stripe's standard processing fees (2.9% + 30¢)
/// No platform fee - buyer pays exact seller price + Stripe processing fee
final class FeeCalculationService: ObservableObject {
    static let shared = FeeCalculationService()
    private init() {}
    
    // MARK: - Stripe Processing Fees
    
    /// Calculates Stripe's standard processing fee for a given amount
    /// - Parameter amountCents: Amount in cents
    /// - Returns: Processing fee in cents
    func calculateStripeProcessingFee(amountCents: Int) -> Int {
        let amount = Double(amountCents) / 100.0
        let percentageFee = amount * 0.029 // 2.9%
        let flatFee = 30 // 30 cents
        let totalFee = (percentageFee * 100) + Double(flatFee)
        return Int(round(totalFee))
    }
    
    // MARK: - Buyer Price Calculations
    
    /// Calculates the buyer price (seller price + Stripe fee, exact amount - no rounding)
    /// Example: $20.00 seller price → $20.88 buyer price (exact)
    /// - Parameter sellerPriceCents: Seller's listing price in cents
    /// - Returns: Buyer price in cents (exact, no rounding)
    func calculateBuyerPrice(sellerPriceCents: Int) -> Int {
        // Calculate Stripe fee
        let stripeFeeCents = calculateStripeProcessingFee(amountCents: sellerPriceCents)
        
        // Buyer pays exact amount: seller price + Stripe fee (no rounding, no platform fee)
        let buyerPriceCents = sellerPriceCents + stripeFeeCents
        
        return buyerPriceCents
    }
    
    /// CampusLink's cut is always $0 - no platform fee
    /// - Parameter sellerPriceCents: Seller's listing price in cents
    /// - Returns: Always 0 (no platform fee)
    func calculateCampusLinkCut(sellerPriceCents: Int) -> Int {
        return 0  // No platform fee - only Stripe processing fee is charged
    }
    
    /// Calculates the total amount including Stripe processing fees
    /// - Parameter baseAmountCents: Base amount in cents (listing price)
    /// - Returns: Total amount including fees in cents
    func calculateTotalWithFees(baseAmountCents: Int) -> Int {
        return baseAmountCents + calculateStripeProcessingFee(amountCents: baseAmountCents)
    }
    
    /// Formats fee amount for display
    /// - Parameter feeCents: Fee amount in cents
    /// - Returns: Formatted string (e.g., "$0.87")
    func formatFee(feeCents: Int) -> String {
        let fee = Double(feeCents) / 100.0
        return String(format: "$%.2f", fee)
    }
    
    /// Formats total amount for display
    /// - Parameter totalCents: Total amount in cents
    /// - Returns: Formatted string (e.g., "$22.87")
    func formatTotal(totalCents: Int) -> String {
        let total = Double(totalCents) / 100.0
        return String(format: "$%.2f", total)
    }
    
    // MARK: - Fee Breakdown
    
    /// Returns a breakdown of fees for display (no platform fee model)
    /// - Parameter sellerPriceCents: Seller's listing price in cents
    /// - Returns: Dictionary with complete fee breakdown
    func getFeeBreakdown(sellerPriceCents: Int) -> [String: Int] {
        let stripeFee = calculateStripeProcessingFee(amountCents: sellerPriceCents)
        let buyerPrice = calculateBuyerPrice(sellerPriceCents: sellerPriceCents)
        
        return [
            "seller_price": sellerPriceCents,
            "stripe_fee": stripeFee,
            "buyer_price": buyerPrice,
            "campuslink_cut": 0,  // No platform fee
            "total": buyerPrice
        ]
    }
    
    /// Legacy method for backward compatibility
    /// - Parameter baseAmountCents: Base amount in cents
    /// - Returns: Dictionary with fee breakdown
    func getFeeBreakdown(baseAmountCents: Int) -> [String: Int] {
        return getFeeBreakdown(sellerPriceCents: baseAmountCents)
    }
    
    // MARK: - Validation
    
    /// Validates that fees are reasonable (not more than 10% of base amount)
    /// - Parameter baseAmountCents: Base amount in cents
    /// - Returns: True if fees are reasonable
    func validateFees(baseAmountCents: Int) -> Bool {
        let fee = calculateStripeProcessingFee(amountCents: baseAmountCents)
        let feePercentage = Double(fee) / Double(baseAmountCents)
        return feePercentage <= 0.10 // Max 10%
    }
}
