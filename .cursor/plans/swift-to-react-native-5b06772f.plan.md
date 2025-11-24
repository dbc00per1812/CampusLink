<!-- 5b06772f-ef75-48f0-b523-9ab8b4028d41 a0704981-c24b-46e3-83f3-03eed54adb9a -->
# Swift to React Native Conversion - File-by-File Migration Plan

## Repository Structure

Clean separation with three main directories: iOS, React Native, and shared docs.

```
CampusLink/                           (Root repo)
├── ios-swift/                        (ALL Swift/iOS files - moved here)
│   ├── CampusLink/                   (Swift source code)
│   ├── CampusLink.xcodeproj/         (Xcode project)
│   ├── CampusLinkTests/              (iOS tests)
│   ├── CampusLinkUITests/            (iOS UI tests)
│   └── PrivacyInfo.xcprivacy         (iOS privacy manifest)
│
├── mobile/                           (ALL React Native files - new)
│   ├── src/
│   │   ├── types/                    (TypeScript models)
│   │   ├── services/                 (API/business logic)
│   │   ├── components/               (Reusable UI)
│   │   ├── screens/                  (Full-screen views)
│   │   ├── navigation/               (Tab/stack navigation)
│   │   ├── hooks/                    (Custom React hooks)
│   │   ├── utils/                    (Helpers/extensions)
│   │   └── config/                   (App config, Supabase client)
│   ├── assets/                       (Images, fonts)
│   ├── app.json                      (Expo config)
│   ├── package.json                  (Dependencies)
│   ├── tsconfig.json                 (TypeScript config)
│   └── App.tsx                       (Entry point)
│
├── docs/                             (Shared documentation - moved from root)
│   ├── databaseinfoforcontext/       (Database schema reference)
│   ├── sql/                          (All SQL migration files)
│   └── guides/                       (All markdown docs)
│
├── supabase/                         (Edge functions - unchanged)
│   └── functions/
│       ├── process-push-queue/
│       ├── connect_onboarding/
│       └── create-payment-intent/
│
├── web/                              (Static HTML files - keep at root level)
│   ├── index.html
│   ├── privacy.html
│   ├── terms.html
│   └── stripe-*.html
│
├── .gitignore                        (Root - updated for both platforms)
├── README.md                         (Root - project overview)
├── package.json                      (Root - for supabase functions)
├── .git/                             (Git repo)
└── .cursor/                          (Cursor IDE config)
```

**Benefits:**

- Clear separation: iOS and React Native never conflict
- Easy file comparison: `ios-swift/CampusLink/Core/Models/` vs `mobile/src/types/`
- Clean root: Only essential config files
- Shared resources: Docs accessible to both platforms
- Future-proof: Can add more platforms easily

## Phase 0: Repository Reorganization (30 minutes)

Before creating React Native app, reorganize existing files for clean separation.

### Step 0.1: Create new directory structure

```bash
mkdir -p ios-swift
mkdir -p mobile
mkdir -p docs/sql
mkdir -p docs/guides
```

### Step 0.2: Move iOS files to ios-swift/

Move these folders/files from root to `ios-swift/`:

- `CampusLink/` → `ios-swift/CampusLink/`
- `CampusLink.xcodeproj/` → `ios-swift/CampusLink.xcodeproj/`
- `CampusLinkTests/` → `ios-swift/CampusLinkTests/`
- `CampusLinkUITests/` → `ios-swift/CampusLinkUITests/`
- `PrivacyInfo.xcprivacy` → `ios-swift/PrivacyInfo.xcprivacy`

### Step 0.3: Move documentation files to docs/

Move these from root to `docs/`:

- All `*.sql` files → `docs/sql/`
- All `*.md` files (except README.md) → `docs/guides/`
- `databaseinfoforcontext/` → `docs/databaseinfoforcontext/`

### Step 0.4: Keep at root level

These stay in root:

- `supabase/` (edge functions)
- `web/` (rename from api/ - contains HTML files)
- `.gitignore`, `README.md`, `package.json`, `.git/`, `.cursor/`

### Step 0.5: Update .gitignore

Add React Native entries:

```
# React Native / Expo
mobile/node_modules/
mobile/.expo/
mobile/dist/
mobile/.expo-shared/
mobile/*.log

# iOS (updated path)
ios-swift/Pods/
ios-swift/*.xcworkspace
ios-swift/build/
```

## Phase 1: Project Setup & Foundation (Day 1 Morning - 2 hours)

### Step 1.1: Create React Native project

```bash
cd mobile
npx create-expo-app@latest . --template blank-typescript
```

### Step 1.2: Install dependencies

