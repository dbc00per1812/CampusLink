import Foundation

/// Service for calculating Stripe processing fees
/// Currently only calculates Stripe's standard processing fees (2.9% + 30¢)
/// No additional marketplace fees are charged
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
    
    /// Returns a breakdown of fees for display
    /// - Parameter baseAmountCents: Base amount in cents
    /// - Returns: Dictionary with fee breakdown
    func getFeeBreakdown(baseAmountCents: Int) -> [String: Int] {
        let stripeFee = calculateStripeProcessingFee(amountCents: baseAmountCents)
        let total = baseAmountCents + stripeFee
        
        return [
            "base": baseAmountCents,
            "stripe_fee": stripeFee,
            "total": total
        ]
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
