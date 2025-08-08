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
        
        // Initialize PaymentSheet
        self.paymentSheet = PaymentSheet(
            paymentIntentClientSecret: clientSecret,
            configuration: configuration
        )
        
        print("✅ PaymentService: PaymentSheet configured for listing \(listingId)")
    }
    
    /// Presents the Stripe PaymentSheet UI.
    /// - Parameter presentingViewController: The view controller to present from.
    func presentPaymentSheet(from presentingViewController: UIViewController) {
        guard let paymentSheet = paymentSheet else {
            print("❌ PaymentService: PaymentSheet not configured")
            return
        }
        
        paymentSheet.present(from: presentingViewController) { [weak self] paymentResult in
            self?.paymentResult = paymentResult
            
            switch paymentResult {
            case .completed:
                print("✅ Payment completed successfully")
            case .canceled:
                print("⚠️ Payment canceled by user")
            case .failed(let error):
                print("❌ Payment failed: \(error.localizedDescription)")
            }
        }
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