```bash
npm install @supabase/supabase-js @stripe/stripe-react-native react-native-onesignal
npm install @react-navigation/native @react-navigation/bottom-tabs @react-navigation/native-stack
npm install expo-image-picker expo-camera expo-image
npm install @tanstack/react-query
npm install react-native-reanimated react-native-gesture-handler
```

### Step 1.3: Setup Supabase client

**Create:** `mobile/src/config/supabase.ts`

**Reference:** `ios-swift/CampusLink/App/CampusLinkTestApp.swift` (lines 12-15)

### Step 1.4: Environment configuration

**Create:** `mobile/src/config/secrets.ts`

**Reference:** `ios-swift/CampusLink/App/Secrets.swift`

**Note:** Use same Supabase URL/keys as iOS app

## Phase 2: Data Models (Day 1 Morning - 2 hours)

Convert Swift structs to TypeScript interfaces. All models are straightforward 1:1 conversions.

| Swift File | React Native File | Lines | Priority |

|------------|-------------------|-------|----------|

| `ios-swift/CampusLink/Core/Models/ProductModels.swift` | `mobile/src/types/product.ts` | ~200 | HIGH |

| `ios-swift/CampusLink/Core/Models/OrderModels.swift` | `mobile/src/types/order.ts` | ~150 | HIGH |

| `ios-swift/CampusLink/Core/Models/MessagingModels.swift` | `mobile/src/types/messaging.ts` | ~100 | HIGH |

| `ios-swift/CampusLink/Core/Models/WalletModels.swift` | `mobile/src/types/wallet.ts` | ~80 | HIGH |

| `ios-swift/CampusLink/Core/Models/NotificationModels.swift` | `mobile/src/types/notification.ts` | ~60 | MEDIUM |

| `ios-swift/CampusLink/Core/Models/RatingModels.swift` | `mobile/src/types/rating.ts` | ~50 | MEDIUM |

| `ios-swift/CampusLink/Core/Models/PaymentModels.swift` | `mobile/src/types/payment.ts` | ~100 | MEDIUM |

| `ios-swift/CampusLink/Core/Models/SearchModels.swift` | `mobile/src/types/search.ts` | ~40 | LOW |

| `ios-swift/CampusLink/Core/Models/Campus.swift` | `mobile/src/types/campus.ts` | ~20 | LOW |

| `ios-swift/CampusLink/Core/Models/BlockedUser.swift` | `mobile/src/types/blockedUser.ts` | ~15 | LOW |

| `ios-swift/CampusLink/Core/Models/UserInterest.swift` | `mobile/src/types/userInterest.ts` | ~15 | LOW |

| `ios-swift/CampusLink/Core/Models/ReportModels.swift` | `mobile/src/types/report.ts` | ~40 | LOW |

| `ios-swift/CampusLink/Core/Models/PendingTransactionModels.swift` | `mobile/src/types/pendingTransaction.ts` | ~30 | LOW |

**Reference:** `docs/databaseinfoforcontext/databaseinfoforcontext.md` for exact column types

## Phase 3: Services Layer (Day 1 Afternoon - 4 hours)

Convert Swift services to TypeScript. These handle all Supabase RPC calls and business logic.

| Swift File | React Native File | Key Functions | Priority |

|------------|-------------------|---------------|----------|

| `ios-swift/CampusLink/Core/Auth/AuthManager.swift` | `mobile/src/services/authService.ts` | signIn, signOut, session management | CRITICAL |

| `ios-swift/CampusLink/Core/Services/OrderService.swift` | `mobile/src/services/orderService.ts` | getUserActiveOrders, confirmOrder, etc. | HIGH |

| `ios-swift/CampusLink/Core/Services/WalletService.swift` | `mobile/src/services/walletService.ts` | getBalance, getTransactions | HIGH |

| `ios-swift/CampusLink/Core/Services/SearchService.swift` | `mobile/src/services/searchService.ts` | searchListings RPC | HIGH |

| `ios-swift/CampusLink/Core/Services/UnifiedOfferService.swift` | `mobile/src/services/offerService.ts` | makeOffer, acceptOffer, declineOffer | HIGH |

| `ios-swift/CampusLink/Core/Services/NotificationManager.swift` | `mobile/src/services/notificationService.ts` | OneSignal setup, token management | HIGH |

| `ios-swift/CampusLink/Core/Services/PayoutService.swift` | `mobile/src/services/payoutService.ts` | requestPayout RPC | MEDIUM |

| `ios-swift/CampusLink/Core/Services/RatingService.swift` | `mobile/src/services/ratingService.ts` | submitRating RPC | MEDIUM |

| `ios-swift/CampusLink/Core/Services/EscrowService.swift` | `mobile/src/services/escrowService.ts` | Payment tracking | MEDIUM |

| `ios-swift/CampusLink/Core/Services/BlockedUsersService.swift` | `mobile/src/services/blockedUsersService.ts` | Block/unblock users | LOW |

