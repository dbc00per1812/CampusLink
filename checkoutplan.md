# CampusLink Marketplace Execution Plan

## 📊 Current State Analysis

**✅ Already Built:**
- Basic listing creation (PostView) - title, description, price, category, photo
- Listing display (HomeTabView) - shows all listings in feed format
- Data models (Listing, ListingCreate, ListingWithUser)
- Image upload to Supabase storage
- User authentication & profiles

**❌ Missing Critical Components:**
- Individual listing detail view
- Purchase/contact flows
- Service vs Product differentiation
- Transaction management
- Messaging system
- Payment integration
- Escrow system
- Dispute resolution

---

## 🎯 Phase 1: Core Marketplace Foundation (Week 1-2)

### P1.1: Listing Types & Categories
**Priority: HIGH** | **Effort: 2 days** | **Status: TODO**

**Current Issue:** No distinction between products vs services
**Solution:** Extend listing model and UI

**Tasks:**
- [ ] Add `listingType` enum to ProductModels.swift: `.product` / `.service`
- [ ] Update PostView to include type selection
- [ ] Add service-specific fields:
  - `duration` (1 hour, 2 hours, 1 day, etc.)
  - `location` (on-campus, off-campus, remote)
  - `availability` (weekdays, weekends, anytime)
- [ ] Update database schema in Supabase
- [ ] Migrate existing listings to `.product` type

**Acceptance Criteria:**
- Users can choose between product/service when posting
- Service listings show duration and location options
- Existing listings still display correctly

### P1.2: Individual Listing Detail View
**Priority: HIGH** | **Effort: 3 days** | **Status: COMPLETED**

**Current Issue:** No way to view full listing details or take action
**Solution:** Create comprehensive listing detail screen

**Tasks:**
- [x] Create `ListingDetailView.swift` in Features/Marketplace/Views/
- [x] Navigation from ListingCard tap
- [x] Display full listing info:
  - Large photo display (300px height)
  - Full description with proper spacing
  - Seller profile (name, email, member since date)
  - Price and category prominently displayed
  - Listing date and status
  - Service-specific details (duration, location, availability)
- [x] Action buttons (placeholder for P1.3)

**Acceptance Criteria:**
- Tapping any listing card opens detail view
- All listing information is clearly displayed
- Smooth navigation back to feed

### P1.3: Primary Action Buttons
**Priority: HIGH** | **Effort: 2 days** | **Status: COMPLETED**

**Current Issue:** No way to interact with listings
**Solution:** Add action buttons to listing detail

**Design Patterns:**

**For Products:**
```
[💬 Contact Seller] [💳 Buy Now]
```

**For Services:**
```
[💬 Contact Seller] [📅 Book Service]
```

**Tasks:**
- [x] Add action button component to Shared/Views/
- [x] Implement button logic with loading states and haptic feedback
- [x] Different buttons based on listing type (Contact Seller + Buy Now/Book Service)
- [x] Disable if user owns the listing (shows ownership message)
- [x] Handle sold/unavailable state (shows appropriate messaging)

**Acceptance Criteria:**
- ✅ Appropriate buttons show based on listing type
- ✅ Buttons are disabled for own listings  
- ✅ Visual feedback on button press (haptic feedback + loading states)
- ✅ Clear messaging for different states (own listing, sold items)

---

## 🛒 Phase 2: Purchase & Booking Flows (Week 3-4)

### P2.1: Product Purchase Flow
**Priority: HIGH** | **Effort: 5 days** | **Status: TODO**

**User Journey:**
1. User taps "Buy Now" on product
2. Confirm purchase modal (price, seller info)
3. Payment method selection
4. Process payment through Stripe
5. Hold funds in escrow
6. Notify seller & buyer
7. Await delivery confirmation

