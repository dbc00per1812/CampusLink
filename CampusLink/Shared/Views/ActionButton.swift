import SwiftUI

enum ActionButtonType {
    case contactSeller
    case buyNow
    case bookService
    case editListing
    case deleteListing
    
    var title: String {
        switch self {
        case .contactSeller:
            return "Contact Seller"
        case .buyNow:
            return "Buy Now"
        case .bookService:
            return "Book Service"
        case .editListing:
            return "Edit Post"
        case .deleteListing:
            return "Delete Post"
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
        case .editListing:
            return "pencil"
        case .deleteListing:
            return "trash"
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
        case .editListing:
            return Color.blue
        case .deleteListing:
            return Color.facebookBlue
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
            ResponsiveHStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.9)
                        .progressViewStyle(CircularProgressViewStyle(tint: type.foregroundColor))
                } else {
                    Image(systemName: type.icon)
                        .responsiveFont(.headline)
                }
                
                Text(isLoading ? "Loading..." : type.title)
                    .responsiveFont(.headline, weight: .semibold)
            }
            .foregroundColor(isEnabled ? type.foregroundColor : Color.gray)
            .frame(maxWidth: .infinity)
            .responsiveSpacing(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isEnabled ? type.backgroundColor : Color(UIColor.systemGray4))
            )
        }
        .disabled(!isEnabled || isLoading)
        .opacity(isEnabled ? 1.0 : 0.7)
        .accessibleButton(type.title)
    }
}

struct ActionButtonRow: View {
    let listing: ListingWithUser
    let isOwnListing: Bool
    let isContactingLoading: Bool
    let isPrimaryActionLoading: Bool
    let onContactSeller: () -> Void
    let onPrimaryAction: () -> Void
    let onEditListing: (() -> Void)?
    let onDeleteListing: (() -> Void)?
    
    init(listing: ListingWithUser, isOwnListing: Bool, isContactingLoading: Bool = false, isPrimaryActionLoading: Bool = false, onContactSeller: @escaping () -> Void, onPrimaryAction: @escaping () -> Void, onEditListing: (() -> Void)? = nil, onDeleteListing: (() -> Void)? = nil) {
        self.listing = listing
        self.isOwnListing = isOwnListing
        self.isContactingLoading = isContactingLoading
        self.isPrimaryActionLoading = isPrimaryActionLoading
        self.onContactSeller = onContactSeller
        self.onPrimaryAction = onPrimaryAction
        self.onEditListing = onEditListing
        self.onDeleteListing = onDeleteListing
    }
    
    private var shouldShowButtons: Bool {
        let result = !isOwnListing && !listing.isSold
        print("🔍 ActionButtonRow - isOwnListing: \(isOwnListing), isSold: \(listing.isSold), shouldShowButtons: \(result)")
        print("🔍 ActionButtonRow - onEditListing exists: \(onEditListing != nil)")
        print("🔍 ActionButtonRow - onDeleteListing exists: \(onDeleteListing != nil)")
        return result
    }
    
    private var primaryButtonType: ActionButtonType {
        listing.listingType == .product ? .buyNow : .bookService
    }
    
    var body: some View {
        if shouldShowButtons {
            ResponsiveVStack(spacing: 12) {
                ResponsiveHStack(spacing: 12) {
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
                            .responsiveFont(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .responsiveSpacing(8)
                }
            }
        } else if isOwnListing {
            ResponsiveVStack(spacing: 12) {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(Color("ThemeColor"))
                    Text("This is your listing")
                        .responsiveFont(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                ResponsiveHStack(spacing: 12) {
                    if let onEditListing = onEditListing {
                        ActionButton(
                            type: .editListing,
                            action: onEditListing
                        )
                    }
                    
                    if let onDeleteListing = onDeleteListing {
                        ActionButton(
                            type: .deleteListing,
                            action: onDeleteListing
                        )
                    }
                }
            }
            .responsivePadding(16)
            .background(Color(UIColor.systemGray6))
            .responsiveCornerRadius(12)
        } else if listing.isSold {
            ResponsiveVStack(spacing: 8) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.facebookBlue)
                    Text("This listing is no longer available")
                        .responsiveFont(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .responsivePadding(16)
            .background(Color(UIColor.systemGray6))
            .responsiveCornerRadius(12)
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
                    photos: [],
                    isSold: false,
                    listingType: .product,
                    serviceDuration: nil,
                    serviceLocation: nil,
                    serviceAvailability: nil,
                    archived: false,
                    createdAt: Date(),
                    user: User(
                        id: UUID().uuidString, 
                        name: "Test User", 
                        bio: nil, 
                        profilePic: nil, 
                        email: "test@example.com",
                        campus: "Indiana University Bloomington",
                        createdAt: Date(),
                        campusEmailVerified: true,
                        trustScore: 85,
                        stripeConnectId: nil,
                        stripePayoutsEnabled: false,
                        stripeDetailsSubmitted: false,
                        verificationStatus: nil,
                        studentIdImageUrl: nil,
                        verificationSubmittedAt: nil,
                        verificationReviewedAt: nil,
                        verificationNotes: nil
                    ),
                    // Seek mode fields
                    intent: .offer,
                    budgetMin: nil,
                    budgetMax: nil,
                    expiresAt: nil,
                    deliveryMethod: .pickup,
                    quantityAvailable: 1,
                    quantitySold: 0,
                    acceptsOffers: false
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
