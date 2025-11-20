import Foundation
import Supabase
import StripePaymentSheet
import UIKit  // Needed for UIViewController

/// A thin service responsible for calling Supabase Edge Functions involved in the payment flow.
/// - It uses the current Supabase auth session to authorize requests via Bearer token.
/// - It communicates with the deployed functions: `create_payment_intent` and `capture_payment`.
@MainActor
final class PaymentService: ObservableObject {
    static let shared = PaymentService()
    
    @Published var paymentSheet: PaymentSheet?
    @Published var paymentResult: PaymentSheetResult?
    
    // MARK: - Fee Calculation
    private let feeService = FeeCalculationService.shared
    
    /// Calculates Stripe processing fees for a given amount
    /// - Parameter amountCents: Amount in cents
    /// - Returns: Processing fee in cents
    func calculateProcessingFee(amountCents: Int) -> Int {
        return feeService.calculateStripeProcessingFee(amountCents: amountCents)
    }
    
    /// Gets total amount including processing fees
    /// - Parameter baseAmountCents: Base amount in cents
    /// - Returns: Total amount including fees in cents
    func getTotalWithFees(baseAmountCents: Int) -> Int {
        return feeService.calculateTotalWithFees(baseAmountCents: baseAmountCents)
    }
    
    /// Gets fee breakdown for display
    /// - Parameter baseAmountCents: Base amount in cents
    /// - Returns: Dictionary with fee breakdown
    func getFeeBreakdown(baseAmountCents: Int) -> [String: Int] {
        return feeService.getFeeBreakdown(baseAmountCents: baseAmountCents)
    }
    
    private init() {
        // Configure Stripe with publishable key
        STPAPIClient.shared.publishableKey = Secrets.stripePublishableKey
    }

    // MARK: - Public API

