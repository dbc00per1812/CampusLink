import SwiftUI

struct TransactionActionSheetView: View {
    @Environment(\.dismiss) private var dismiss
    let order: Order
    let isBuyer: Bool
    let canConfirm: Bool
    let onConfirm: () -> Void
    let onContactSeller: () -> Void
    let onReport: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Large header with title and price
                VStack(alignment: .leading, spacing: 6) {
                    Text(order.listing?.title ?? "Listing")
                        .font(.title)
                        .fontWeight(.bold)
                    Text(order.formattedPrice)
                        .font(.title2)
                        .foregroundColor(Color("ThemeColor"))
                    if let desc = order.listing?.description, !desc.isEmpty {
                        Text(desc)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .lineLimit(4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

                // Quick badges
                HStack(spacing: 10) {
                    if order.orderStatus == .disputed { badge(text: "Disputed", color: .orange) }
                    if order.paymentStatus == .requiresCapture { badge(text: "Requires Capture", color: .orange) }
                    if order.orderStatus == .completed { badge(text: "Completed", color: .green) }
                    if order.paymentStatus == .succeeded { badge(text: "Paid", color: .green) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

                Spacer()

                VStack(spacing: 14) {
                    if isBuyer {
                        Button(action: onConfirm) {
                            Text("Confirm Received")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(canConfirm ? Color.green : Color.gray)
                                .cornerRadius(14)
                        }.disabled(!canConfirm)
                    }

                    Button(action: onContactSeller) {
                        Text("Contact Seller")
                            .font(.headline)
                            .foregroundColor(Color("ThemeColor"))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 14).stroke(Color("ThemeColor"), lineWidth: 2)
                            )
                    }

                    Button(action: onReport) {
                        Text("Report Problem")
                            .font(.headline)
                            .foregroundColor(.facebookBlue)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.facebookBlue.opacity(0.08))
                            .cornerRadius(14)
                    }
                }
                .padding(.horizontal)

                Spacer(minLength: 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
    // local badge view helper (must be declared at type scope)
    @ViewBuilder
    private func badge(text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(6)
    }
}