**Database Models Needed:**
```swift
struct Transaction: Codable {
    let id: UUID
    let listingId: UUID
    let buyerId: String
    let sellerId: String
    let amount: Double
    let status: TransactionStatus
    let paymentIntentId: String
    let escrowReleaseDate: Date?
    let createdAt: Date
}

enum TransactionStatus: String, Codable {
    case pending = "pending"
    case paid = "paid"
    case delivered = "delivered"
    case completed = "completed"
    case disputed = "disputed"
    case cancelled = "cancelled"
    case refunded = "refunded"
}
```

**Tasks:**
- [ ] Create transaction models in Core/Models/
- [ ] Set up Stripe integration in Services/
- [ ] Create PurchaseConfirmationView
- [ ] Implement payment processing
- [ ] Add transaction tracking to database
- [ ] Create buyer/seller notification system

**Acceptance Criteria:**
- Users can purchase products with real payments
- Funds held in escrow until delivery confirmed
- Both parties receive notifications
- Transaction records maintained

### P2.2: Service Booking Flow
**Priority: HIGH** | **Effort: 4 days** | **Status: TODO**

**User Journey:**
1. User taps "Book Service" 
2. Service booking modal:
   - Select date/time slots
   - Confirm location
   - Add special requests
   - See total price calculation
3. Payment method & processing
4. Hold funds in escrow
5. Notify service provider
6. Await service completion confirmation

**Additional Models:**
```swift
struct ServiceBooking: Codable {
    let id: UUID
    let transactionId: UUID
    let scheduledDate: Date
    let duration: Int // minutes
    let location: String
    let specialRequests: String?
    let status: ServiceStatus
}

enum ServiceStatus: String, Codable {
    case scheduled = "scheduled"
    case inProgress = "in_progress" 
    case completed = "completed"
    case cancelled = "cancelled"
}
```

**Tasks:**
- [ ] Create service booking models
- [ ] Create ServiceBookingView with calendar
- [ ] Implement date/time selection
- [ ] Handle service pricing calculation
- [ ] Add booking confirmation flow
- [ ] Service provider acceptance/rejection

**Acceptance Criteria:**
- Users can book services for specific dates/times
- Service providers can accept/reject bookings
- Price calculated based on duration
- Booking details tracked in database

---

## 💬 Phase 3: Communication System (Week 5-6)

### P3.1: Direct Messaging Infrastructure
**Priority: HIGH** | **Effort: 4 days** | **Status: TODO**

**Current Issue:** No way for buyers/sellers to communicate
**Solution:** Build real-time messaging system

**Database Schema:**
```sql
-- Conversations table
CREATE TABLE conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    listing_id UUID REFERENCES listings(id),
    buyer_id UUID REFERENCES users(id),
    seller_id UUID REFERENCES users(id),
    last_message_at TIMESTAMP DEFAULT NOW(),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Messages table  
CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID REFERENCES conversations(id),
    sender_id UUID REFERENCES users(id),
    content TEXT NOT NULL,
    message_type VARCHAR(20) DEFAULT 'text',
    created_at TIMESTAMP DEFAULT NOW()
);
```

**Tasks:**
- [ ] Create messaging models in Features/Messaging/Models/
- [ ] Set up Supabase real-time subscriptions
- [ ] Create ConversationListView
- [ ] Create ChatView with real-time updates
- [ ] Implement message sending/receiving
- [ ] Add conversation creation from listings

**Acceptance Criteria:**
- Users can message about specific listings
- Real-time message delivery
- Message history persisted
- Clean conversation UI

### P3.2: Transaction-Specific Communications
**Priority: MEDIUM** | **Effort: 2 days** | **Status: TODO**

**Enhanced Messages for Transactions:**
- Auto-generated messages for key events
- Purchase confirmations
- Delivery tracking updates
- Service completion requests

**Special Message Types:**
```swift
enum MessageType: String, Codable {
    case text = "text"
    case systemNotification = "system"
    case purchaseConfirmation = "purchase_confirmation"
    case deliveryRequest = "delivery_request"
    case serviceComplete = "service_complete"
    case disputeAlert = "dispute_alert"
}
```

