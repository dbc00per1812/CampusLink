import SwiftUI

struct ListingStickerView: View {
    let title: String
    let price: String
    let description: String
    let image: UIImage?
    
    var body: some View {
        VStack(spacing: 0) {
            // Image Area
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 300, height: 250)
                    .clipped()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(red: 0.0, green: 0.478, blue: 1.0),
                            Color(red: 0.0, green: 0.378, blue: 0.9)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: "photo")
                        .font(.system(size: 50))
                        .foregroundColor(.white.opacity(0.6))
                }
                .frame(width: 300, height: 250)
            }
            
            // Details with improved design
            VStack(alignment: .leading, spacing: 14) {
                // Title and Price
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(.black)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text(price)
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundColor(Color(red: 0.0, green: 0.478, blue: 1.0)) // CampusLink Blue
                }
                
                // Description
                if !description.isEmpty {
                    Text(description)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                // Divider with CampusLink branding
                Divider()
                    .background(Color.gray.opacity(0.3))
                
                // Footer with app branding
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "graduationcap.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color(red: 0.0, green: 0.478, blue: 1.0))
                        Text("CampusLink")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Text("Tap to Open")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(red: 0.0, green: 0.478, blue: 1.0))
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 14))
                        .foregroundColor(Color(red: 0.0, green: 0.478, blue: 1.0))
                    }
                }
            }
            .padding(18)
            .background(Color.white)
        }
        .frame(width: 300)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }
}

#if DEBUG
struct ListingStickerView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray // Background to see the sticker boundaries
            
            ListingStickerView(
                title: "iPhone 13 Pro Max 256GB",
                price: "$799",
                description: "In excellent condition, battery health 95%. Comes with original box and charging cable.",
                image: nil
            )
        }
    }
}
#endif


