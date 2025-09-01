import SwiftUI

enum ActionButtonType {
    case contactSeller
    case buyNow
    case bookService
    
    var title: String {
        switch self {
        case .contactSeller:
            return "Contact Seller"
        case .buyNow:
            return "Buy Now"
        case .bookService:
            return "Book Service"
        }
    }
    
    var icon: String {
        switch self {
        case .contactSeller:
            return "message"
        case .buyNow:
            return "cart"
        case .bookService:
            return "calendar"
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .contactSeller:
            return Color("ThemeColor")
        case .buyNow:
            return Color.green
        case .bookService:
            return Color.blue
        }
    }
    
    var foregroundColor: Color {
        return .white
    }
}

struct ActionButton: View {
    let type: ActionButtonType
    let isEnabled: Bool
    let isLoading: Bool
    let action: () -> Void
    
    init(type: ActionButtonType, isEnabled: Bool = true, isLoading: Bool = false, action: @escaping () -> Void) {
        self.type = type
        self.isEnabled = isEnabled
        self.isLoading = isLoading
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.9)
                        .progressViewStyle(CircularProgressViewStyle(tint: type.foregroundColor))
                } else {
                    Image(systemName: type.icon)
                        .font(.headline)
                }
                
                Text(isLoading ? "Loading..." : type.title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(isEnabled ? type.foregroundColor : Color.gray)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isEnabled ? type.backgroundColor : Color(UIColor.systemGray4))
            )
        }
        .disabled(!isEnabled || isLoading)
        .opacity(isEnabled ? 1.0 : 0.7)
    }
}

struct ActionButtonRow: View {
    let listing: ListingWithUser
    let isOwnListing: Bool
    let isContactingLoading: Bool
    let isPrimaryActionLoading: Bool
    let onContactSeller: () -> Void
    let onPrimaryAction: () -> Void
    
    init(listing: ListingWithUser, isOwnListing: Bool, isContactingLoading: Bool = false, isPrimaryActionLoading: Bool = false, onContactSeller: @escaping () -> Void, onPrimaryAction: @escaping () -> Void) {
        self.listing = listing
        self.isOwnListing = isOwnListing
        self.isContactingLoading = isContactingLoading
        self.isPrimaryActionLoading = isPrimaryActionLoading
        self.onContactSeller = onContactSeller
        self.onPrimaryAction = onPrimaryAction
    }
    
    private var shouldShowButtons: Bool {
        !isOwnListing && !listing.isSold
    }
    
    private var primaryButtonType: ActionButtonType {
        listing.listingType == .product ? .buyNow : .bookService
    }
    
    var body: some View {
        if shouldShowButtons {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    ActionButton(
                        type: .contactSeller,
                        isLoading: isContactingLoading,
                        action: onContactSeller
                    )
                    
                    ActionButton(
                        type: primaryButtonType,
                        isLoading: isPrimaryActionLoading,
                        action: onPrimaryAction
                    )
                }
                
                // Status messaging
                if listing.isSold {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("This item has been sold")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)
                }
            }
        } else if isOwnListing {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(Color("ThemeColor"))
                    Text("This is your listing")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Text("You can manage this listing from your profile")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
        } else if listing.isSold {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.red)
                    Text("This listing is no longer available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
        }
    }
}

struct ActionButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Individual button examples
            ActionButton(type: .contactSeller) {
                #if DEBUG
                print("Contact seller")
                #endif
            }
            
            ActionButton(type: .buyNow) {
                #if DEBUG
                print("Buy now")
                #endif
            }
            
            ActionButton(type: .bookService) {
                #if DEBUG
                print("Book service")
                #endif
            }
            
            // Disabled button
            ActionButton(type: .buyNow, isEnabled: false) {
                #if DEBUG
                print("Disabled")
                #endif
            }
            
            // Button row example
            ActionButtonRow(
                listing: ListingWithUser(
                    id: UUID(),
                    title: "Sample Product",
                    description: "A sample product",
                    price: 99.99,
                    category: "Electronics",
                    photo: nil,
                    isSold: false,
                    listingType: .product,
                    serviceDuration: nil,
                    serviceLocation: nil,
                    serviceAvailability: nil,
                    createdAt: Date(),
                    user: User(
                        id: UUID().uuidString, 
                        name: "Test User", 
                        bio: nil, 
                        profilePic: nil, 
                        email: "test@example.com", 
                        createdAt: Date(),
                        campusEmailVerified: true,
                        trustScore: 85,
                        stripeConnectId: nil,
                        stripePayoutsEnabled: false,
                        stripeDetailsSubmitted: false
                    )
                ),
                isOwnListing: false,
                isContactingLoading: false,
                isPrimaryActionLoading: false,
                onContactSeller: { 
                    #if DEBUG
                    print("Contact")
                    #endif
                },
                onPrimaryAction: { 
                    #if DEBUG
                    print("Buy")
                    #endif
                }
            )
        }
        .padding()
    }
}
