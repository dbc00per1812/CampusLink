import SwiftUI

struct LegalDocumentView: View {
    let title: String
    let content: String
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(content)
                        .font(.body)
                        .foregroundColor(.primary)
                        .padding()
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

struct LegalDocumentView_Previews: PreviewProvider {
    static var previews: some View {
        LegalDocumentView(
            title: "Sample Legal Document",
            content: "This is sample legal content that would appear in the document..."
        )
    }
}

