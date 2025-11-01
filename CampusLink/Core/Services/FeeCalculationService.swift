import Foundation

/// Service for calculating Stripe processing fees and marketplace pricing
/// Calculates Stripe's standard processing fees (2.9% + 30¢)
/// Implements two-tier pricing: seller price vs. buyer price (rounded up for CampusLink's cut)
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
    
    /// Calculates the buyer price (seller price + Stripe fee, rounded up to next dollar)
    /// Example: $20.00 seller price → $20.88 with fees → $21.00 buyer price
    /// - Parameter sellerPriceCents: Seller's listing price in cents
    /// - Returns: Buyer price in cents (rounded up to next dollar)
    func calculateBuyerPrice(sellerPriceCents: Int) -> Int {
        // Calculate Stripe fee
        let stripeFeeCents = calculateStripeProcessingFee(amountCents: sellerPriceCents)
        
        // Calculate subtotal (seller price + Stripe fee)
        let subtotalCents = sellerPriceCents + stripeFeeCents
        
        // Round UP to next dollar
        let buyerPriceCents = Int(ceil(Double(subtotalCents) / 100.0) * 100.0)
        
        return buyerPriceCents
    }
    
    /// Calculates CampusLink's cut (difference between buyer price and actual costs)
    /// This is the marketplace fee after covering Stripe's processing fees
    /// - Parameter sellerPriceCents: Seller's listing price in cents
    /// - Returns: CampusLink's cut in cents
    func calculateCampusLinkCut(sellerPriceCents: Int) -> Int {
        let stripeFeeCents = calculateStripeProcessingFee(amountCents: sellerPriceCents)
        let subtotalCents = sellerPriceCents + stripeFeeCents
        let buyerPriceCents = calculateBuyerPrice(sellerPriceCents: sellerPriceCents)
        
        return buyerPriceCents - subtotalCents
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
    
    /// Returns a breakdown of fees for display (with new pricing model)
    /// - Parameter sellerPriceCents: Seller's listing price in cents
    /// - Returns: Dictionary with complete fee breakdown
    func getFeeBreakdown(sellerPriceCents: Int) -> [String: Int] {
        let stripeFee = calculateStripeProcessingFee(amountCents: sellerPriceCents)
        let buyerPrice = calculateBuyerPrice(sellerPriceCents: sellerPriceCents)
        let campusLinkCut = calculateCampusLinkCut(sellerPriceCents: sellerPriceCents)
        
        return [
            "seller_price": sellerPriceCents,
            "stripe_fee": stripeFee,
            "buyer_price": buyerPrice,
            "campuslink_cut": campusLinkCut,
            "total": buyerPrice  // Kept for backward compatibility
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