| `ios-swift/CampusLink/Core/Services/RecommendationService.swift` | `mobile/src/services/recommendationService.ts` | Smart suggestions | LOW |

| `ios-swift/CampusLink/Core/Services/UserInterestService.swift` | `mobile/src/services/userInterestService.ts` | Interest tracking | LOW |

| `ios-swift/CampusLink/Core/Services/ImageCacheManager.swift` | (Use expo-image caching) | N/A | LOW |

| `ios-swift/CampusLink/Core/Services/DataCacheManager.swift` | (Use React Query) | N/A | LOW |

| `ios-swift/CampusLink/Core/Services/ActiveOrderMonitor.swift` | `mobile/src/hooks/useActiveOrders.ts` | Convert to custom hook | MEDIUM |

| `ios-swift/CampusLink/Core/Services/ExpiredListingArchiver.swift` | `mobile/src/services/listingService.ts` | Auto-archive logic | LOW |

| `ios-swift/CampusLink/Core/Payments/PaymentLogic.swift` | `mobile/src/services/paymentService.ts` | Stripe integration | HIGH |

| `ios-swift/CampusLink/Features/Payments/Managers/PaymentService.swift` | (Merge with above) | Payment flows | HIGH |

**Critical:** All RPC function names and parameters must match exactly (e.g., `user_uuid` not `userId`)

## Phase 4: Shared Components (Day 2 Morning - 3 hours)

Build reusable UI components used across multiple screens.

| Swift File | React Native File | Component Type | Priority |

|------------|-------------------|----------------|----------|

| `ios-swift/CampusLink/Shared/Views/UserAvatarView.swift` | `mobile/src/components/UserAvatar.tsx` | Display | HIGH |

| `ios-swift/CampusLink/Shared/Views/ActionButton.swift` | `mobile/src/components/Button.tsx` | Interactive | HIGH |

| `ios-swift/CampusLink/Shared/Views/SearchBarView.swift` | `mobile/src/components/SearchBar.tsx` | Input | HIGH |

| `ios-swift/CampusLink/Shared/Views/ImagePickerView.swift` | `mobile/src/components/ImagePicker.tsx` | Use expo-image-picker | HIGH |

| `ios-swift/CampusLink/Core/Components/ShareListingSheet.swift` | `mobile/src/components/ShareSheet.tsx` | Modal | MEDIUM |

| `ios-swift/CampusLink/Core/Views/Skeletons/ListingCardSkeleton.swift` | `mobile/src/components/skeletons/ListingCardSkeleton.tsx` | Loading | MEDIUM |

| `ios-swift/CampusLink/Core/Views/Skeletons/ChatSkeleton.swift` | `mobile/src/components/skeletons/ChatSkeleton.tsx` | Loading | LOW |

| `ios-swift/CampusLink/Core/Views/Skeletons/ShimmerEffect.swift` | `mobile/src/components/skeletons/ShimmerEffect.tsx` | Animation | LOW |

## Phase 5: Feature Screens (Day 2 Afternoon + Day 3 - 10 hours)

Convert full-screen views. Organized by feature area.

### 5.1 Authentication (1 hour) - CRITICAL

- `WelcomeView.swift` → `mobile/src/screens/auth/WelcomeScreen.tsx`
- `OTPEmailConfirmationView.swift` → `mobile/src/screens/auth/OTPVerificationScreen.tsx`
- `GuestPromptView.swift` → `mobile/src/components/GuestPrompt.tsx`

### 5.2 Home & Browse (2 hours) - CRITICAL

- `HomeTabView.swift` → `mobile/src/screens/home/HomeScreen.tsx`
- `ListingDetailView.swift` → `mobile/src/screens/home/ListingDetailScreen.tsx`
- `BrowseByCategoryView.swift` → `mobile/src/screens/home/CategoryBrowseScreen.tsx`

### 5.3 Create/Edit Listings (1.5 hours) - CRITICAL

- `TabViews.swift (PostView)` → `mobile/src/screens/post/CreateListingScreen.tsx` (1200 lines - largest file)
- `EditListingView.swift` → `mobile/src/screens/post/EditListingScreen.tsx`

### 5.4 Messaging (2 hours) - CRITICAL

- `ConversationListView.swift` → `mobile/src/screens/messages/ConversationsScreen.tsx`
- `ChatView.swift` → `mobile/src/screens/messages/ChatScreen.tsx`
- Convert ViewModels to hooks/local state

### 5.5 Orders & Payments (2 hours) - HIGH

