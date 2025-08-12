import SwiftUI

struct DisputeDetailView: View, Identifiable {
    let id = UUID()
    let transaction: PaymentTransaction
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(transaction.listing?.title ?? "Listing")
                        .font(.headline)
                    Spacer()
                    StatusBadge(text: (transaction.disputeStatus?.rawValue ?? "none").replacingOccurrences(of: "_", with: " ").capitalized, color: .orange)
                }

                GroupBox(label: Text("Reason")) {
                    Text(transaction.disputeReason?.replacingOccurrences(of: "_", with: " ").capitalized ?? "-")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox(label: Text("Notes / Evidence")) {
                    ScrollView {
                        Text(transaction.disputeNotes ?? "-")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 240)
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


