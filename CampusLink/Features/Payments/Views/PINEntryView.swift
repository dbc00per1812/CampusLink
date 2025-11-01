import SwiftUI

struct PINEntryView: View {
    let orderId: UUID
    let onSuccess: () -> Void
    
    @State private var pin = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Color("ThemeColor"))
                    
                    Text("Enter Verification PIN")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Enter the 4-digit PIN provided by the buyer")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 32)
                
                // PIN Input Display
                HStack(spacing: 12) {
                    ForEach(0..<4, id: \.self) { index in
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(pin.count == index ? Color("ThemeColor") : Color.gray.opacity(0.3), lineWidth: 2)
                                .frame(width: 60, height: 70)
                            
                            if index < pin.count {
                                Text(String(pin[pin.index(pin.startIndex, offsetBy: index)]))
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                            }
                        }
                    }
                }
                
                // Hidden text field for keyboard input
                TextField("", text: $pin)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .frame(width: 1, height: 1)
                    .opacity(0.01)
                    .focused($focusedField)
                    .onChange(of: pin) { newValue in
                        // Limit to 4 digits
                        if newValue.count > 4 {
                            pin = String(newValue.prefix(4))
                        }
                        // Auto-submit when 4 digits entered
                        if pin.count == 4 {
                            Task { await verifyPIN() }
                        }
                    }
                
                // Error message
                if let error = errorMessage {
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.facebookBlue)
                        .padding()
                        .background(Color.facebookBlue.opacity(0.1))
                        .cornerRadius(8)
                }
                
                Spacer()
                
                // Manual submit button
                if pin.count == 4 && !isLoading {
                    Button(action: { Task { await verifyPIN() } }) {
                        Text("Verify PIN")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.green)
                            .cornerRadius(12)
                    }
                }
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") {
                        pin = ""
                        errorMessage = nil
                    }
                    .disabled(pin.isEmpty || isLoading)
                }
            }
            .onAppear {
                focusedField = true
            }
        }
    }
    
    private func verifyPIN() async {
        guard pin.count == 4 else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let _ = try await OrderService.shared.verifyServicePIN(orderId, pin: pin)
            
            await MainActor.run {
                isLoading = false
                onSuccess()
                dismiss()
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
                pin = ""
            }
        }
    }
}

// MARK: - Preview
struct PINEntryView_Previews: PreviewProvider {
    static var previews: some View {
        PINEntryView(orderId: UUID()) {
            print("Success!")
        }
    }
}