**Tasks:**
- [ ] Extend message types
- [ ] Auto-generate transaction messages
- [ ] Add delivery confirmation buttons in chat
- [ ] Service completion confirmations
- [ ] Visual distinction for system messages

---

## 🏦 Phase 4: Transaction Management (Week 7-8)

### P4.1: Escrow System Implementation
**Priority: HIGH** | **Effort: 6 days** | **Status: TODO**

**How Escrow Works:**

**For Products:**
1. Payment captured but not charged to buyer
2. Funds held by Stripe for 7 days (configurable)
3. Buyer confirms delivery → Release to seller
4. Auto-release after 7 days if no disputes
5. Dispute → Hold funds pending resolution

**For Services:**
1. Payment captured at booking
2. Funds held until service completion
3. Service provider marks complete → Buyer has 24h to dispute
4. Auto-release after 24h if no issues
5. Dispute → Manual review process

**Tasks:**
- [ ] Implement Stripe Payment Intents with manual capture
- [ ] Create escrow management service
- [ ] Build delivery confirmation UI
- [ ] Implement auto-release timers
- [ ] Add manual release triggers
- [ ] Create escrow status tracking

**Acceptance Criteria:**
- Payments held securely until delivery/completion
- Automatic release mechanisms work
- Manual confirmation options available
- Clear status communication to users

### P4.2: Delivery & Completion Tracking
**Priority: HIGH** | **Effort: 4 days** | **Status: TODO**

**Product Delivery Flow:**
1. Seller marks "Ready for Pickup/Delivered"
2. Buyer receives notification
3. Buyer confirms "Received" or "Not Received"
4. If confirmed → Release escrow
5. If not confirmed → Start dispute timer

**Service Completion Flow:**
1. Service provider marks "Service Complete"
2. Buyer receives completion confirmation request
3. Buyer confirms or disputes within 24h
4. Auto-complete if no response

**UI Components:**
- Transaction status dashboard
- Confirmation buttons in messaging
- Status timeline view
- Notification banners

**Tasks:**
- [ ] Create transaction status views
- [ ] Implement status update mechanisms
- [ ] Build confirmation UI components
- [ ] Add notification system
- [ ] Create status timeline display

---

## ⚖️ Phase 5: Dispute Resolution (Week 9-10)

### P5.1: Dispute Filing System
**Priority: MEDIUM** | **Effort: 3 days** | **Status: TODO**

**Dispute Triggers:**
- Buyer claims non-delivery
- Buyer claims item not as described
- Service provider claims no-show
- Service quality disputes

**Dispute Process:**
1. Either party files dispute
2. Automatic evidence collection period (48h)
3. Both parties submit evidence/statements
4. Admin review and decision
5. Escrow released based on decision

**Database Schema:**
```sql
CREATE TABLE disputes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_id UUID REFERENCES transactions(id),
    filed_by UUID REFERENCES users(id),
    dispute_type VARCHAR(50),
    description TEXT,
    evidence_urls TEXT[],
    status VARCHAR(20) DEFAULT 'open',
    resolution TEXT,
    resolved_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);
```

**Tasks:**
- [ ] Create dispute models and views
- [ ] Build dispute filing interface
- [ ] Implement evidence upload system
- [ ] Create admin dispute dashboard
- [ ] Add resolution notification system

### P5.2: Admin Support Dashboard
**Priority: LOW** | **Effort: 4 days** | **Status: TODO**

**Admin Features:**
- View all open disputes
- Review evidence from both parties
- Make resolution decisions
- Refund/release escrow funds
- Ban problematic users
- Generate dispute reports

**Tasks:**
- [ ] Create admin authentication system
- [ ] Build dispute management interface
- [ ] Implement resolution actions
- [ ] Add user management tools
- [ ] Create reporting dashboard

