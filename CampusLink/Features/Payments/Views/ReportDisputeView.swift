import SwiftUI
import PhotosUI

struct ReportDisputeView: View {
    let transaction: PaymentTransaction
    let onSubmitted: () -> Void
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var reason: DisputeReason = .notReceived
    @State private var notes: String = ""
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Reason")) {
                    Picker("Reason", selection: $reason) {
                        ForEach(DisputeReason.allCases, id: \.self) { r in
                            Text(r.displayName).tag(r)
                        }
                    }
                }

                Section(header: Text("Details (optional)")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }

                Section(header: Text("Evidence (optional) – up to 3 images")) {
                    if !selectedImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(selectedImages.enumerated()), id: \.offset) { _, image in
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .clipped()
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }

                    PhotosPicker(selection: $selectedItems, maxSelectionCount: 3, matching: .images) {
                        Text(selectedImages.isEmpty ? "Add Photos" : "Add More")
                            .foregroundColor(Color("ThemeColor"))
                    }
                    .onChange(of: selectedItems) { oldValue, newValue in
                        Task { await loadImages() }
                    }
                }

                if let errorMessage = errorMessage {
                    Section { Text(errorMessage).foregroundColor(.red) }
                }
            }
            .navigationTitle("Report a Problem")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSubmitting ? "Submitting..." : "Submit") {
                        Task { await submit() }
                    }
                    .disabled(isSubmitting)
                }
            }
        }
    }

    private func loadImages() async {
        var images: [UIImage] = []
        for item in selectedItems.prefix(3) {
            if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                images.append(img)
            }
        }
        await MainActor.run { selectedImages = images }
    }

    private func submit() async {
        guard let userId = authManager.session?.user.id.uuidString else { return }
        await MainActor.run { isSubmitting = true; errorMessage = nil }

        // Upload evidence images if any
        var evidenceURLs: [String] = []
        if !selectedImages.isEmpty {
            do {
                for image in selectedImages {
                    if let data = image.jpegData(compressionQuality: 0.7) {
                        let path = "\(transaction.id.uuidString)/\(UUID().uuidString).jpg"
                        try await supabase.storage.from("disputes").upload(path, data: data)
                        let url = try supabase.storage.from("disputes").getPublicURL(path: path).absoluteString
                        evidenceURLs.append(url)
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to upload evidence: \(error.localizedDescription)"
                    isSubmitting = false
                }
                return
            }
        }

        // Compose notes + evidence into dispute_notes (schema has no buyer URLs column)
        var disputeNotes = notes
        if !evidenceURLs.isEmpty {
            let joined = evidenceURLs.joined(separator: ", ")
            disputeNotes = notes.isEmpty ? "Evidence: \(joined)" : notes + "\nEvidence: \(joined)"
        }

        do {
            try await supabase
                .from("payments")
                .update([
                    "dispute_status": "open",
                    "dispute_reason": reason.rawValue,
                    "dispute_notes": disputeNotes
                ])
                .eq("id", value: transaction.id.uuidString)
                .execute()

            await MainActor.run {
                isSubmitting = false
                onSubmitted()
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to submit dispute: \(error.localizedDescription)"
                isSubmitting = false
            }
        }
    }
}

enum DisputeReason: String, CaseIterable {
    case notReceived = "not_received"
    case notAsDescribed = "not_as_described"
    case serviceIssue = "service_issue"
    case other = "other"

    var displayName: String {
        switch self {
        case .notReceived: return "Item not received"
        case .notAsDescribed: return "Not as described"
        case .serviceIssue: return "Service issue"
        case .other: return "Other"
        }
    }
}


