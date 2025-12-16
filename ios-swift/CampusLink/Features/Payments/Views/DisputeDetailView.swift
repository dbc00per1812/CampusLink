import SwiftUI

struct DisputeDetailView: View, Identifiable {
    let id = UUID()
    let order: Order
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(order.listing?.title ?? "Listing")
                        .font(.headline)
                    Spacer()
                    StatusBadge(text: "Disputed", color: .orange)
                }

                GroupBox(label: Text("Order Status")) {
                    Text(order.orderStatus.displayName)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox(label: Text("Payment Status")) {
                    Text(order.paymentStatus.displayName)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Dispute Details")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct StatusBadge: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(8)
    }
}


