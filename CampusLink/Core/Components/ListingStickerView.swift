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
                    Color.gray.opacity(0.1)
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                }
                .frame(width: 300, height: 250)
            }
            
            // Details
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Text(price)
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundColor(Color(red: 0.0, green: 0.478, blue: 1.0)) // CampusLink Blue
                }
                
                if !description.isEmpty {
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                Divider()
                    .padding(.vertical, 4)
                
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "graduationcap.fill")
                            .foregroundColor(Color(red: 0.0, green: 0.478, blue: 1.0))
                        Text("CampusLink")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Text("Open App")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(red: 0.0, green: 0.478, blue: 1.0))
                }
            }
            .padding(16)
            .background(Color.white)
        }
        .frame(width: 300)
        .background(Color.white)
        .cornerRadius(24)
        // No shadow here as it will be part of the sticker image itself, 
        // but we can add a border if needed.
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


