import SwiftUI

struct PINDisplayView: View {
    let pin: String
    @State private var isPinRevealed = false
    @State private var showCopiedConfirmation = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Info header
            VStack(spacing: 8) {
                Image(systemName: "key.fill")
                    .font(.system(size: 40))
                    .foregroundColor(Color("ThemeColor"))
                
                Text("Service Verification PIN")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Share this PIN with the seller after they complete the service")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // PIN Display
            HStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { index in
                    Text(isPinRevealed ? String(pin[pin.index(pin.startIndex, offsetBy: index)]) : "•")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .frame(width: 50, height: 60)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                }
            }
            
            // Reveal/Hide Button
            Button(action: {
                withAnimation {
                    isPinRevealed.toggle()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: isPinRevealed ? "eye.slash.fill" : "eye.fill")
                    Text(isPinRevealed ? "Hide PIN" : "Reveal PIN")
                }
                .font(.headline)
                .foregroundColor(Color("ThemeColor"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color("ThemeColor").opacity(0.1))
                .cornerRadius(12)
            }
            
            // Copy Button
            if isPinRevealed {
                Button(action: {
                    UIPasteboard.general.string = pin
                    showCopiedConfirmation = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showCopiedConfirmation = false
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: showCopiedConfirmation ? "checkmark.circle.fill" : "doc.on.doc")
                        Text(showCopiedConfirmation ? "Copied!" : "Copy PIN")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(showCopiedConfirmation ? Color.green : Color("ThemeColor"))
                    .cornerRadius(12)
                }
                .animation(.easeInOut, value: showCopiedConfirmation)
            }
            
            // Warning message
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Important")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                Text("Only share this PIN after the seller has completed the service. Once they enter the PIN, payment will be released from escrow.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
}

// MARK: - Preview
struct PINDisplayView_Previews: PreviewProvider {
    static var previews: some View {
        PINDisplayView(pin: "1234")
            .padding()
            .previewLayout(.sizeThatFits)
    }
}

