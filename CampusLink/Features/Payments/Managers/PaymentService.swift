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

    /// Calls the `create_payment_intent` Edge Function to prepare a Stripe PaymentIntent.
    /// - Parameter listingId: The identifier of the listing that the user intends to purchase.
    /// - Returns: The client secret string used to initialize Stripe's PaymentSheet on iOS.
    func preparePaymentSheet(listingId: String) async throws -> String {
        let url = try functionsURL(appendingPath: "create_payment_intent")

        struct RequestBody: Encodable { let listing_id: String }
        struct ResponseBody: Decodable { let client_secret: String }

        let token = try await currentAccessToken()
        let request = try makeRequest(url: url, token: token, body: RequestBody(listing_id: listingId))

        let (data, response) = try await URLSession.shared.data(for: request)
        try ensureSuccess(response: response, data: data)

        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        return decoded.client_secret
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
    
    /// Prepares and configures the Stripe PaymentSheet for a listing purchase.
    /// - Parameter listingId: The identifier of the listing to purchase.
    func configurePaymentSheet(for listingId: String) async throws {
        // Get the client secret from our Edge Function
        let clientSecret = try await preparePaymentSheet(listingId: listingId)
        
        // Configure the PaymentSheet
        var configuration = PaymentSheet.Configuration()
        configuration.merchantDisplayName = "CampusLink"
        configuration.allowsDelayedPaymentMethods = false
        
        // Enable Apple Pay
        configuration.applePay = .init(merchantId: "merchant.campuslink.com.campuslink", merchantCountryCode: "US")
        // Initialize PaymentSheet
        self.paymentSheet = PaymentSheet(
            paymentIntentClientSecret: clientSecret,
            configuration: configuration
        )
        
        #if DEBUG
        print("✅ PaymentService: PaymentSheet configured for listing \(listingId)")
        #endif
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
        
        paymentSheet.present(from: presentingViewController) { [weak self] paymentResult in
            self?.paymentResult = paymentResult
            
            switch paymentResult {
            case .completed:
                #if DEBUG
                print("✅ Payment completed successfully")
                #endif
                // Update order with payment intent ID for escrow tracking
                Task { [weak self] in
                    await self?.handlePaymentCompletion()
                }
            case .canceled:
                #if DEBUG
                print("⚠️ Payment canceled by user")
                #endif
            case .failed(let error):
                #if DEBUG
                print("❌ Payment failed: \(error.localizedDescription)")
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