    /// Calls the `create_payment_intent` Edge Function to prepare payment for an existing order (from accepted offer).
    /// - Parameter orderId: The identifier of the unpaid order
    /// - Returns: Tuple containing client secret and fee information
    func preparePaymentSheetForOrder(orderId: String) async throws -> (clientSecret: String, baseAmountCents: Int, stripeFeeCents: Int, totalAmountCents: Int) {
        #if DEBUG
        print("🔍 PaymentService: Calling create_payment_intent for order \(orderId)")
        #endif
        
        let url = try functionsURL(appendingPath: "create_payment_intent")

        struct RequestBody: Encodable { let order_id: String }
        
        struct ResponseBodyWithPricing: Decodable {
            let client_secret: String
            let seller_price_cents: Int
            let buyer_price_cents: Int
            let stripe_fee_cents: Int
            let campuslink_cut_cents: Int?
        }

        let token = try await currentAccessToken()
        let request = try makeRequest(url: url, token: token, body: RequestBody(order_id: orderId))

        #if DEBUG
        print("🌐 Making request to: \(url.absoluteString)")
        #endif
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        #if DEBUG
        if let httpResponse = response as? HTTPURLResponse {
            print("📥 Response status: \(httpResponse.statusCode)")
            print("📥 Response data: \(String(data: data, encoding: .utf8) ?? "nil")")
        }
        #endif
        
        // Check for errors before decoding
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Edge function error: \(errorString)")
            throw NSError(domain: "PaymentService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error: \(errorString)"])
        }
        
        try ensureSuccess(response: response, data: data)
        
        let decoded = try JSONDecoder().decode(ResponseBodyWithPricing.self, from: data)
        
        #if DEBUG
        print("✅ Decoded payment intent for order")
        print("   Seller price: $\(Double(decoded.seller_price_cents)/100)")
        print("   Buyer price: $\(Double(decoded.buyer_price_cents)/100)")
        print("   Stripe fee: $\(Double(decoded.stripe_fee_cents)/100)")
        #endif
        
        return (decoded.client_secret, decoded.seller_price_cents, decoded.stripe_fee_cents, decoded.buyer_price_cents)
    }

    /// Calls the `create_payment_intent` Edge Function to prepare a Stripe PaymentIntent.
    /// - Parameter listingId: The identifier of the listing that the user intends to purchase.
    /// - Returns: Tuple containing client secret and fee information
    func preparePaymentSheet(listingId: String) async throws -> (clientSecret: String, baseAmountCents: Int, stripeFeeCents: Int, totalAmountCents: Int) {
        #if DEBUG
        print("🔍 PaymentService: Calling create_payment_intent for listing \(listingId)")
        #endif
        
        let url = try functionsURL(appendingPath: "create_payment_intent")

        struct RequestBody: Encodable { let listing_id: String }
        
        // Check if the server returns the new format with fees
        struct ResponseBodyWithFees: Decodable { 
            let client_secret: String
            let base_amount_cents: Int?
            let stripe_fee_cents: Int?
            let total_amount_cents: Int?
        }
        
        // Fallback for old format
        struct ResponseBodyOld: Decodable {
            let client_secret: String
        }

        let token = try await currentAccessToken()
        let request = try makeRequest(url: url, token: token, body: RequestBody(listing_id: listingId))

        #if DEBUG
        print("🌐 Making request to: \(url.absoluteString)")
        #endif
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        #if DEBUG
        if let httpResponse = response as? HTTPURLResponse {
            print("📥 Response status: \(httpResponse.statusCode)")
            print("📥 Response data: \(String(data: data, encoding: .utf8) ?? "nil")")
        }
        #endif
        
        try ensureSuccess(response: response, data: data)
        
        // New response format includes seller_price_cents and buyer_price_cents
        struct ResponseBodyWithPricing: Decodable {
            let client_secret: String
            let seller_price_cents: Int
            let buyer_price_cents: Int
            let stripe_fee_cents: Int
            let campuslink_cut_cents: Int?
        }
        
        // Try new format first, fallback to old format
        do {
            let decoded = try JSONDecoder().decode(ResponseBodyWithPricing.self, from: data)
            
            #if DEBUG
            print("✅ Decoded payment intent with pricing")
            print("   Seller price: $\(Double(decoded.seller_price_cents)/100)")
            print("   Buyer price: $\(Double(decoded.buyer_price_cents)/100)")
            print("   Stripe fee: $\(Double(decoded.stripe_fee_cents)/100)")
            #endif
            
            // Return seller price as baseAmount for backward compatibility
            // Total amount is now buyer price (rounded up)
            return (decoded.client_secret, decoded.seller_price_cents, decoded.stripe_fee_cents, decoded.buyer_price_cents)
        } catch {
            #if DEBUG
            print("⚠️ Failed to decode ResponseBodyWithPricing: \(error)")
            #endif
            
            // Try old format with fees
            do {
                let decoded = try JSONDecoder().decode(ResponseBodyWithFees.self, from: data)
                
                if let baseAmount = decoded.base_amount_cents,
                   let stripeFee = decoded.stripe_fee_cents,
                   let totalAmount = decoded.total_amount_cents {
                    #if DEBUG
                    print("✅ Decoded payment intent with fees (old format)")
                    #endif
                    return (decoded.client_secret, baseAmount, stripeFee, totalAmount)
                } else {
                    print("⚠️ Server didn't return fee information, calculating locally")
                    return (decoded.client_secret, 0, 0, 0)
                }
            } catch {
                #if DEBUG
                print("⚠️ Failed to decode ResponseBodyWithFees: \(error)")
                #endif
                
                // Try old format without fees
                do {
                    let decoded = try JSONDecoder().decode(ResponseBodyOld.self, from: data)
                    print("⚠️ Using old response format without fee information")
                    return (decoded.client_secret, 0, 0, 0)
                } catch {
                    print("❌ Failed to decode payment intent response: \(error)")
                    print("Response data: \(String(data: data, encoding: .utf8) ?? "nil")")
                    throw PaymentServiceError.invalidResponse
                }
            }
        }
    }

    /// Calls the `capture_payment` Edge Function to capture funds for a previously authorized PaymentIntent.
    /// - Parameter paymentIntentId: The Stripe PaymentIntent identifier to capture.
    func capturePayment(paymentIntentId: String) async throws {
        let url = try functionsURL(appendingPath: "capture_payment")

        struct RequestBody: Encodable { let payment_intent_id: String }

        let token = try await currentAccessToken()
        let request = try makeRequest(url: url, token: token, body: RequestBody(payment_intent_id: paymentIntentId))

        let (data, response) = try await URLSession.shared.data(for: request)
        try ensureSuccess(response: response, data: data)
        _ = data // no-op; server returns status JSON which we do not currently need
    }
    
    /// Calls the `cancel_payment` Edge Function to void/cancel a previously authorized PaymentIntent.
    /// - Parameter paymentIntentId: The Stripe PaymentIntent identifier to cancel.
    func cancelPayment(paymentIntentId: String) async throws {
        let url = try functionsURL(appendingPath: "cancel_payment")

        struct RequestBody: Encodable { let payment_intent_id: String }

        let token = try await currentAccessToken()
        let request = try makeRequest(url: url, token: token, body: RequestBody(payment_intent_id: paymentIntentId))

        let (data, response) = try await URLSession.shared.data(for: request)
        try ensureSuccess(response: response, data: data)
        _ = data // no-op; server returns status JSON which we do not currently need
    }
    
    /// Prepares and configures the Stripe PaymentSheet for paying an existing order (from accepted offer).
    /// - Parameter orderId: The identifier of the unpaid order
    /// - Returns: Fee information for display
    func configurePaymentSheetForOrder(_ orderId: String) async throws -> (baseAmountCents: Int, stripeFeeCents: Int, totalAmountCents: Int) {
        // Get the client secret and fee info from our Edge Function
        let (clientSecret, baseAmountCents, stripeFeeCents, totalAmountCents) = try await preparePaymentSheetForOrder(orderId: orderId)
        
        #if DEBUG
        print("🔍 PaymentService: Configuring PaymentSheet for order")
        print("   Order ID: \(orderId)")
        print("   Client Secret: \(clientSecret.prefix(20))...")
        print("   Base Amount: $\(Double(baseAmountCents)/100)")
        print("   Stripe Fee: $\(Double(stripeFeeCents)/100)")
        print("   Total Amount: $\(Double(totalAmountCents)/100)")
        #endif
        
        // Configure the PaymentSheet
        var configuration = PaymentSheet.Configuration()
        configuration.merchantDisplayName = "CampusLink"
        configuration.allowsDelayedPaymentMethods = false
        
        // Enable Apple Pay
        configuration.applePay = .init(merchantId: "merchant.campuslink.com.campuslink", merchantCountryCode: "US")
        
        #if DEBUG
        print("✅ Apple Pay enabled")
        #endif
        
        // Initialize PaymentSheet
        self.paymentSheet = PaymentSheet(
            paymentIntentClientSecret: clientSecret,
            configuration: configuration
        )
        
        #if DEBUG
        print("✅ PaymentService: PaymentSheet configured for order")
        #endif
        
        return (baseAmountCents, stripeFeeCents, totalAmountCents)
    }
    
    /// Prepares and configures the Stripe PaymentSheet for a listing purchase.
    /// - Parameter listingId: The identifier of the listing to purchase.
    /// - Returns: Fee information for display
    func configurePaymentSheet(for listingId: String) async throws -> (baseAmountCents: Int, stripeFeeCents: Int, totalAmountCents: Int) {
        // Get the client secret and fee info from our Edge Function
        let (clientSecret, baseAmountCents, stripeFeeCents, totalAmountCents) = try await preparePaymentSheet(listingId: listingId)
        
        #if DEBUG
        print("🔍 PaymentService: Configuring PaymentSheet")
        print("   Listing ID: \(listingId)")
        print("   Client Secret: \(clientSecret.prefix(20))...")
        print("   Base Amount: $\(Double(baseAmountCents)/100)")
        print("   Stripe Fee: $\(Double(stripeFeeCents)/100)")
        print("   Total Amount: $\(Double(totalAmountCents)/100)")
        #endif
        
        // Configure the PaymentSheet
        var configuration = PaymentSheet.Configuration()
        configuration.merchantDisplayName = "CampusLink"
        configuration.allowsDelayedPaymentMethods = false
        
        // Enable Apple Pay
        configuration.applePay = .init(merchantId: "merchant.campuslink.com.campuslink", merchantCountryCode: "US")
        
        #if DEBUG
        print("✅ Apple Pay enabled")
        #endif
        
        // Initialize PaymentSheet
        self.paymentSheet = PaymentSheet(
            paymentIntentClientSecret: clientSecret,
            configuration: configuration
        )
        
        #if DEBUG
        print("✅ PaymentService: PaymentSheet configured successfully")
        #endif
        
        return (baseAmountCents, stripeFeeCents, totalAmountCents)
    }
    
    /// Presents the Stripe PaymentSheet UI.
    /// - Parameter presentingViewController: The view controller to present from.
    func presentPaymentSheet(from presentingViewController: UIViewController) {
        guard let paymentSheet = paymentSheet else {
            #if DEBUG
            print("❌ PaymentService: PaymentSheet not configured")
            #endif
            return
        }
        
        #if DEBUG
        print("🔍 PaymentService: About to present PaymentSheet")
        #endif
        
        paymentSheet.present(from: presentingViewController) { [weak self] paymentResult in
            #if DEBUG
            print("🔍 PaymentService: PaymentSheet dismissed with result: \(paymentResult)")
            #endif
            
            self?.paymentResult = paymentResult
            
            switch paymentResult {
            case .completed:
                #if DEBUG
                print("✅ PaymentService: Payment completed successfully")
                #endif
                // Update order with payment intent ID for escrow tracking
                Task { [weak self] in
                    await self?.handlePaymentCompletion()
                }
            case .canceled:
                #if DEBUG
                print("⚠️ PaymentService: Payment canceled - either by user or Stripe validation failure")
                #endif
            case .failed(let error):
                #if DEBUG
                print("❌ PaymentService: Payment failed with error: \(error)")
                print("❌ PaymentService: Error type: \(type(of: error))")
                print("❌ PaymentService: Error localized: \(error.localizedDescription)")
                #endif
            }
        }
    }
    
    /// Handles payment completion by updating order with payment intent ID
    private func handlePaymentCompletion() async {
        // This would typically be called with the order ID and payment intent ID
        // For now, we'll log that payment was completed
        #if DEBUG
        print("✅ PaymentService: Payment completed, order should be updated with payment intent ID")
        #endif
    }
    
    /// Updates an order with payment intent ID for escrow tracking
    /// - Parameters:
    ///   - orderId: The order ID to update
    ///   - paymentIntentId: The Stripe payment intent ID
    func updateOrderWithPaymentIntent(orderId: UUID, paymentIntentId: String) async throws {
        let orderService = OrderService.shared
        try await orderService.updateOrderWithPaymentIntent(orderId, paymentIntentId: paymentIntentId)
        
        #if DEBUG
        print("✅ PaymentService: Order \(orderId) updated with payment intent \(paymentIntentId)")
        #endif
    }

    // MARK: - Helpers

    /// Builds the Functions base URL from the configured `Secrets.supabaseURL`.
    /// Example: https://vnmzijluyctlufnzxast.supabase.co -> https://vnmzijluyctlufnzxast.functions.supabase.co/
    private func functionsBaseURL() throws -> URL {
        let base = Secrets.supabaseURL.absoluteString
        guard base.hasPrefix("https://"), base.hasSuffix(".supabase.co") else {
            throw PaymentServiceError.invalidSupabaseURL
        }
        let ref = base
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: ".supabase.co", with: "")
        let functionsString = "https://\(ref).functions.supabase.co/"
        guard let url = URL(string: functionsString) else {
            throw PaymentServiceError.invalidSupabaseURL
        }
        return url
    }

    private func functionsURL(appendingPath path: String) throws -> URL {
        try functionsBaseURL().appendingPathComponent(path)
    }

    private func currentAccessToken() async throws -> String {
        let session = try await supabase.auth.session
        return session.accessToken
    }

    private func makeRequest<Body: Encodable>(url: URL, token: String, body: Body) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    private func ensureSuccess(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw PaymentServiceError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? ""
            throw PaymentServiceError.serverError(status: http.statusCode, message: message)
        }
    }
}

enum PaymentServiceError: Error, LocalizedError {
    case invalidSupabaseURL
    case invalidResponse
    case serverError(status: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidSupabaseURL:
            return "Supabase URL is not in the expected format."
        case .invalidResponse:
            return "Received an invalid response from the server."
        case let .serverError(status, message):
            return "Server error (\(status)): \(message)"
        }
    }
}