- `MyTransactionsView.swift` → `mobile/src/screens/orders/OrdersScreen.tsx`
- `OrderDetailView.swift` → `mobile/src/screens/orders/OrderDetailScreen.tsx`
- `PurchaseConfirmationView.swift` → `mobile/src/screens/orders/PurchaseConfirmationScreen.tsx`
- `PaymentMethodSheet.swift` → `mobile/src/components/PaymentMethodSheet.tsx`

### 5.6 Wallet (1.5 hours) - HIGH

- `WalletView.swift` → `mobile/src/screens/wallet/WalletScreen.tsx`
- `PayoutRequestView.swift` → `mobile/src/screens/wallet/PayoutRequestScreen.tsx`
- `PayoutHistoryView.swift` → `mobile/src/screens/wallet/PayoutHistoryScreen.tsx`

### 5.7 Profile (1.5 hours) - HIGH

- `ProfileTabView.swift` → `mobile/src/screens/profile/ProfileScreen.tsx`
- `PublicProfileView.swift` → `mobile/src/screens/profile/PublicProfileScreen.tsx`
- `SettingsView.swift` → `mobile/src/screens/profile/SettingsScreen.tsx`

### 5.8 Offers (1 hour) - MEDIUM

- `MakeOfferSheet.swift` → `mobile/src/components/MakeOfferSheet.tsx`
- `OffersListView.swift` → `mobile/src/screens/offers/OffersScreen.tsx`
- `OfferAcceptanceView.swift` → `mobile/src/components/OfferAcceptance.tsx`

## Phase 6: Navigation (Day 3 - 1 hour)

Convert SwiftUI navigation to React Navigation.

| Swift File | React Native File | Purpose |

|------------|-------------------|---------|

| `ios-swift/CampusLink/Core/Navigation/MainTabView.swift` | `mobile/src/navigation/TabNavigator.tsx` | Bottom tabs (5 tabs) |

| `ios-swift/CampusLink/Core/Navigation/TabCoordinator.swift` | `mobile/src/navigation/navigationUtils.ts` | Tab state |

| `ios-swift/CampusLink/App/ContentView.swift` | `mobile/App.tsx` | Root component |

## Phase 7: Utilities & Config (Day 3 - 30 min)

| Swift File | React Native File | Purpose |

|------------|-------------------|---------|

| `ios-swift/CampusLink/Shared/Extensions/Color+Extensions.swift` | `mobile/src/utils/colors.ts` | Theme |

| `ios-swift/CampusLink/Shared/Extensions/String+NameFormat.swift` | `mobile/src/utils/stringUtils.ts` | Helpers |

| `ios-swift/CampusLink/Shared/Extensions/UIImage+Resize.swift` | `mobile/src/utils/imageUtils.ts` | Image processing |

| `ios-swift/CampusLink/Core/Config/AppConfig.swift` | `mobile/src/config/appConfig.ts` | Feature flags |

## Phase 8: Integration & Testing (Day 3 - 2 hours)

1. OneSignal push notifications
2. Stripe payment flows
3. Real-time chat/orders subscriptions
4. Image upload/caching
5. End-to-end critical flows

## Summary

**Total files to convert:** ~105 files

**Estimated time:** 3 days

**Backend changes:** Zero (everything stays the same)

**Critical path (MVP):**

1. Auth → Models → Services → Navigation
2. Home + Listing Detail (browse)
3. Chat (messaging)
4. Orders (transaction tracking)
5. Profile (user management)

**After React Native version is stable:**

- Test both apps side-by-side
- Fix any bugs found
- keep swift files for reference.
- Deploy React Native to iOS + Android

### To-dos

- [ ] Reorganize repository: move iOS files to ios-swift/, docs to docs/, create mobile/ folder
- [ ] Create Expo project in mobile/ and install all dependencies
- [ ] Setup Supabase client, secrets, and app configuration
- [ ] Convert all 13 Swift model files to TypeScript types
- [ ] Convert all 18 Swift service files to TypeScript services
- [ ] Build 15+ reusable UI components (Avatar, Button, SearchBar, etc.)
- [ ] Build authentication screens (Welcome, OTP, Guest)
- [ ] Build home screens (Home, Listing Detail, Category Browse)
- [ ] Build create/edit listing screens (largest file ~1200 lines)
- [ ] Build messaging screens (Conversations, Chat with real-time)
- [ ] Build orders/payments screens (Orders, Detail, Confirmation)
- [ ] Build wallet screens (Balance, Payout, History)
- [ ] Build profile screens (Profile, Settings, Public Profile)
- [ ] Build offers screens (Make Offer, List, Acceptance)
- [ ] Setup React Navigation with bottom tabs and stack navigators
- [ ] Integrate Stripe SDK and test payment flows
- [ ] Integrate OneSignal for push notifications (iOS + Android)
- [ ] Test Supabase real-time subscriptions for chat and orders
- [ ] Run complete end-to-end tests of all critical user flows