---

## 📱 Phase 6: UI/UX Polish (Week 11-12)

### P6.1: Status Indicators & Notifications
**Priority: HIGH** | **Effort: 3 days** | **Status: TODO**

**Status Displays:**
- Purchase status badges
- Delivery tracking
- Service appointment reminders
- Payment confirmations
- Dispute alerts

**Notification Types:**
- Push notifications for messages
- Transaction status updates
- Service reminders
- Dispute deadlines
- Payment confirmations

**Tasks:**
- [ ] Design status indicator system
- [ ] Implement push notification service
- [ ] Add in-app notification center
- [ ] Create status dashboards
- [ ] Add notification preferences

### P6.2: Enhanced Listing Management
**Priority: MEDIUM** | **Effort: 2 days** | **Status: TODO**

**Seller Features:**
- Mark items as sold/unavailable
- Edit listing details
- View purchase inquiries
- Manage service bookings
- Track earnings

**Tasks:**
- [ ] Add listing edit functionality
- [ ] Create seller dashboard
- [ ] Implement listing status management
- [ ] Add earnings tracking
- [ ] Build booking management interface

---

## 🚀 Phase 7: Advanced Features (Week 13-16)

### P7.1: Rating & Review System
**Priority: MEDIUM** | **Effort: 5 days** | **Status: TODO**

**After Transaction Completion:**
- Both parties can rate each other
- Written reviews optional
- Ratings affect user trustworthiness
- Reviews displayed on profiles

### P7.2: Advanced Search & Filters
**Priority: MEDIUM** | **Effort: 4 days** | **Status: TODO**

**Search Features:**
- Text search in titles/descriptions
- Category filtering
- Price range filtering
- Distance/location filtering
- Availability filtering for services
- Sort by price, date, popularity

### P7.3: Favorites & Saved Searches
**Priority: LOW** | **Effort: 2 days** | **Status: TODO**

**User Features:**
- Save favorite listings
- Create saved search alerts
- Wishlist functionality
- Price drop notifications

---

## 📊 Success Metrics & KPIs

### Week 2 Goals:
- [ ] Users can view individual listing details
- [ ] Appropriate action buttons display
- [ ] Navigation flow works smoothly

### Week 4 Goals:
- [ ] Users can complete product purchases
- [ ] Users can book services
- [ ] Payment integration functional
- [ ] Escrow system operational

### Week 6 Goals:
- [ ] Messaging system fully functional
- [ ] Real-time communication works
- [ ] Transaction communications integrated

### Week 8 Goals:
- [ ] Delivery confirmation system works
- [ ] Escrow auto-release functional
- [ ] Transaction status tracking complete

### Week 10 Goals:
- [ ] Dispute system operational
- [ ] Admin resolution tools functional
- [ ] Support pipeline complete

### Week 12 Goals:
- [ ] All notifications working
- [ ] Status indicators comprehensive
- [ ] User experience polished

---

## 🔧 Technical Implementation Notes

### Database Migrations Needed:
1. Add `listing_type` to listings table
2. Create transactions table
3. Create service_bookings table  
4. Create conversations table
5. Create messages table
6. Create disputes table

### Stripe Integration:
- Payment Intents for escrow
- Webhooks for payment confirmations
- Marketplace account setup
- Dispute handling integration

### Real-time Features:
- Supabase real-time for messaging
- Push notifications for iOS
- Background sync for status updates

### Security Considerations:
- Row Level Security for all tables
- Payment validation
- Dispute evidence handling
- Admin access controls

---

## 🎯 Next Immediate Actions:

1. **Start with P1.1** - Add listing types (product vs service)
2. **Then P1.2** - Create listing detail view
3. **Then P1.3** - Add action buttons
4. **Review progress** after each phase completion

This plan ensures we build a complete, production-ready marketplace with proper transaction handling, communication, and dispute resolution systems.
